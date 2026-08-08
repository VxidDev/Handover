import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"


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


settings = Settings()