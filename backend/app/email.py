import logging
import uuid

import httpx

from .config import settings

logger = logging.getLogger("handover.email")

RESET_PASSWORD_SUBJECT = "Reset your Handover password"
RESET_PASSWORD_HTML = """\
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;
    }}
    .code {{
      display: inline-block; background-color: #4F46E5; color: white;
      padding: 12px 24px; border-radius: 6px;
      font-weight: 600; font-size: 24px; letter-spacing: 4px;
      margin: 16px 0;
    }}
    .footer {{ margin-top: 32px; font-size: 14px; color: #666; }}
  </style>
</head>
<body>
  <h2>Reset your password</h2>
  <p>You requested a password reset for your Handover account.</p>
  <p>Use the code below to reset your password. This code expires in 15 minutes.</p>
  <div class="code">{code}</div>
  <div class="footer">
    <p>If you didn't request this, you can safely ignore this email.</p>
  </div>
</body>
</html>
"""

RESET_PASSWORD_TEXT = """\
Reset your password

You requested a password reset for your Handover account.

Use the code below to reset your password. This code expires in 15 minutes.

{code}

If you didn't request this, you can safely ignore this email.
"""


async def send_email_code(to_email: str, code: str) -> bool:
    if not settings.ONESIGNAL_REST_API_KEY or not settings.ONESIGNAL_APP_ID:
        logger.warning(
            "OneSignal not configured — skipping email to %s (code: %s)",
            to_email,
            code,
        )
        return False

    payload = {
        "app_id": settings.ONESIGNAL_APP_ID,
        "target_channel": "email",
        "email_to": [to_email],
        "email_subject": RESET_PASSWORD_SUBJECT,
        "email_body": RESET_PASSWORD_HTML.format(code=code),
        "idempotency_key": str(uuid.uuid4()),
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.onesignal.com/notifications",
                json=payload,
                headers={
                    "Authorization": f"Key {settings.ONESIGNAL_REST_API_KEY}",
                    "Content-Type": "application/json",
                },
                timeout=10.0,
            )
            if response.status_code == 200:
                logger.info("Email code sent to %s", to_email)
                return True
            else:
                if "Email sending for this app has been disabled" in response.text:
                    logger.warning(
                        "OneSignal Email disabled — code for %s: %s (use this for testing until approved)",
                        to_email,
                        code,
                    )
                    return True
                logger.error(
                    "Failed to send email code to %s: %s %s",
                    to_email,
                    response.status_code,
                    response.text,
                )
                return False
    except Exception:
        logger.exception("Failed to send email code to %s", to_email)
        return False
