import asyncio
import json
import logging
from collections import defaultdict
from datetime import UTC, datetime, timedelta

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy.orm import Session

from ..config import settings
from ..database import SessionLocal, get_db
from ..deps import authenticate_room_token, get_current_user
from ..models import (
    BlockedUser,
    ChatMessage,
    DisclosureLog,
    MessageReadCursor,
    OneSignalPlayer,
    Request,
    User,
)
from ..onesignal import send_push
from ..schemas import ChatMessageOut, RoomTokenOut, UnreadCountsOut
from ..security import create_token, decrypt_contact
from .notifications import notification_manager
from .requests import _to_out

logger = logging.getLogger("handover.rooms")

router = APIRouter(prefix="/requests", tags=["request rooms"])


def _is_blocked(db: Session, user_id: int, other_id: int) -> bool:
    return (
        db.query(BlockedUser)
        .filter(
            ((BlockedUser.blocker_id == user_id) & (BlockedUser.blocked_id == other_id))
            | (
                (BlockedUser.blocker_id == other_id)
                & (BlockedUser.blocked_id == user_id)
            )
        )
        .first()
        is not None
    )


def _accepted_participant(
    request: Request | None, user: User, db: Session | None = None
) -> Request:
    if request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Request not found"
        )
    if user.id not in (request.requester_id, request.provider_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not a request participant"
        )
    if request.status not in ("accepted", "completed"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Request is not accepted"
        )
    # Block enforcement for chat access
    if db is not None:
        other_id = (
            request.requester_id
            if user.id == request.provider_id
            else request.provider_id
        )
        if _is_blocked(db, user.id, other_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot interact with this user",
            )
    return request


def _message_out(message: ChatMessage) -> ChatMessageOut:
    return ChatMessageOut(
        id=message.id,
        request_id=message.request_id,
        sender_id=message.sender_id,
        sender_name=message.sender.name,
        body=message.body,
        created_at=message.created_at,
        image_url=message.image_url,
    )


@router.post("/{request_id}/room-token", response_model=RoomTokenOut)
def create_room_token(
    request_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    request = _accepted_participant(db.get(Request, request_id), user, db)
    expires_at = datetime.now(UTC) + timedelta(seconds=settings.ROOM_TOKEN_TTL_SECONDS)
    token = create_token(
        {
            "sub": str(user.id),
            "scope": "request_room",
            "request_id": request.id,
        },
        ttl_seconds=settings.ROOM_TOKEN_TTL_SECONDS,
    )
    contact_info: dict[str, str] = {}
    if (
        user.id == request.requester_id
        and request.provider_share_phone
        and request.provider.private_contact is not None
    ):
        try:
            contact_info["phone"] = decrypt_contact(
                request.provider.private_contact.encrypted_phone
            )
        except Exception:
            logger.exception(
                "Failed to decrypt phone for room token (request %d)", request_id
            )
        db.add(
            DisclosureLog(
                request_id=request.id,
                owner_id=request.provider_id,
                viewer_id=user.id,
                field="phone",
                reason="accepted_request_room",
            )
        )
        db.commit()
    return RoomTokenOut(
        token=token,
        expires_at=expires_at,
        request=_to_out(request),
        contact_info=contact_info,
    )


@router.get("/{request_id}/messages", response_model=list[ChatMessageOut])
def message_history(
    request_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _accepted_participant(db.get(Request, request_id), user, db)
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.request_id == request_id, ChatMessage.is_hidden == False)  # noqa: E712
        .order_by(ChatMessage.created_at, ChatMessage.id)
        .all()
    )
    return [_message_out(message) for message in messages]


