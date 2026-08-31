import logging
import uuid
from pathlib import Path

from anyio import to_thread
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from ..deps import get_current_user
from ..models import User
from ..moderation import moderate_image

logger = logging.getLogger("handover.uploads")

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB


def _write_file(filepath: Path, content: bytes) -> None:
    with open(filepath, "wb") as f:
        f.write(content)


@router.post("/images")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file type: {ext}. Use jpg, png, or webp.",
        )

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Max size is 5MB.",
        )

    # Play UGC image check — flag violations before storing (CSAM/NSFW placeholder)
    is_violation, reason = moderate_image(file.filename or "", content)
    if is_violation:
        logger.warning("Image upload blocked for user %s: %s", current_user.id, reason)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image rejected by moderation. Please choose a different image.",
        )

    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = UPLOAD_DIR / filename

    await to_thread.run_sync(_write_file, filepath, content)

    return {"path": f"/uploads/{filename}"}
