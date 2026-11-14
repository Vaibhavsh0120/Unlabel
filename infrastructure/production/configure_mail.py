"""One-time local SMTP credential entry; never paste the key into chat or arguments."""

import getpass
import json
import os
import smtplib
import ssl
import sys
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from project_secrets import private_directory


def main():
    if not sys.stdin.isatty():
        raise SystemExit(
            "Run this in an interactive local terminal so input can stay hidden."
        )
    username = input("Brevo SMTP login (shown in Brevo SMTP settings): ").strip()
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        try:
            password = getpass.getpass("Brevo SMTP key (hidden): ").strip()
        except (getpass.GetPassWarning, EOFError):
            raise SystemExit(
                "This terminal cannot hide input; nothing was saved."
            ) from None
    if (
        not username
        or not password
        or any(character in username + password for character in "\r\n\x00")
    ):
        raise SystemExit("A valid SMTP login and key are required.")
    try:
        with smtplib.SMTP("smtp-relay.brevo.com", 587, timeout=15) as client:
            client.ehlo()
            client.starttls(context=ssl.create_default_context())
            client.ehlo()
            client.login(username, password)
    except Exception:
        raise SystemExit(
            "SMTP authentication failed; no credentials were saved and no email was sent."
        ) from None
    directory = ROOT / "infrastructure/production/.secrets"
    directory.mkdir(parents=True, exist_ok=True)
    private_directory(directory)
    payload = {
        "host": "smtp-relay.brevo.com",
        "port": 587,
        "username": username,
        "password": password,
        "sender_email": "vaibhavsh0120@gmail.com",
        "sender_name": "Unlabel",
    }
    staging = directory / "mail-settings.new"
    target = directory / "mail-settings"
    try:
        with staging.open("x", encoding="utf-8") as output:
            output.write(json.dumps(payload))
        staging.chmod(0o600)
        os.replace(staging, target)
    finally:
        staging.unlink(missing_ok=True)
    print("SMTP authenticated successfully. No email was sent.")
    print("Credentials saved in the ignored production secret directory.")
    print("Next run: .\\secrets.ps1 encrypt")


if __name__ == "__main__":
    main()
