from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Skill, User
from ..schemas import SkillCreateIn, SkillOut, UserMeOut, UserUpdateIn

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserMeOut)
def me(user: User = Depends(get_current_user)):
    return UserMeOut.model_validate(user)


@router.patch("/me", response_model=UserMeOut)
def update_me(payload: UserUpdateIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return UserMeOut.model_validate(user)


@router.post("/me/skills", response_model=SkillOut, status_code=status.HTTP_201_CREATED)
def add_skill(payload: SkillCreateIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    skill = Skill(user_id=user.id, name=payload.name.strip(), blurb=payload.blurb.strip())
    db.add(skill)
    db.commit()
    db.refresh(skill)
    return SkillOut.model_validate(skill)


@router.delete("/me/skills/{skill_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_skill(skill_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    skill = db.get(Skill, skill_id)
    if skill is None or skill.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found")
    db.delete(skill)
    db.commit()