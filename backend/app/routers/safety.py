from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import BlockedUser, Report, User
from ..schemas import BlockIn, ReportIn

router = APIRouter(prefix="/safety", tags=["safety"])


@router.post("/report", status_code=status.HTTP_201_CREATED)
def report_user(
    payload: ReportIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.reported_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot report yourself"
        )
    reported = db.get(User, payload.reported_id)
    if reported is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    report = Report(
        reporter_id=user.id,
        reported_id=payload.reported_id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    db.commit()
    return {"message": "Report submitted"}


@router.post("/block", status_code=status.HTTP_201_CREATED)
def block_user(
    payload: BlockIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.blocked_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot block yourself"
        )
    blocked = db.get(User, payload.blocked_id)
    if blocked is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    existing = (
        db.query(BlockedUser)
        .filter(
            BlockedUser.blocker_id == user.id,
            BlockedUser.blocked_id == payload.blocked_id,
        )
        .first()
    )
    if existing:
        return {"message": "Already blocked"}
    db.add(BlockedUser(blocker_id=user.id, blocked_id=payload.blocked_id))
    db.commit()
    return {"message": "User blocked"}


@router.post("/unblock", status_code=status.HTTP_204_NO_CONTENT)
def unblock_user(
    payload: BlockIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    db.query(BlockedUser).filter(
        BlockedUser.blocker_id == user.id,
        BlockedUser.blocked_id == payload.blocked_id,
    ).delete()
    db.commit()
