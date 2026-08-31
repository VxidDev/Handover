from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import OneSignalPlayer, User

router = APIRouter(prefix="/onesignal", tags=["onesignal"])


class PlayerRegisterIn(BaseModel):
    player_id: str = Field(min_length=1, max_length=255)


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register_player(
    payload: PlayerRegisterIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    existing = (
        db.query(OneSignalPlayer)
        .filter(OneSignalPlayer.player_id == payload.player_id)
        .first()
    )
    if existing is not None:
        if existing.user_id != user.id:
            existing.user_id = user.id
            db.commit()
        return {"ok": True}

    player = OneSignalPlayer(user_id=user.id, player_id=payload.player_id)
    db.add(player)
    db.commit()
    return {"ok": True}


@router.delete("/unregister", status_code=status.HTTP_204_NO_CONTENT)
def unregister_player(
    player_id: str = "",
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = db.query(OneSignalPlayer).filter(OneSignalPlayer.user_id == user.id)
    if player_id:
        query = query.filter(OneSignalPlayer.player_id == player_id)
    query.delete()
    db.commit()
