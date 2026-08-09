import base64
import hashlib
import hmac
import secrets
import time
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHash, VerificationError

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