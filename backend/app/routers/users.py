import logging
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..legal import CONTROLLER_EMAIL, CONTROLLER_NAME
from ..models import (
    ChatMessage,
    DisclosureLog,
    PrivateContact,
    Rating,
    Request,
    Skill,
    SkillImage,
    User,
    utcnow,
)
from ..schemas import RatingOut, SkillCreateIn, SkillOut, UserMeOut, UserUpdateIn
from ..security import decrypt_contact, encrypt_contact
from .skills import invalidate_catalog

logger = logging.getLogger("handover.users")

router = APIRouter(prefix="/users", tags=["users"])

UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"


def user_me_out(user: User) -> UserMeOut:
    result = UserMeOut.model_validate(user)
    if user.private_contact is not None:
        try:
            result.phone = decrypt_contact(user.private_contact.encrypted_phone)
        except Exception:
            logger.exception("Failed to decrypt phone for user %d", user.id)
    return result


@router.get("/me", response_model=UserMeOut)
def me(user: User = Depends(get_current_user)):
    return user_me_out(user)


@router.patch("/me", response_model=UserMeOut)
def update_me(
    payload: UserUpdateIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    changes = payload.model_dump(exclude_unset=True)
    if "phone" in changes:
        phone = changes.pop("phone")
        phone = phone.strip() if phone is not None else ""
        if phone:
            if user.private_contact is None:
                user.private_contact = PrivateContact(
                    encrypted_phone=encrypt_contact(phone)
                )
            else:
                user.private_contact.encrypted_phone = encrypt_contact(phone)
        elif user.private_contact is not None:
            db.delete(user.private_contact)
            user.private_contact = None
    if "profile_image" in changes:
        old_image = user.profile_image
        new_image = changes["profile_image"]
        if old_image and old_image != new_image:
            _remove_uploaded_file(old_image)
    for field, value in changes.items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    invalidate_catalog()
    return user_me_out(user)


@router.post("/me/skills", response_model=SkillOut, status_code=status.HTTP_201_CREATED)
def add_skill(
    payload: SkillCreateIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    skill = Skill(
        user_id=user.id, name=payload.name.strip(), blurb=payload.blurb.strip()
    )
    db.add(skill)
    db.flush()  # Get skill.id

    for i, path in enumerate(payload.image_paths[:3]):
        db.add(SkillImage(skill_id=skill.id, path=path, order=i))

    db.commit()
    db.refresh(skill)
    invalidate_catalog()
    return SkillOut.model_validate(skill)


@router.delete("/me/skills/{skill_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_skill(
    skill_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    skill = db.get(Skill, skill_id)
    if skill is None or skill.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found"
        )
    db.delete(skill)
    db.commit()
    invalidate_catalog()


def _skill_image_paths(user: User) -> list[str]:
    return [image.path for skill in user.skills for image in skill.images]


def _all_uploaded_paths(user: User) -> list[str]:
    paths = _skill_image_paths(user)
    if user.profile_image:
        paths.append(user.profile_image)
    return paths


def _remove_uploaded_file(path: str) -> None:
    if not path.startswith("/uploads/"):
        return
    try:
        (UPLOAD_DIR / path.removeprefix("/uploads/")).unlink(missing_ok=True)
    except OSError as exc:
        logger.warning("Failed to remove uploaded file %s: %s", path, exc)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Erase the account and all associated personal data (GDPR erasure)."""
    image_paths = _all_uploaded_paths(user)
    db.delete(user)
    db.commit()
    invalidate_catalog()
    for path in image_paths:
        _remove_uploaded_file(path)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me/export")
def export_me(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Return all personal data in a portable, machine-readable format."""
    skill_rows = (
        db.query(Skill).filter(Skill.user_id == user.id).order_by(Skill.id).all()
    )
    request_rows = (
        db.query(Request)
        .filter((Request.requester_id == user.id) | (Request.provider_id == user.id))
        .order_by(Request.id)
        .all()
    )
    request_ids = [req.id for req in request_rows]
    message_rows = (
        db.query(ChatMessage)
        .filter(ChatMessage.request_id.in_(request_ids))
        .order_by(ChatMessage.id)
        .all()
        if request_ids
        else []
    )
    disclosure_rows = (
        db.query(DisclosureLog)
        .filter(DisclosureLog.owner_id == user.id)
        .order_by(DisclosureLog.id)
        .all()
    )

    phone = None
    if user.private_contact is not None:
        try:
            phone = decrypt_contact(user.private_contact.encrypted_phone)
        except Exception:
            logger.exception(
                "Failed to decrypt phone during export for user %d", user.id
            )

    return {
        "generated_at": utcnow().isoformat(),
        "controller": {"name": CONTROLLER_NAME, "email": CONTROLLER_EMAIL},
        "account": {
            "email": user.email,
            "name": user.name,
            "is_available": user.is_available,
            "karma": user.karma,
            "grid": user.grid,
            "lat": user.lat,
            "lng": user.lng,
            "phone": phone,
            "profile_image": user.profile_image,
            "created_at": user.created_at.isoformat(),
            "tos_accepted_at": (
                user.tos_accepted_at.isoformat() if user.tos_accepted_at else None
            ),
            "privacy_accepted_at": (
                user.privacy_accepted_at.isoformat()
                if user.privacy_accepted_at
                else None
            ),
            "tos_version": user.tos_version,
            "privacy_version": user.privacy_version,
        },
        "skills": [
            {
                "id": skill.id,
                "name": skill.name,
                "blurb": skill.blurb,
                "created_at": skill.created_at.isoformat(),
                "images": [image.path for image in skill.images],
            }
            for skill in skill_rows
        ],
        "requests": [
            {
                "id": req.id,
                "status": req.status,
                "message": req.message,
                "skill_id": req.skill_id,
                "requester_id": req.requester_id,
                "provider_id": req.provider_id,
                "provider_share_phone": req.provider_share_phone,
                "created_at": req.created_at.isoformat(),
                "updated_at": req.updated_at.isoformat(),
            }
            for req in request_rows
        ],
        "chat_messages": [
            {
                "id": msg.id,
                "request_id": msg.request_id,
                "sender_id": msg.sender_id,
                "body": msg.body,
                "created_at": msg.created_at.isoformat(),
            }
            for msg in message_rows
        ],
        "disclosure_logs": [
            {
                "id": log.id,
                "request_id": log.request_id,
                "viewer_id": log.viewer_id,
                "field": log.field,
                "reason": log.reason,
                "created_at": log.created_at.isoformat(),
            }
            for log in disclosure_rows
        ],
    }


@router.get("/{user_id}/ratings", response_model=list[RatingOut])
def get_user_ratings(
    user_id: int,
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    ratings = (
        db.query(Rating)
        .filter(Rating.rated_id == user_id)
        .order_by(Rating.created_at.desc())
        .all()
    )
    result = []
    for rating in ratings:
        rater = db.get(User, rating.rater_id)
        result.append(
            RatingOut(
                id=rating.id,
                request_id=rating.request_id,
                rater_id=rating.rater_id,
                rater_name=rater.name if rater else "Unknown",
                rated_id=rating.rated_id,
                stars=rating.stars,
                review=rating.review,
                created_at=rating.created_at,
            )
        )
    return result
