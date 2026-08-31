import logging
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..config import UPLOAD_DIR
from ..database import get_db
from ..deps import get_current_user
from ..models import BlockedUser, ChatMessage, PrivateContact, Rating, Report, Request, Skill, SkillImage, Tip, User, Warning
from ..schemas import SkillCreateIn, SkillOut, UserMeOut, UserUpdateIn
from ..security import decrypt_contact, encrypt_contact
from .skills import invalidate_catalog

logger = logging.getLogger("handover.users")

router = APIRouter(prefix="/users", tags=["users"])


def user_me_out(user: User) -> UserMeOut:
    result = UserMeOut.model_validate(user)
    if user.private_contact is not None:
        result.phone = decrypt_contact(user.private_contact.encrypted_phone)
    return result


@router.get("/me", response_model=UserMeOut)
def me(user: User = Depends(get_current_user)):
    return user_me_out(user)


@router.get("/me/export")
def export_my_data(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """GDPR data portability — return everything we hold about the user."""
    # Decrypt phone for export
    phone = None
    if user.private_contact is not None:
        try:
            phone = decrypt_contact(user.private_contact.encrypted_phone)
        except Exception:
            phone = None

    skills = db.query(Skill).filter(Skill.user_id == user.id).all()
    sent = db.query(Request).filter(Request.requester_id == user.id).all()
    received = db.query(Request).filter(Request.provider_id == user.id).all()
    messages = db.query(ChatMessage).filter(ChatMessage.sender_id == user.id).all()
    ratings_given = db.query(Rating).filter(Rating.rater_id == user.id).all()
    ratings_recv = db.query(Rating).filter(Rating.rated_id == user.id).all()
    tips_sent = db.query(Tip).filter(Tip.sender_id == user.id).all()
    tips_recv = db.query(Tip).filter(Tip.recipient_id == user.id).all()
    blocked = db.query(BlockedUser).filter(BlockedUser.blocker_id == user.id).all()
    reports_made = db.query(Report).filter(Report.reporter_id == user.id).all()
    warnings_list = db.query(Warning).filter(Warning.user_id == user.id).all()

    return {
        "user": {
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "is_available": user.is_available,
            "karma": user.karma,
            "lat": user.lat,
            "lng": user.lng,
            "grid": user.grid,
            "profile_image": user.profile_image,
            "phone": phone,
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "tos_accepted_at": user.tos_accepted_at.isoformat() if user.tos_accepted_at else None,
            "tos_version": user.tos_version,
            "privacy_accepted_at": user.privacy_accepted_at.isoformat() if user.privacy_accepted_at else None,
            "privacy_version": user.privacy_version,
            "two_factor_enabled": user.two_factor_enabled,
        },
        "skills": [
            {"id": s.id, "name": s.name, "blurb": s.blurb, "created_at": s.created_at.isoformat() if s.created_at else None, "images": [i.path for i in s.images]}
            for s in skills
        ],
        "requests_sent": [
            {"id": r.id, "provider_id": r.provider_id, "skill_id": r.skill_id, "status": r.status, "message": r.message, "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in sent
        ],
        "requests_received": [
            {"id": r.id, "requester_id": r.requester_id, "skill_id": r.skill_id, "status": r.status, "message": r.message, "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in received
        ],
        "messages": [
            {"id": m.id, "request_id": m.request_id, "body": m.body, "image_url": m.image_url, "created_at": m.created_at.isoformat() if m.created_at else None}
            for m in messages
        ],
        "ratings_given": [
            {"id": x.id, "request_id": x.request_id, "rated_id": x.rated_id, "stars": x.stars, "review": x.review, "created_at": x.created_at.isoformat() if x.created_at else None}
            for x in ratings_given
        ],
        "ratings_received": [
            {"id": x.id, "request_id": x.request_id, "rater_id": x.rater_id, "stars": x.stars, "review": x.review, "created_at": x.created_at.isoformat() if x.created_at else None}
            for x in ratings_recv
        ],
        "tips_sent": [
            {"id": t.id, "recipient_id": t.recipient_id, "amount_cents": t.amount_cents, "status": t.status, "created_at": t.created_at.isoformat() if t.created_at else None}
            for t in tips_sent
        ],
        "tips_received": [
            {"id": t.id, "sender_id": t.sender_id, "amount_cents": t.amount_cents, "recipient_amount_cents": t.recipient_amount_cents, "created_at": t.created_at.isoformat() if t.created_at else None}
            for t in tips_recv
        ],
        "blocked_users": [b.blocked_id for b in blocked],
        "reports_made": [
            {"id": r.id, "content_type": r.content_type, "content_id": r.content_id, "reason": r.reason, "status": r.status, "created_at": r.created_at.isoformat() if r.created_at else None}
            for r in reports_made
        ],
        "warnings": [
            {"id": w.id, "report_id": w.report_id, "reason": w.reason, "created_at": w.created_at.isoformat() if w.created_at else None}
            for w in warnings_list
        ],
        "exported_at": __import__("datetime").datetime.now(__import__("datetime").UTC).isoformat(),
    }


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """GDPR right to erasure + Play Data Deletion. Hard-delete user and cascade."""
    # Best-effort remove uploaded files referenced by this user
    try:
        if user.profile_image:
            # profile_image is /uploads/<name>
            p = Path(UPLOAD_DIR) / Path(user.profile_image).name
            if p.exists() and p.is_file():
                p.unlink(missing_ok=True)
        # skill images
        skill_ids = [s.id for s in db.query(Skill.id).filter(Skill.user_id == user.id).all()]
        if skill_ids:
            from ..models import SkillImage as _SI

            paths = [row[0] for row in db.query(_SI.path).filter(_SI.skill_id.in_(skill_ids)).all()]
            for rel in paths:
                pp = Path(UPLOAD_DIR) / Path(rel).name
                if pp.exists() and pp.is_file():
                    try:
                        pp.unlink(missing_ok=True)
                    except Exception:
                        pass
            # also chat image_urls that are /uploads/...
            msgs = db.query(ChatMessage.image_url).filter(ChatMessage.sender_id == user.id, ChatMessage.image_url.isnot(None)).all()
            for (url,) in msgs:
                if url and url.startswith("/uploads/"):
                    pp = Path(UPLOAD_DIR) / Path(url).name
                    if pp.exists() and pp.is_file():
                        try:
                            pp.unlink(missing_ok=True)
                        except Exception:
                            pass
    except Exception:
        logger.exception("Failed to clean up files for user %s", user.id)

    db.delete(user)
    db.commit()
    invalidate_catalog()
    return None


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
