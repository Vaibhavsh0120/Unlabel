"""Create missing local Web Push secrets without printing keys; encrypt before push."""

import base64
import secrets
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from dotenv import dotenv_values, set_key

ROOT = Path(__file__).resolve().parents[2]


def main():
    path = ROOT / "backend/.env"
    if not path.is_file():
        raise SystemExit("Restore the backend environment first.")
    values = dotenv_values(path)
    if bool(values.get("WEB_PUSH_PRIVATE_KEY")) != bool(values.get("WEB_PUSH_PUBLIC_KEY")):
        raise SystemExit("Incomplete Web Push key pair; resolve it before continuing.")
    if not values.get("WEB_PUSH_PRIVATE_KEY"):
        private = ec.generate_private_key(ec.SECP256R1())
        private_der = private.private_bytes(serialization.Encoding.DER,
                                           serialization.PrivateFormat.PKCS8,
                                           serialization.NoEncryption())
        public = private.public_key().public_bytes(serialization.Encoding.X962,
                                                   serialization.PublicFormat.UncompressedPoint)
        for key, value in {"WEB_PUSH_PRIVATE_KEY": private_der,
                           "WEB_PUSH_PUBLIC_KEY": public}.items():
            set_key(path, key, base64.urlsafe_b64encode(value).decode().rstrip("="))
    if not values.get("CRON_SECRET"):
        set_key(path, "CRON_SECRET", secrets.token_urlsafe(48))
    print("Local Web Push key pair and scheduler secret are configured; no values printed.")


if __name__ == "__main__":
    main()
