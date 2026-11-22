from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.selfhost.mail import send_welcome
from pydantic import SecretStr


def test_welcome_mail_has_branded_html_and_plain_text_without_remote_images():
    settings = SimpleNamespace(smtp_host='smtp.example.test', smtp_port=587,
        smtp_user='synthetic', smtp_password=SecretStr('synthetic-smtp-test'),
        smtp_sender='welcome@example.test', frontend_url='https://example.test/?a=1&b=2')
    smtp = MagicMock()
    with patch('app.selfhost.mail.smtplib.SMTP') as constructor:
        constructor.return_value.__enter__.return_value = smtp
        send_welcome(settings, 'scanner@example.test')
    message = smtp.send_message.call_args.args[0]
    assert message.get_content_type() == 'multipart/alternative'
    assert 'Your account is ready' in message.get_body(preferencelist=('plain',)).get_content()
    html = message.get_body(preferencelist=('html',)).get_content()
    assert 'YOUR ACCOUNT IS READY' in html and 'Open Unlabel' in html
    assert 'https://example.test/?a=1&amp;b=2' in html
    assert '{{app_url}}' not in html and '<script' not in html and '<img' not in html
    assert 'synthetic-smtp-test' not in html
    smtp.starttls.assert_called_once()
