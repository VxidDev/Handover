from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Request, Skill, User
from ..schemas import RequestCreateIn, RequestOut, RequestUpdateIn

router = APIRouter(prefix="/requests", tags=["requests"])

VALID_STATUSES = {"pending", "accepted", "declined", "cancelled", "completed"}


def _to_out(req: Request) -> RequestOut:
    return RequestOut(
        id=req.id,
        status=req.status,
        message=req.message,
        created_at=req.created_at,
        updated_at=req.updated_at,
        requester_id=req.requester_id,
        requester_name=req.requester.name,
        provider_id=req.provider_id,
        provider_name=req.provider.name,
        skill_name=req.skill.name,
    )


@router.post("", response_model=RequestOut, status_code=status.HTTP_201_CREATED)
def create_request(
    payload: RequestCreateIn,
    db: Session = Depends(get_db),
    requester: User = Depends(get_current_user),
):
    skill = db.get(Skill, payload.skill_id)
    if skill is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found"
        )
    if skill.user_id == requester.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot request your own skill",
        )
    if not skill.owner.is_available:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Neighbor is currently unavailable",
        )

    request = Request(
        requester_id=requester.id,
        provider_id=skill.user_id,
        skill_id=skill.id,
        message=payload.message,
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return _to_out(request)


@router.get("", response_model=list[RequestOut])
def list_requests(
    role: str = Query(default="all", pattern="^(all|sent|received)$"),
    status_filter: str = Query(default="all", alias="status"),
    amount: int = Query(default=50, ge=1, le=100),
    active_only: bool = Query(default=False, alias="active"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = db.query(Request)

    if role == "sent":
        query = query.filter(Request.requester_id == user.id)
    elif role == "received":
        query = query.filter(Request.provider_id == user.id)
    else:
        query = query.filter(
            or_(Request.requester_id == user.id, Request.provider_id == user.id)
        )

    if status_filter != "all":
        query = query.filter(Request.status == status_filter)

    if active_only:
        query = query.filter(Request.status.notin_(["cancelled", "completed"]))

    requests = query.order_by(Request.created_at.desc()).limit(amount).all()
    valid_requests = [r for r in requests if r.skill is not None]

    return [_to_out(r) for r in valid_requests]


@router.delete("/{request_id}", response_model=RequestOut)
def cancel_request(
    request_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    req = db.get(Request, request_id)
    if req is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Request not found"
        )
    if req.requester_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the requester can cancel this request",
        )
    if req.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Request already answered"
        )
    req.status = "cancelled"
    db.commit()
    db.refresh(req)
    return _to_out(req)


@router.patch("/{request_id}", response_model=RequestOut)
def update_request(
    request_id: int,
    payload: RequestUpdateIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    req = db.get(Request, request_id)
    if req is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Request not found"
        )
    if payload.status not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status: {payload.status}",
        )

    if payload.status in ("accepted", "declined"):
        if req.provider_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the skill owner can respond",
            )
        if req.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Request already answered"
            )
        req.status = payload.status
        req.provider_share_phone = (
            payload.share_phone if payload.status == "accepted" else False
        )
    elif payload.status == "completed":
        if req.status != "accepted":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Only accepted requests can be completed",
            )
        if user.id not in (req.requester_id, req.provider_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only request participants can complete it",
            )
        req.status = "completed"
        req.requester.karma += 1
        req.provider.karma += 1
    elif payload.status == "cancelled":
        if req.status != "accepted":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Only accepted requests can be withdrawn",
            )
        if user.id not in (req.requester_id, req.provider_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only request participants can withdraw",
            )
        req.status = "cancelled"
        user.karma -= 1
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot set status to {payload.status} via this endpoint",
        )

    db.commit()
    db.refresh(req)
    return _to_out(req)
