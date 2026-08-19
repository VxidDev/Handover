from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import ChatMessage, Report, Skill, User, Warning
from ..moderation import analyze
from ..schemas import ReportCreateIn, ReportOut, WarningOut

router = APIRouter(prefix="/reports", tags=["reports"])

_WARNING_REASON = {
    "skill": "inappropriate post",
    "chat_message": "inappropriate chat message",
}


def _warning_cutoff() -> datetime:
    return datetime.now(UTC) - timedelta(days=settings.WARNING_EXPIRY_DAYS)


def active_warning_count(db: Session, user: User) -> int:
    return (
        db.query(Warning)
        .filter(
            Warning.user_id == user.id,
            Warning.created_at >= _warning_cutoff(),
        )
        .count()
    )


def apply_ban_if_needed(db: Session, user: User) -> None:
    """Ban the user temporarily once active warnings exceed the threshold."""
    if active_warning_count(db, user) > settings.WARNING_BAN_THRESHOLD:
        user.banned_until = datetime.now(UTC) + timedelta(
            days=settings.WARNING_BAN_DURATION_DAYS
        )
        db.add(user)


def _resolve_target(
    db: Session, content_type: str, content_id: int
) -> tuple[User, str]:
    """Return the content owner and the text to moderate for a report target."""
    if content_type == "skill":
        skill = db.get(Skill, content_id)
        if skill is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Post not found"
            )
        text = f"{skill.name} {skill.blurb}".strip()
        return skill.owner, text
    if content_type == "chat_message":
        message = db.get(ChatMessage, content_id)
        if message is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Message not found"
            )
        return message.sender, message.body
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="Unsupported content type",
    )


def _report_out(report: Report) -> ReportOut:
    return ReportOut(
        id=report.id,
        content_type=report.content_type,
        content_id=report.content_id,
        status=report.status,
        toxicity_score=report.toxicity_score,
        warning_issued=report.status == "warning_issued",
        created_at=report.created_at,
    )


@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def create_report(
    payload: ReportCreateIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    owner, text = _resolve_target(db, payload.content_type, payload.content_id)
    if owner.id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot report your own content",
        )

    already_reported = (
        db.query(Report)
        .filter(
            Report.reporter_id == user.id,
            Report.content_type == payload.content_type,
            Report.content_id == payload.content_id,
        )
        .first()
    )
    if already_reported is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have already reported this content",
        )

    toxic, scores = analyze(text)
    peak = max(scores.values()) if scores else None

    report = Report(
        reporter_id=user.id,
        content_type=payload.content_type,
        content_id=payload.content_id,
        reason=payload.reason.strip(),
        status="warning_issued" if toxic else "dismissed",
        toxicity_score=peak,
    )
    db.add(report)
    db.flush()

    if toxic:
        db.add(
            Warning(
                user_id=owner.id,
                report_id=report.id,
                reason=_WARNING_REASON[payload.content_type],
            )
        )

    db.commit()
    apply_ban_if_needed(db, owner)
    db.commit()
    db.refresh(report)
    return _report_out(report)


@router.get("/mine", response_model=list[ReportOut])
def my_reports(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    reports = (
        db.query(Report)
        .filter(Report.reporter_id == user.id)
        .order_by(Report.created_at.desc())
        .all()
    )
    return [_report_out(report) for report in reports]


@router.get("/warnings", response_model=list[WarningOut])
def my_warnings(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    warnings = (
        db.query(Warning)
        .filter(Warning.user_id == user.id)
        .order_by(Warning.created_at.desc())
        .all()
    )
    return warnings
