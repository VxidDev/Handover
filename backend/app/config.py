import os
import sys
from pathlib import Path

from dotenv import load_dotenv

_env_path = Path(__file__).resolve().parent.parent / ".env"

if _env_path.exists():
    load_dotenv(_env_path)
else:
    print(f"[WARNING] .env file not found at {_env_path}", file=sys.stderr)

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)

UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


def _fail_startup(message: str) -> None:
    print(f"[FATAL] {message}", file=sys.stderr)
    sys.exit(1)


class Settings:
    APP_NAME = "Handover API"
    API_PREFIX = "/api"
    DATABASE_URL = os.getenv(
        "DATABASE_URL", f"sqlite:///{(DATA_DIR / 'handover.db').as_posix()}"
    )
    SECRET_KEY = os.getenv("SECRET_KEY")
    TOKEN_TTL_SECONDS = int(os.getenv("TOKEN_TTL_SECONDS", str(60 * 60 * 24 * 7)))
    ROOM_TOKEN_TTL_SECONDS = int(os.getenv("ROOM_TOKEN_TTL_SECONDS", "900"))
    CONTACT_ENCRYPTION_KEY = os.getenv("CONTACT_ENCRYPTION_KEY")

    def __init__(self) -> None:
        if not self.SECRET_KEY:
            _fail_startup(
                "SECRET_KEY is not set. Generate one with:\n"
                "  python -c \"import secrets; print(secrets.token_hex(32))\"\n"
                "Then set it in your .env or environment."
            )

        if not self.CONTACT_ENCRYPTION_KEY:
            _fail_startup(
                "CONTACT_ENCRYPTION_KEY is not set.\n"
                "Generate one with:\n"
                "  python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\"\n"
                "Then set it in your .env or environment.\n"
                "This key is used to encrypt phone numbers — losing it makes stored data unrecoverable."
            )

        self._validate_fernet_key()

    def _validate_fernet_key(self) -> None:
        import base64
        try:
            from cryptography.fernet import Fernet
            Fernet(self.CONTACT_ENCRYPTION_KEY.encode())
        except Exception:
            _fail_startup(
                f"CONTACT_ENCRYPTION_KEY is invalid.\n"
                f"Current value: {self.CONTACT_ENCRYPTION_KEY!r}\n"
                f"It must be a 44-character base64url string ending in '='.\n"
                f"Generate a valid one with:\n"
                f"  python -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
            )


settings = Settings()