import hashlib
import secrets
from datetime import UTC, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..email import send_password_reset_email
from ..legal import PRIVACY_VERSION, TOS_VERSION
from ..models import BlockedToken, PasswordResetToken, User, utcnow
from ..schemas import (
    AuthOut,
    ForgotPasswordIn,
    LoginIn,
    ResetPasswordIn,
    SignupIn,
    UserMeOut,
)
from ..security import create_token, decode_token, hash_password, verify_password
from .users import user_me_out

_bearer = HTTPBearer(auto_error=False)

router = APIRouter(prefix="/auth", tags=["auth"])


def _to_me_out(user: User) -> UserMeOut:
    return user_me_out(user)


@router.post("/signup", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
def signup(payload: SignupIn, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == payload.email.lower()).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Email already registered"
        )
    user = User(
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        name=payload.name.strip(),
        lat=payload.lat,
        lng=payload.lng,
        tos_accepted_at=utcnow(),
        privacy_accepted_at=utcnow(),
        tos_version=TOS_VERSION,
        privacy_version=PRIVACY_VERSION,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return AuthOut(token=create_token({"sub": str(user.id)}), user=_to_me_out(user))


@router.post("/login", response_model=AuthOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password"
        )
    return AuthOut(token=create_token({"sub": str(user.id)}), user=_to_me_out(user))


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    user: User = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
):
    """Revoke the current token so it can no longer be used."""
    if credentials is None:
        return
    try:
        payload = decode_token(credentials.credentials)
        jti = payload.get("jti")
        if jti:
            existing = db.query(BlockedToken).filter(BlockedToken.jti == jti).first()
            if not existing:
                db.add(BlockedToken(jti=jti, blocked_at=utcnow()))
                db.commit()
    except (ValueError, KeyError):
        pass


@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is not None:
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        reset_token = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=utcnow() + timedelta(hours=1),
        )
        db.add(reset_token)
        db.commit()
        await send_password_reset_email(user.email, raw_token)
    return {"message": "If the email exists, a reset link has been sent"}


@router.post("/reset-password")
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)):
    token_hash = hashlib.sha256(payload.token.encode()).hexdigest()
    reset_token = (
        db.query(PasswordResetToken)
        .filter(PasswordResetToken.token_hash == token_hash)
        .first()
    )
    if reset_token is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )
    expires = reset_token.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=UTC)
    if reset_token.used or expires < utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )
    user = db.get(User, reset_token.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User not found",
        )
    user.password_hash = hash_password(payload.new_password)
    reset_token.used = True
    db.commit()
    return {"message": "Password has been reset"}
