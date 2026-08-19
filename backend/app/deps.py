from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .database import get_db
from .models import Request, User
from .security import decode_room_token, decode_token

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _user_from_credentials(credentials, db)


def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User | None:
    if credentials is None:
        return None
    try:
        return _user_from_credentials(credentials, db)
    except HTTPException:
        return None


def _user_from_credentials(
    credentials: HTTPAuthorizationCredentials, db: Session
) -> User:
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("scope") is not None:
            raise ValueError("Scoped token cannot be used for API authentication")
        user_id = int(payload["sub"])
    except (ValueError, KeyError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from None
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists"
        )
    return user


def authenticate_room_token(
    token: str, request_id: int, db: Session
) -> tuple[User, Request]:
    user_id = decode_room_token(token, request_id)
    user = db.get(User, user_id)
    request = db.get(Request, request_id)
    if user is None or request is None:
        raise ValueError("Room or user no longer exists")
    if request.status != "accepted":
        raise ValueError("Room is not active")
    if user.id not in (request.requester_id, request.provider_id):
        raise ValueError("User is not a room participant")
    return user, request
