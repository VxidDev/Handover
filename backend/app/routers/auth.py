from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import check_ban, get_current_user
from ..email import send_email_code
from ..legal import PRIVACY_VERSION, TOS_VERSION
from ..models import BlockedToken, PasswordResetCode, User, utcnow
from ..schemas import (
    AuthOut,
    ForgotPasswordIn,
    LoginIn,
    ResetPasswordIn,
    SignupIn,
    TwoFADisableIn,
    TwoFAEnableIn,
    TwoFASetupOut,
    TwoFAStatusOut,
    UserMeOut,
)
from ..security import (
    create_token,
    decode_token,
    decrypt_totp_secret,
    encrypt_totp_secret,
    generate_email_code,
    generate_recovery_codes,
    generate_totp_secret,
    get_totp_uri,
    hash_email_code,
    hash_password,
    remove_recovery_code,
    store_recovery_codes,
    verify_email_code,
    verify_password,
    verify_totp,
)
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
    check_ban(db, user)
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
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials",
        )

    code = generate_email_code()
    code_hash = hash_email_code(code)

    reset_code = PasswordResetCode(
        user_id=user.id,
        code_hash=code_hash,
        expires_at=utcnow() + timedelta(minutes=15),
    )
    db.add(reset_code)
    db.commit()

    sent = await send_email_code(user.email, code)
    if not sent:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send email. Please try again.",
        )

    return {"message": "A verification code has been sent to your email"}


@router.post("/reset-password")
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid credentials",
        )

    if payload.email_code:
        code_record = (
            db.query(PasswordResetCode)
            .filter(
                PasswordResetCode.user_id == user.id,
                PasswordResetCode.used == False,
                PasswordResetCode.expires_at > utcnow(),
            )
            .order_by(PasswordResetCode.created_at.desc())
            .first()
        )
        if not code_record or not verify_email_code(payload.email_code, code_record.code_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired email code",
            )
        code_record.used = True
    elif payload.recovery_code:
        if not user.recovery_codes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid recovery code",
            )
        updated_codes = remove_recovery_code(payload.recovery_code, user.recovery_codes)
        if updated_codes is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or already used recovery code",
            )
        user.recovery_codes = updated_codes
    elif payload.totp_code:
        if not user.two_factor_enabled or not user.totp_secret:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Two-factor authentication is not enabled",
            )
        totp_secret = decrypt_totp_secret(user.totp_secret)
        if not verify_totp(totp_secret, payload.totp_code):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid TOTP code",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One of email_code, totp_code, or recovery_code is required",
        )

    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"message": "Password has been reset"}


# ---------------------------------------------------------------------------
# Two-Factor Authentication
# ---------------------------------------------------------------------------


@router.post("/2fa/setup", response_model=TwoFASetupOut)
def setup_2fa(
    user: User = Depends(get_current_user),
):
    if user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is already enabled",
        )
    secret = generate_totp_secret()
    encrypted = encrypt_totp_secret(secret)
    otpauth_uri = get_totp_uri(secret, user.email)
    user.totp_secret = encrypted
    db = Session.object_session(user)
    db.commit()
    return TwoFASetupOut(secret=secret, otpauth_uri=otpauth_uri)


@router.post("/2fa/enable")
def enable_2fa(
    payload: TwoFAEnableIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is already enabled",
        )
    if not user.totp_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Call /2fa/setup first to generate a secret",
        )

    totp_secret = decrypt_totp_secret(user.totp_secret)
    if not verify_totp(totp_secret, payload.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid TOTP code",
        )

    codes = generate_recovery_codes()
    user.two_factor_enabled = True
    user.recovery_codes = store_recovery_codes(codes)
    db.commit()
    return {"message": "Two-factor authentication enabled", "recovery_codes": codes}


@router.post("/2fa/disable")
def disable_2fa(
    payload: TwoFADisableIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is not enabled",
        )
    if not user.totp_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No TOTP secret found",
        )

    totp_secret = decrypt_totp_secret(user.totp_secret)
    if not verify_totp(totp_secret, payload.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid TOTP code",
        )

    user.two_factor_enabled = False
    user.totp_secret = None
    user.recovery_codes = None
    db.commit()
    return {"message": "Two-factor authentication disabled"}


@router.get("/2fa/status", response_model=TwoFAStatusOut)
def two_fa_status(user: User = Depends(get_current_user)):
    return TwoFAStatusOut(enabled=user.two_factor_enabled)


@router.get("/2fa/recovery-codes")
def get_recovery_codes(
    user: User = Depends(get_current_user),
):
    if not user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is not enabled",
        )
    if not user.recovery_codes:
        return {"recovery_codes": []}
    import json

    try:
        hashed = json.loads(user.recovery_codes)
    except (json.JSONDecodeError, TypeError):
        return {"recovery_codes": []}
    return {"recovery_codes": hashed, "count": len(hashed)}


@router.post("/2fa/recovery-codes/regenerate")
def regenerate_recovery_codes(
    payload: TwoFAEnableIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is not enabled",
        )
    if not user.totp_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No TOTP secret found",
        )

    totp_secret = decrypt_totp_secret(user.totp_secret)
    if not verify_totp(totp_secret, payload.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid TOTP code",
        )

    codes = generate_recovery_codes()
    user.recovery_codes = store_recovery_codes(codes)
    db.commit()
    return {"recovery_codes": codes}
