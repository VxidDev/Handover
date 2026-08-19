import math
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from ..cache import SKILLS_CATALOG_KEY, cache
from ..database import get_db
from ..deps import get_current_user_optional
from ..models import Skill, User
from ..schemas import SkillSearchOut

router = APIRouter(prefix="/skills", tags=["skills"])

EARTH_RADIUS_KM = 6371.0


def _load_catalog(db: Session) -> list[dict[str, Any]]:
    rows = (
        db.query(Skill)
        .options(joinedload(Skill.owner), joinedload(Skill.images))
        .join(User)
        .order_by(Skill.name.asc())
        .all()
    )
    return [
        {
            "skill_id": skill.id,
            "skill_name": skill.name,
            "blurb": skill.blurb,
            "user_id": skill.user_id,
            "owner_name": skill.owner.name,
            "grid": skill.owner.grid,
            "lat": skill.owner.lat,
            "lng": skill.owner.lng,
            "available": skill.owner.is_available,
            "karma": skill.owner.karma,
            "images": [img.path for img in skill.images],
        }
        for skill in rows
    ]


def get_catalog(db: Session) -> list[dict[str, Any]]:
    return cache.get_or_set(SKILLS_CATALOG_KEY, lambda: _load_catalog(db))


def invalidate_catalog() -> None:
    cache.delete(SKILLS_CATALOG_KEY)


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
    radius_km: float | None = Query(default=None, ge=0),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_current_user_optional),
):
    keyword = q.strip().lower()
    results: list[SkillSearchOut] = []
    for entry in get_catalog(db):
        if current_user is not None and entry["user_id"] == current_user.id:
            continue
        if keyword:
            haystack = (
                entry["skill_name"] + entry["blurb"] + entry["owner_name"]
            ).lower()
            if keyword not in haystack:
                continue
        distance = None
        if (
            lat is not None
            and lng is not None
            and entry["lat"] is not None
            and entry["lng"] is not None
        ):
            distance = round(haversine_km(lat, lng, entry["lat"], entry["lng"]), 1)

            if radius_km is not None and distance > radius_km:
                continue

        results.append(
            SkillSearchOut(
                skill_id=entry["skill_id"],
                skill_name=entry["skill_name"],
                blurb=entry["blurb"],
                owner_id=entry["user_id"],
                owner_name=entry["owner_name"],
                grid=entry["grid"],
                distance_km=distance,
                available=entry["available"],
                karma=entry["karma"],
                images=entry["images"],
            )
        )
    return results
