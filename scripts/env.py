"""Encrypt or restore backend/.env with age, without exposing secret contents."""

import argparse
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class EnvError(RuntimeError):
    """A safe operator-facing error that never includes age output or secret bytes."""


def _regular_file(path: Path, description: str, *, optional: bool = False) -> None:
    if path.is_symlink():
        raise EnvError(f"Refusing a symbolic link for {description}.")
    if not path.exists() and optional:
        return
    if not path.is_file():
        raise EnvError(f"{description} must be an existing regular file.")


def _backend(root: Path) -> Path:
    directory = Path(root).resolve() / "backend"
    if directory.is_symlink() or not directory.is_dir():
        raise EnvError("backend must be an existing directory without a symbolic link.")
    return directory


def _age() -> str:
    executable = shutil.which("age")
    if executable is None:
        raise EnvError("Install age and ensure its executable is on PATH.")
    return executable


def _temporary(directory: Path) -> Path:
    try:
        descriptor, filename = tempfile.mkstemp(
            prefix=".env-", suffix=".tmp", dir=directory
        )
        os.close(descriptor)
    except OSError:
        raise EnvError(
            "Unable to create a private temporary file in backend."
        ) from None
    path = Path(filename)
    # mkstemp already uses 0600 on POSIX. Windows retains the directory's ACL;
    # chmod is a best effort and must not be described as an NTFS ACL guarantee.
    try:
        path.chmod(0o600)
    except OSError:
        pass
    return path


def _run_age(
    command: list[str], output: Path, *, identity_input: bytes | None = None
) -> None:
    try:
        if identity_input is None:
            result = subprocess.run(
                command, capture_output=True, check=False, timeout=120
            )
        else:
            result = subprocess.run(
                command,
                capture_output=True,
                check=False,
                timeout=120,
                input=identity_input,
            )
    except (OSError, subprocess.SubprocessError):
        raise EnvError(
            "age could not complete; existing environment files were preserved."
        ) from None
    if result.returncode != 0:
        # age stderr can contain paths, recipient diagnostics or identity details.
        # Captured output is deliberately never printed or added to exceptions.
        raise EnvError("age failed; check the recipient or identity file and retry.")
    _regular_file(output, "age temporary output")
    if output.stat().st_size == 0:
        raise EnvError(
            "age produced no output; existing environment files were preserved."
        )


def _cleanup(path: Path) -> None:
    try:
        path.unlink(missing_ok=True)
    except OSError:
        raise EnvError(
            "Unable to remove the temporary environment file; remove it locally."
        ) from None


def encrypt_env(root: Path, recipient: str | None = None) -> Path:
    """Atomically update ciphertext while preserving the existing plaintext .env."""
    directory = _backend(root)
    plaintext = directory / ".env"
    target = directory / ".env.age"
    _regular_file(plaintext, "backend/.env")
    _regular_file(target, "backend/.env.age", optional=True)
    if recipient is None:
        recipient_file = Path(root).resolve() / "scripts/config/age-recipient.txt"
        _regular_file(recipient_file, "public recipient file")
        try:
            recipient = recipient_file.read_text(encoding="ascii").strip()
        except (OSError, UnicodeError):
            raise EnvError("Unable to read the public age recipient.") from None
    if not re.fullmatch(r"age1[0-9a-z]+", recipient):
        raise EnvError("The age recipient must be a single age public key.")
    executable = _age()
    staging = _temporary(directory)
    try:
        _run_age(
            [executable, "-r", recipient, "-o", str(staging), str(plaintext)], staging
        )
        _regular_file(target, "backend/.env.age", optional=True)
        os.replace(staging, target)
    except OSError:
        raise EnvError(
            "Unable to publish encrypted environment; existing files were preserved."
        ) from None
    finally:
        _cleanup(staging)
    return target


def decrypt_env(root: Path, identity: Path, *, overwrite: bool = False) -> Path:
    """Restore .env using an identity path; existing plaintext is kept by default."""
    identity = Path(identity).expanduser().absolute()
    return _decrypt(root, str(identity), overwrite=overwrite)


def decrypt_env_text(root: Path, identity: str, *, overwrite: bool = False) -> Path:
    """Pass a single pasted native age identity via stdin, never a key file/argument."""
    identity = identity.strip()
    if not re.fullmatch(r"AGE-SECRET-KEY-1[0-9A-Z]{1,150}", identity):
        raise EnvError(
            "Paste a single native age private key beginning AGE-SECRET-KEY-1."
        )
    return _decrypt(
        root, "-", identity_input=(identity + "\n").encode("ascii"), overwrite=overwrite
    )


def _decrypt(
    root: Path,
    identity_argument: str,
    *,
    identity_input: bytes | None = None,
    overwrite: bool = False,
) -> Path:
    directory = _backend(root)
    ciphertext = directory / ".env.age"
    target = directory / ".env"
    _regular_file(ciphertext, "backend/.env.age")
    _regular_file(target, "backend/.env", optional=True)
    if target.exists() and not overwrite:
        raise EnvError(
            "backend/.env already exists; keep it or explicitly use --force."
        )
    if identity_input is None:
        _regular_file(Path(identity_argument), "private identity")
    executable = _age()
    staging = _temporary(directory)
    try:
        _run_age(
            [
                executable,
                "--decrypt",
                "-i",
                identity_argument,
                "-o",
                str(staging),
                str(ciphertext),
            ],
            staging,
            identity_input=identity_input,
        )
        _regular_file(target, "backend/.env", optional=True)
        if overwrite:
            os.replace(staging, target)
        else:
            # A hard link is atomic and refuses an existing destination, including
            # an environment created while age was running. No check/replace race.
            try:
                os.link(staging, target)
            except FileExistsError:
                raise EnvError(
                    "backend/.env already exists; the restored file was not published."
                ) from None
    except OSError:
        raise EnvError(
            "Unable to restore environment; existing files were preserved."
        ) from None
    finally:
        _cleanup(staging)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser(
        "encrypt", help="Update backend/.env.age with the public recipient"
    )
    decrypt = commands.add_parser(
        "decrypt", help="Restore backend/.env using a private key file"
    )
    identities = decrypt.add_mutually_exclusive_group(required=True)
    identities.add_argument("--identity", type=Path, help="Private identity file path")
    identities.add_argument(
        "--paste-key",
        action="store_true",
        help="Hidden local terminal prompt; key goes to age stdin",
    )
    decrypt.add_argument(
        "--force", action="store_true", help="Explicitly replace an existing .env"
    )
    args = parser.parse_args()
    try:
        if args.command == "encrypt":
            result = encrypt_env(REPOSITORY_ROOT)
        elif args.paste_key:
            result = decrypt_env_text(
                REPOSITORY_ROOT, prompt_identity(), overwrite=args.force
            )
        else:
            result = decrypt_env(REPOSITORY_ROOT, args.identity, overwrite=args.force)
    except EnvError as error:
        parser.exit(1, f"Environment setup failed: {error}\n")
    print(f"Environment file ready: {result.relative_to(REPOSITORY_ROOT).as_posix()}")
    return 0


def prompt_identity() -> str:
    import getpass
    import sys
    import warnings

    if not sys.stdin.isatty():
        raise EnvError("Private-key paste requires an interactive local terminal.")
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        try:
            return getpass.getpass("Paste private age key (hidden): ")
        except (getpass.GetPassWarning, EOFError):
            raise EnvError(
                "This terminal cannot hide input; use a private-key file instead."
            ) from None


if __name__ == "__main__":
    raise SystemExit(main())
