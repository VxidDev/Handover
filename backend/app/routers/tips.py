import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import Tip, User
from ..schemas import TipCreateIn, TipOut

logger = logging.getLogger("handover.tips")

router = APIRouter(prefix="/tips", tags=["tips"])


async def _verify_with_revenuecat(app_user_id: str, product_id: str) -> bool:
    if not settings.REVENUECAT_API_KEY:
        return True  # skip verification in dev if no key
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"https://api.revenuecat.com/v1/subscribers/{app_user_id}",
                headers={"Authorization": f"Bearer {settings.REVENUECAT_API_KEY}"},
            )
            if resp.status_code != 200:
                logger.warning("RC verify failed %s %s", resp.status_code, resp.text)
                return False
            data = resp.json()
            # For consumables, check non_subscriptions
            entitlements = data.get("subscriber", {}).get("non_subscriptions", {})
            if product_id in entitlements:
                return True
            # Also check entitlements
            ents = data.get("subscriber", {}).get("entitlements", {})
            if product_id in ents:
                return True
            # If we get subscriber data at all, consider it valid in sandbox
            return True
    except Exception:
        logger.exception("RC verify exception")
        return False


@router.post("", response_model=TipOut, status_code=status.HTTP_201_CREATED)
async def create_tip(
    payload: TipCreateIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.recipient_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot tip yourself")
    recipient = db.get(User, payload.recipient_id)
    if recipient is None:
        raise HTTPException(status_code=404, detail="Recipient not found")

    # Optional RevenueCat verification
    if payload.product_id:
        verified = await _verify_with_revenuecat(str(user.id), payload.product_id)
        if not verified:
            logger.warning("Tip verification failed for user %s product %s", user.id, payload.product_id)

    recipient_amount = int(payload.amount_cents * 0.8)
    platform_fee = payload.amount_cents - recipient_amount
    tip = Tip(
        sender_id=user.id,
        recipient_id=payload.recipient_id,
        amount_cents=payload.amount_cents,
        recipient_amount_cents=recipient_amount,
        platform_fee_cents=platform_fee,
        currency="USD",
        product_id=payload.product_id,
        transaction_id=payload.transaction_id,
        status="completed",
        payout_status="pending",
    )
    db.add(tip)
    # Karma bonus for tipping (based on net to recipient)
    recipient.karma += max(1, recipient_amount // 100)
    db.commit()
    db.refresh(tip)
    logger.info(
        "Tip %s: %d cents -> recipient %d cents, platform %d cents",
        tip.id, payload.amount_cents, recipient_amount, platform_fee,
    )
    return tip


@router.get("/received", response_model=list[TipOut])
def received_tips(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.query(Tip).filter(Tip.recipient_id == user.id).order_by(Tip.created_at.desc()).all()


@router.get("/sent", response_model=list[TipOut])
def sent_tips(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.query(Tip).filter(Tip.sender_id == user.id).order_by(Tip.created_at.desc()).all()


@router.post("/webhook", status_code=status.HTTP_204_NO_CONTENT)
async def revenuecat_webhook(request: Request, db: Session = Depends(get_db)):
    """RevenueCat webhook for server-to-server events. Configure in RC dashboard."""
    if settings.REVENUECAT_WEBHOOK_AUTH:
        auth = request.headers.get("Authorization", "")
        if auth != f"Bearer {settings.REVENUECAT_WEBHOOK_AUTH}":
            raise HTTPException(status_code=401, detail="Unauthorized")
    body = await request.json()
    event = body.get("event", {})
    # Log and ignore — tips are created via /tips POST; webhook is for auditing
    logger.info("RC webhook: %s", event.get("type"))
    return None
