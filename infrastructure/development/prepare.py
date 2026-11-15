"""Create non-overwriting, local-only development secrets without printing values."""

import hashlib
import os
import secrets
from pathlib import Path


def create(path: Path, value: str) -> None:
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        return
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as target:
        target.write(value)


def main():
    directory = Path(__file__).resolve().parent / ".secrets"
    directory.mkdir(mode=0o700, exist_ok=True)
    for name in ("pg-app", "pg-auth", "mongo-admin", "cache-password", "jobs-password"):
        create(directory / name, secrets.token_urlsafe(48))
    for name in ("cache", "jobs"):
        password = (directory / f"{name}-password").read_text(encoding="utf-8")
        digest = hashlib.sha256(password.encode()).hexdigest()
        create(directory / f"{name}-acl", "user default off\n"
               f"user unlabel on #{digest} ~unlabel:* &unlabel:* "
               "+@read +@write +@connection +@scripting +@transaction -@dangerous\n")
    print("Local development secrets are ready; existing values were preserved.")


if __name__ == "__main__":
    main()
