from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import PrivateContact, Skill, SkillImage, User
from ..schemas import SkillCreateIn, SkillOut, UserMeOut, UserUpdateIn
from ..security import decrypt_contact, encrypt_contact
from .skills import invalidate_catalog

router = APIRouter(prefix="/users", tags=["users"])


def user_me_out(user: User) -> UserMeOut:
    result = UserMeOut.model_validate(user)
    if user.private_contact is not None:
        result.phone = decrypt_contact(user.private_contact.encrypted_phone)
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