@router.post("/{request_id}/read")
def mark_read(
    request_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _accepted_participant(db.get(Request, request_id), user, db)
    latest = (
        db.query(ChatMessage)
        .filter(ChatMessage.request_id == request_id)
        .order_by(ChatMessage.id.desc())
        .first()
    )
    last_id = latest.id if latest else 0
    cursor = (
        db.query(MessageReadCursor)
        .filter(
            MessageReadCursor.user_id == user.id,
            MessageReadCursor.request_id == request_id,
        )
        .first()
    )
    if cursor is None:
        cursor = MessageReadCursor(
            user_id=user.id,
            request_id=request_id,
            last_read_message_id=last_id,
        )
        db.add(cursor)
    else:
        cursor.last_read_message_id = last_id
    db.commit()
    return {"last_read_message_id": last_id}


@router.get("/unread-counts", response_model=UnreadCountsOut)
def unread_counts(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    requests = (
        db.query(Request)
        .filter(
            (Request.requester_id == user.id) | (Request.provider_id == user.id),
            Request.status.in_(["accepted", "completed"]),
        )
        .all()
    )
    counts: dict[str, int] = {}
    for req in requests:
        cursor = (
            db.query(MessageReadCursor)
            .filter(
                MessageReadCursor.user_id == user.id,
                MessageReadCursor.request_id == req.id,
            )
            .first()
        )
        last_read = cursor.last_read_message_id if cursor else 0
        unread = (
            db.query(ChatMessage)
            .filter(
                ChatMessage.request_id == req.id,
                ChatMessage.id > last_read,
                ChatMessage.sender_id != user.id,
            )
            .count()
        )
        if unread > 0:
            counts[str(req.id)] = unread
    return UnreadCountsOut(counts=counts)


class ConnectionManager:
    def __init__(self) -> None:
        self._rooms: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, request_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._rooms[request_id].add(websocket)

    async def disconnect(self, request_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            room = self._rooms.get(request_id)
            if room is None:
                return
            room.discard(websocket)
            if not room:
                self._rooms.pop(request_id, None)

    async def broadcast(self, request_id: int, event: dict) -> None:
        async with self._lock:
            sockets = list(self._rooms.get(request_id, ()))
        stale = []
        for websocket in sockets:
            try:
                await websocket.send_json(event)
            except Exception:  # noqa: BLE001
                stale.append(websocket)
        for websocket in stale:
            await self.disconnect(request_id, websocket)


manager = ConnectionManager()


@router.websocket("/{request_id}/chat")
async def request_chat(  # noqa: C901
    websocket: WebSocket,
    request_id: int,
    token: str = Query(...),
):
    with SessionLocal() as db:
        try:
            user, _ = authenticate_room_token(token, request_id, db)
        except ValueError:
            await websocket.close(code=1008, reason="Invalid or expired room token")
            return
        user_id = user.id

    await manager.connect(request_id, websocket)
    try:
        with SessionLocal() as db:
            messages = (
                db.query(ChatMessage)
                .filter(
                    ChatMessage.request_id == request_id, ChatMessage.is_hidden == False
                )  # noqa: E712
                .order_by(ChatMessage.created_at, ChatMessage.id)
                .all()
            )
            history = [
                _message_out(message).model_dump(mode="json") for message in messages
            ]
        await websocket.send_json({"type": "history", "messages": history})

        while True:
            try:
                payload = json.loads(await websocket.receive_text())
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "detail": "Invalid JSON"})
                continue

            if not isinstance(payload, dict):
                await websocket.send_json(
                    {"type": "error", "detail": "Expected a JSON object"}
                )
                continue

            event_type = payload.get("type")

            if event_type == "typing":
                await manager.broadcast(
                    request_id,
                    {"type": "typing", "user_id": user_id},
                )
                continue

            if event_type != "message":
                await websocket.send_json(
                    {"type": "error", "detail": "Expected a message event"}
                )
                continue

            body = (payload.get("body") or "").strip()
            image_url = payload.get("image_url")
            if not body and not image_url:
                await websocket.send_json(
                    {"type": "error", "detail": "Message must have body or image_url"}
                )
                continue
            if body and len(body) > 2000:
                await websocket.send_json(
                    {"type": "error", "detail": "Message must be 1 to 2000 characters"}
                )
                continue
            if image_url and len(image_url) > 500:
                await websocket.send_json(
                    {"type": "error", "detail": "image_url too long"}
                )
                continue

            with SessionLocal() as db:
                try:
                    user, _ = authenticate_room_token(token, request_id, db)
                except ValueError:
                    await websocket.close(
                        code=1008, reason="Room access is no longer valid"
                    )
                    return
                # Proactive UGC moderation on chat messages — hide toxic within 24h
                from ..moderation import analyze as _analyze

                is_toxic = False
                if body:
                    toxic, _ = _analyze(body)
                    is_toxic = toxic
                message = ChatMessage(
                    request_id=request_id,
                    sender_id=user_id,
                    body="[Removed for review]" if is_toxic else body,
                    image_url=image_url if not is_toxic else None,
                    is_hidden=is_toxic,
                )
                db.add(message)
                if is_toxic:
                    from ..models import Report, Warning

                    # Auto-report for auditing
                    rep = Report(
                        reporter_id=user_id,
                        content_type="chat_message",
                        content_id=0,  # temporary, updated after flush
                        reason="auto_moderation",
                        status="warning_issued",
                        toxicity_score=1.0,
                    )
                    db.add(rep)
                    db.flush()
                    rep.content_id = message.id
                    warn = Warning(
                        user_id=user_id,
                        report_id=rep.id,
                        reason="inappropriate chat message",
                    )
                    db.add(warn)
                db.commit()
                db.refresh(message)
                if is_toxic:
                    await websocket.send_json(
                        {"type": "error", "detail": "Message blocked by moderation."}
                    )
                    continue
                event_message = _message_out(message).model_dump(mode="json")
            await manager.broadcast(
                request_id, {"type": "message", "message": event_message}
            )
            await notification_manager.broadcast_to_request(
                request_id,
                sender_id=user_id,
                event={
                    "type": "new_message",
                    "request_id": request_id,
                    "sender_name": user.name,
                    "body": body[:100] if body else "",
                },
            )
            with SessionLocal() as push_db:
                req = push_db.get(Request, request_id)
                if req is not None:
                    recipient_ids = [
                        pid
                        for pid in (req.requester_id, req.provider_id)
                        if pid != user_id
                    ]
                    if recipient_ids:
                        players = (
                            push_db.query(OneSignalPlayer.player_id)
                            .filter(OneSignalPlayer.user_id.in_(recipient_ids))
                            .all()
                        )
                        player_ids = [p[0] for p in players]
                        if player_ids:
                            await send_push(
                                player_ids,
                                title=user.name,
                                body=body[:100] if body else "Sent an image",
                                data={"request_id": str(request_id)},
                            )
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("Unexpected error in WebSocket for request %d", request_id)
    finally:
        await manager.disconnect(request_id, websocket)
