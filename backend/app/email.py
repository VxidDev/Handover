import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import aiosmtplib

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
    .button {{
      display: inline-block; background-color: #4F46E5; color: white;
      text-decoration: none; padding: 12px 24px; border-radius: 6px;
      font-weight: 500; margin: 16px 0;
    }}
    .footer {{ margin-top: 32px; font-size: 14px; color: #666; }}
  </style>
</head>
<body>
  <h2>Reset your password</h2>
  <p>You requested a password reset for your Handover account.</p>
  <p>Click the button below to set a new password. This link expires in 1 hour.</p>
  <a href="{reset_url}" class="button">Reset Password</a>
  <p>If the button doesn't work, copy this link into your browser:</p>
  <p><a href="{reset_url}">{reset_url}</a></p>
  <div class="footer">
    <p>If you didn't request this, you can safely ignore this email.</p>
  </div>
</body>
</html>
"""

RESET_PASSWORD_TEXT = """\
Reset your password

You requested a password reset for your Handover account.

Open the link below to set a new password. This link expires in 1 hour.

{reset_url}

If you didn't request this, you can safely ignore this email.
"""


def _build_reset_email(to_email: str, reset_url: str) -> MIMEMultipart:
    msg = MIMEMultipart("alternative")
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email
    msg["Subject"] = RESET_PASSWORD_SUBJECT
    msg.attach(MIMEText(RESET_PASSWORD_TEXT.format(reset_url=reset_url), "plain"))
    msg.attach(MIMEText(RESET_PASSWORD_HTML.format(reset_url=reset_url), "html"))
    return msg


async def send_password_reset_email(to_email: str, token: str) -> None:
    reset_url = f"{settings.FRONTEND_URL}/reset-password?token={token}"
    msg = _build_reset_email(to_email, reset_url)

    if not settings.SMTP_HOST:
        logger.warning(
            "SMTP_HOST not configured — skipping email to %s (reset URL: %s)",
            to_email,
            reset_url,
        )
        return

    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USERNAME or None,
            password=settings.SMTP_PASSWORD or None,
            use_tls=False,
            start_tls=settings.SMTP_TLS,
        )
        logger.info("Password reset email sent to %s", to_email)
    except Exception:
        logger.exception("Failed to send password reset email to %s", to_email)
