"""Small, bounded transactional welcome email; signup never waits for SMTP."""

import logging
import smtplib
import ssl
from email.message import EmailMessage

logger = logging.getLogger("uvicorn.error")


def send_welcome(settings, email):
    if not getattr(settings, "smtp_host", "") or not settings.smtp_password:
        logger.warning("Welcome email unavailable: SMTP is not configured")
        return
    message = EmailMessage()
    message["Subject"] = "Welcome to Unlabel"
    message["From"] = f"Unlabel <{settings.smtp_sender}>"
    message["To"] = email
    message.set_content(
        "Welcome to Unlabel!\n\nYour account is ready. No email verification is needed.\n\n"
        "Search products, scan package labels, compare facts and save your reports.\n\n"
        f"Open Unlabel: {settings.frontend_url}\n\n"
        "If you did not create this account, you can ignore this email.\n\nThe Unlabel team\n"
    )
    for attempt in range(2):
        try:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=8) as client:
                client.ehlo()
                client.starttls(context=ssl.create_default_context())
                client.ehlo()
                client.login(settings.smtp_user, settings.smtp_password.get_secret_value())
                client.send_message(message)
            logger.info("Welcome email accepted by SMTP")
            return
        except (OSError, smtplib.SMTPException):
            if attempt:
                logger.warning("Welcome email delivery failed after retry")
