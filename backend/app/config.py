import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"

UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


def _default_secret() -> str:
    import secrets

    return secrets.token_hex(32)


class Settings:
    APP_NAME = "Handover API"
    API_PREFIX = "/api"
    DATABASE_URL = os.getenv(
        "DATABASE_URL", f"sqlite:///{(DATA_DIR / 'handover.db').as_posix()}"
    )
    SECRET_KEY = os.getenv("SECRET_KEY", _default_secret())
    TOKEN_TTL_SECONDS = int(os.getenv("TOKEN_TTL_SECONDS", str(60 * 60 * 24 * 7)))
    ROOM_TOKEN_TTL_SECONDS = int(os.getenv("ROOM_TOKEN_TTL_SECONDS", "900"))
    CONTACT_ENCRYPTION_KEY = os.getenv("CONTACT_ENCRYPTION_KEY")


settings = Settings()
