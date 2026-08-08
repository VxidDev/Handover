import base64
import hashlib
import hmac
import secrets
import time
from typing import Any

import jwt

from .config import settings

_ITERATIONS = 260_000


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, _ITERATIONS)
    return f"{_ITERATIONS}${base64.b64encode(salt).decode()}${base64.b64encode(digest).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        iterations, salt_b64, hash_b64 = stored.split("$")
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(hash_b64)
    except (ValueError, TypeError):
        return False
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, int(iterations))
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