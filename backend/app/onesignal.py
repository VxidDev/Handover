import logging

import httpx

from .config import settings

logger = logging.getLogger("handover.onesignal")

_ONESIGNAL_API = "https://onesignal.com/api/v1/notifications"


async def send_push(
    player_ids: list[str],
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    if not settings.ONESIGNAL_APP_ID or not settings.ONESIGNAL_REST_API_KEY:
        return
    if not player_ids:
        return

    payload = {
        "app_id": settings.ONESIGNAL_APP_ID,
        "include_subscription_ids": player_ids,
        "headings": {"en": title},
        "contents": {"en": body},
    }
    if data:
        payload["data"] = data

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                _ONESIGNAL_API,
                json=payload,
                headers={
                    "Authorization": f"Key {settings.ONESIGNAL_REST_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code >= 400:
                logger.warning("OneSignal push failed: %s %s", resp.status_code, resp.text)
    except Exception:
        logger.exception("OneSignal push error")
