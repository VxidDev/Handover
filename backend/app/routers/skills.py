import math
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..deps import get_current_user_optional
from ..models import Skill, User
from ..schemas import SkillSearchOut

router = APIRouter(prefix="/skills", tags=["skills"])

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlng / 2) ** 2
    )
    return EARTH_RADIUS_KM * 2 * math.asin(math.sqrt(a))


@router.get("", response_model=list[SkillSearchOut])
def search_skills(
    q: str = Query(default="", max_length=100),
    radius_km: Optional[float] = Query(default=None, ge=0),
    lat: Optional[float] = Query(default=None, ge=-90, le=90),
    lng: Optional[float] = Query(default=None, ge=-180, le=180),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    query = db.query(Skill).options(joinedload(Skill.owner)).join(User)
    keyword = q.strip().lower()
    if keyword:
        like = f"%{keyword}%"
        query = query.filter(
            (Skill.name.ilike(like)) | (Skill.blurb.ilike(like)) | (User.name.ilike(like))
        )
    if current_user is not None:
        query = query.filter(Skill.user_id != current_user.id)

    results: list[SkillSearchOut] = []
    for skill in query.order_by(Skill.name.asc()).all():
        owner = skill.owner
        distance = None
        if lat is not None and lng is not None and owner.lat is not None and owner.lng is not None:
            distance = round(haversine_km(lat, lng, owner.lat, owner.lng), 1)
            if radius_km is not None and distance > radius_km:
                continue
        results.append(
            SkillSearchOut(
                skill_id=skill.id,
                skill_name=skill.name,
                blurb=skill.blurb,
                owner_id=owner.id,
                owner_name=owner.name,
                grid=owner.grid,
                distance_km=distance,
                available=owner.is_available,
                karma=owner.karma,
            )
        )
    return results