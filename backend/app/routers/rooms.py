import asyncio
import json
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
from ..models import ChatMessage, DisclosureLog, Request, User
from ..schemas import ChatMessageOut, RoomTokenOut
from ..security import create_token, decrypt_contact
from .requests import _to_out

router = APIRouter(prefix="/requests", tags=["request rooms"])


def _accepted_participant(request: Request | None, user: User) -> Request:
    if request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Request not found"
        )
    if user.id not in (request.requester_id, request.provider_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not a request participant"
        )
    if request.status != "accepted":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Request is not accepted"
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
    )


@router.post("/{request_id}/room-token", response_model=RoomTokenOut)
def create_room_token(
    request_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    request = _accepted_participant(db.get(Request, request_id), user)
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
        contact_info["phone"] = decrypt_contact(
            request.provider.private_contact.encrypted_phone
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
    _accepted_participant(db.get(Request, request_id), user)
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.request_id == request_id)
        .order_by(ChatMessage.created_at, ChatMessage.id)
        .all()
    )
    return [_message_out(message) for message in messages]


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
async def request_chat(
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
                .filter(ChatMessage.request_id == request_id)
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
            body = payload.get("body") if isinstance(payload, dict) else None
            if (
                not isinstance(payload, dict)
                or payload.get("type") != "message"
                or not isinstance(body, str)
            ):
                await websocket.send_json(
                    {"type": "error", "detail": "Expected a message event"}
                )
                continue
            body = body.strip()
            if not body or len(body) > 2000:
                await websocket.send_json(
                    {"type": "error", "detail": "Message must be 1 to 2000 characters"}
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
                message = ChatMessage(
                    request_id=request_id, sender_id=user_id, body=body
                )
                db.add(message)
                db.commit()
                db.refresh(message)
                event_message = _message_out(message).model_dump(mode="json")
            await manager.broadcast(
                request_id, {"type": "message", "message": event_message}
            )
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(request_id, websocket)
