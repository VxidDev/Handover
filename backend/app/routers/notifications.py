import asyncio
import logging
from collections import defaultdict

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..deps import get_current_user
from ..models import ChatMessage, Request, User
from ..security import decode_token

logger = logging.getLogger("handover.notifications")

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationManager:
    def __init__(self) -> None:
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[user_id].add(websocket)

    async def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            conns = self._connections.get(user_id)
            if conns is None:
                return
            conns.discard(websocket)
            if not conns:
                self._connections.pop(user_id, None)

    async def send(self, user_id: int, event: dict) -> None:
        async with self._lock:
            sockets = list(self._connections.get(user_id, ()))
        stale = []
        for websocket in sockets:
            try:
                await websocket.send_json(event)
            except Exception:  # noqa: BLE001
                stale.append(websocket)
        for websocket in stale:
            await self.disconnect(user_id, websocket)

    async def broadcast_to_request(
        self, request_id: int, sender_id: int, event: dict
    ) -> None:
        with SessionLocal() as db:
            req = db.get(Request, request_id)
            if req is None:
                return
            participant_ids = [
                pid
                for pid in (req.requester_id, req.provider_id)
                if pid != sender_id
            ]
        for uid in participant_ids:
            await self.send(uid, event)


notification_manager = NotificationManager()


def _authenticate_ws_token(token: str) -> int:
    payload = decode_token(token)
    if payload.get("scope") is not None:
        raise ValueError("Scoped token cannot be used for notifications")
    return int(payload["sub"])


@router.websocket("")
async def notifications_ws(
    websocket: WebSocket,
    token: str = Query(...),
):
    try:
        user_id = _authenticate_ws_token(token)
    except (ValueError, KeyError):
        await websocket.close(code=1008, reason="Invalid or expired token")
        return

    with SessionLocal() as db:
        user = db.get(User, user_id)
        if user is None:
            await websocket.close(code=1008, reason="User not found")
            return

    await notification_manager.connect(user_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("Unexpected error in notification WS for user %d", user_id)
    finally:
        await notification_manager.disconnect(user_id, websocket)
