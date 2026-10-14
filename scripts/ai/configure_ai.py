"""Save an optional AI key through a hidden prompt and refresh encrypted settings."""

import argparse
import getpass
import os
import re
import subprocess
import sys
import tempfile
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))


def save_key(provider: str, key: str) -> None:
    from app.ai.configuration import credentials
    from app.core.config import Settings

    if provider not in {"gemini", "openai"} or not 16 <= len(key) <= 512:
        raise ValueError("Invalid AI configuration")
    if any(ord(character) < 33 or ord(character) > 126 or character in {'"', "\\"} for character in key):
        raise ValueError("Invalid AI configuration")
    path = ROOT / "backend/.env"
    if path.is_symlink():
        raise ValueError("Environment must be a regular file")
    previous = path.read_bytes() if path.exists() else b""
    # Do not change an existing global selection by editing provider defaults.
    updates = {provider.upper() + "_API_KEY": key, "AI_ENABLED": "true"}
    previous_config = Settings(_env_file=path if path.exists() else None)
    configured_ids = {item.id for item in credentials(previous_config)} | {provider + "-primary"}
    if previous_config.ai_initial_credential_id not in configured_ids:
        updates["AI_INITIAL_CREDENTIAL_ID"] = provider + "-primary"
    lines = [line for line in previous.decode("utf-8").splitlines() if not any(
        re.match(rf"\s*(?:export\s+)?{name}\s*=", line) for name in updates
    )]
    lines.extend(f'{name}="{value}"' for name, value in updates.items())
    descriptor, name = tempfile.mkstemp(prefix=".env-", suffix=".tmp", dir=path.parent)
    staging = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(("\n".join(lines) + "\n").encode())
            stream.flush()
            os.fsync(stream.fileno())
        Settings(_env_file=staging)
        if (path.read_bytes() if path.exists() else b"") != previous:
            raise ValueError("Environment changed while saving")
        os.replace(staging, path)
    finally:
        staging.unlink(missing_ok=True)
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts/env.py"), "encrypt"], cwd=ROOT,
        capture_output=True, check=False, timeout=120,
    )
    if result.returncode:
        raise RuntimeError("Key saved locally; encrypted settings could not be refreshed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider", choices=["gemini", "openai"])
    args = parser.parse_args(argv)
    if not sys.stdin.isatty():
        print("Use an interactive local terminal so the key stays hidden.")
        return 1
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            key = getpass.getpass(args.provider.title() + " API key (hidden): ").strip()
        save_key(args.provider, key)
        print("Key saved locally and encrypted. No key was printed.")
        print("Use scripts/ai/ai_provider.py status, then activate with its current revision.")
        return 0
    except (OSError, ValueError, RuntimeError, EOFError, KeyboardInterrupt, getpass.GetPassWarning, subprocess.SubprocessError):
        print("AI configuration could not finish. No key was printed.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
