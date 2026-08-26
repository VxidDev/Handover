from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import ChatMessage, MessageReadCursor, Rating, Request, Skill, User
from ..schemas import (
    ChatMessageOut,
    RatingIn,
    RatingOut,
    RequestCreateIn,
    RequestOut,
    RequestUpdateIn,
)

router = APIRouter(prefix="/requests", tags=["requests"])

VALID_STATUSES = {"pending", "accepted", "declined", "cancelled", "completed"}


def _to_out(
    req: Request,
    last_message: ChatMessage | None = None,
    unread_count: int = 0,
) -> RequestOut:
    last_msg_out = None
    if last_message is not None:
        last_msg_out = ChatMessageOut(
            id=last_message.id,
            request_id=last_message.request_id,
            sender_id=last_message.sender_id,
            sender_name=last_message.sender.name,
            body=last_message.body,
            created_at=last_message.created_at,
            image_url=last_message.image_url,
        )
    return RequestOut(
        id=req.id,
        status=req.status,
        message=req.message,
        created_at=req.created_at,
        updated_at=req.updated_at,
        requester_id=req.requester_id,
        requester_name=req.requester.name,
        requester_profile_image=req.requester.profile_image,
        provider_id=req.provider_id,
        provider_name=req.provider.name,
        provider_profile_image=req.provider.profile_image,
        skill_name=req.skill.name,
        last_message=last_msg_out,
        unread_count=unread_count,
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
    offset: int = Query(default=0, ge=0),
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

    requests = (
        query.order_by(Request.created_at.desc()).offset(offset).limit(amount).all()
    )
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
def update_request(  # noqa: C901
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


@router.post(
    "/{request_id}/rate",
    response_model=RatingOut,
    status_code=status.HTTP_201_CREATED,
)
def rate_request(
    request_id: int,
    payload: RatingIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    req = db.get(Request, request_id)
    if req is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Request not found"
        )
    if req.status != "completed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Only completed requests can be rated",
        )
    if user.id not in (req.requester_id, req.provider_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only request participants can rate",
        )
    rated_id = req.provider_id if user.id == req.requester_id else req.requester_id
    existing = (
        db.query(Rating)
        .filter(Rating.request_id == request_id, Rating.rater_id == user.id)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have already rated this request",
        )
    rating = Rating(
        request_id=request_id,
        rater_id=user.id,
        rated_id=rated_id,
        stars=payload.stars,
        review=payload.review,
    )
    db.add(rating)
    db.commit()
    db.refresh(rating)
    return RatingOut(
        id=rating.id,
        request_id=rating.request_id,
        rater_id=rating.rater_id,
        rater_name=user.name,
        rated_id=rating.rated_id,
        stars=rating.stars,
        review=rating.review,
        created_at=rating.created_at,
    )


@router.get("/conversations", response_model=list[RequestOut])
def conversations(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    requests = (
        db.query(Request)
        .filter(
            (Request.requester_id == user.id) | (Request.provider_id == user.id),
            Request.status.in_(["accepted", "completed"]),
        )
        .all()
    )
    result = []
    for req in requests:
        if req.skill is None:
            continue
        last_message = (
            db.query(ChatMessage)
            .filter(ChatMessage.request_id == req.id)
            .order_by(ChatMessage.created_at.desc(), ChatMessage.id.desc())
            .first()
        )
        cursor = (
            db.query(MessageReadCursor)
            .filter(
                MessageReadCursor.user_id == user.id,
                MessageReadCursor.request_id == req.id,
            )
            .first()
        )
        last_read = cursor.last_read_message_id if cursor else 0
        unread = (
            db.query(ChatMessage)
            .filter(
                ChatMessage.request_id == req.id,
                ChatMessage.id > last_read,
                ChatMessage.sender_id != user.id,
            )
            .count()
        )
        result.append(_to_out(req, last_message=last_message, unread_count=unread))
    result.sort(
        key=lambda r: r.last_message.created_at if r.last_message else r.updated_at,
        reverse=True,
    )
    return result
