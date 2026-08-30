import base64
import hashlib
import hmac
import json
import logging
import secrets
import time
from typing import Any

import jwt
import pyotp
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHash, VerificationError
from cryptography.fernet import Fernet, InvalidToken

from .config import settings

_ITERATIONS = 260_000

_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, stored: str) -> bool:
    if stored.startswith("$argon2"):
        try:
            return _hasher.verify(stored, password)
        except (VerificationError, InvalidHash, ValueError):
            return False
    return _verify_legacy_pbkdf2(password, stored)


def _verify_legacy_pbkdf2(password: str, stored: str) -> bool:
    """Verify hashes created before the move to Argon2."""
    try:
        iterations, salt_b64, hash_b64 = stored.split("$")
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(hash_b64)
        digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, int(iterations))
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(digest, expected)


def create_token(payload: dict[str, Any], ttl_seconds: int | None = None) -> str:
    now = int(time.time())
    claims = {
        **payload,
        "iat": now,
        "exp": now + (ttl_seconds or settings.TOKEN_TTL_SECONDS),
        "jti": secrets.token_hex(8),
    }
    return jwt.encode(claims, settings.SECRET_KEY, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise ValueError("Invalid token") from None


def decode_room_token(token: str, request_id: int) -> int:
    payload = decode_token(token)
    try:
        if (
            payload.get("scope") != "request_room"
            or int(payload["request_id"]) != request_id
        ):
            raise ValueError("Invalid room token scope")
        return int(payload["sub"])
    except (KeyError, TypeError, ValueError):
        raise ValueError("Invalid room token scope") from None


def _contact_fernet() -> Fernet:
    key = settings.CONTACT_ENCRYPTION_KEY
    if key is None:
        print("[WARNING] CONTACT_ENCRYPTION_KEY is None, randomizing...")
        digest = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
        key = base64.urlsafe_b64encode(digest).decode()
    try:
        return Fernet(key.encode())
    except (TypeError, ValueError):
        raise RuntimeError(
            "CONTACT_ENCRYPTION_KEY must be a valid Fernet key"
        ) from None


def encrypt_contact(value: str) -> str:
    return _contact_fernet().encrypt(value.encode()).decode()


def decrypt_contact(value: str) -> str:
    try:
        return _contact_fernet().decrypt(value.encode()).decode()
    except InvalidToken:
        raise RuntimeError("Unable to decrypt private contact data") from None


def generate_totp_secret() -> str:
    return pyotp.random_base32()


def get_totp_uri(secret: str, email: str) -> str:
    totp = pyotp.TOTP(secret)
    return totp.provisioning_uri(name=email, issuer_name="Handover")


def verify_totp(secret: str, code: str) -> bool:
    totp = pyotp.TOTP(secret)
    return totp.verify(code, valid_window=1)


def generate_recovery_codes(count: int = 8) -> list[str]:
    return [secrets.token_hex(4).upper() for _ in range(count)]


def hash_recovery_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def store_recovery_codes(codes: list[str]) -> str:
    hashed = [hash_recovery_code(c) for c in codes]
    return json.dumps(hashed)


def verify_recovery_code(code: str, stored_json: str) -> bool:
    try:
        hashed_stored = json.loads(stored_json)
    except (json.JSONDecodeError, TypeError):
        return False
    code_hash = hash_recovery_code(code)
    return code_hash in hashed_stored


def remove_recovery_code(code: str, stored_json: str) -> str | None:
    try:
        hashed_stored = json.loads(stored_json)
    except (json.JSONDecodeError, TypeError):
        return None
    code_hash = hash_recovery_code(code)
    updated = [h for h in hashed_stored if h != code_hash]
    if len(updated) == len(hashed_stored):
        return None
    return json.dumps(updated)


def encrypt_totp_secret(secret: str) -> str:
    return _contact_fernet().encrypt(secret.encode()).decode()


def decrypt_totp_secret(encrypted: str) -> str:
    try:
        return _contact_fernet().decrypt(encrypted.encode()).decode()
    except InvalidToken:
        raise RuntimeError("Unable to decrypt TOTP secret") from None


def generate_email_code() -> str:
    return f"{secrets.randbelow(10**6):06d}"


def hash_email_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def verify_email_code(code: str, stored_hash: str) -> bool:
    return hash_email_code(code) == stored_hash
