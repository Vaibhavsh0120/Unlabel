"""Recoverable project-secret backup. Secret values and age diagnostics are never printed."""

import argparse
import base64
import binascii
import csv
import fnmatch
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from datetime import UTC, datetime
from pathlib import Path, PurePosixPath

from env import EnvError, prompt_identity

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = "secrets/project.age"
INDEX = "secrets/index.json"
MANIFEST = "secrets/manifest.json"
MAX_FILE = 2 * 1024 * 1024
MAX_BUNDLE = 16 * 1024 * 1024


class SecretError(RuntimeError):
    """Only safe, non-secret operator messages belong in this exception."""


def relative_name(name):
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9._/-]{1,240}", name):
        raise SecretError("Invalid project-relative secret path.")
    path = PurePosixPath(name)
    if (
        path.is_absolute()
        or str(path) != name
        or any(
            part in {".", ".."}
            or part.endswith(".")
            or part.split(".")[0].upper() in {"CON", "PRN", "AUX", "NUL"}
            or re.fullmatch(r"(?:COM|LPT)[1-9]", part.split(".")[0], re.IGNORECASE)
            for part in path.parts
        )
    ):
        raise SecretError("Invalid project-relative secret path.")
    return name


def guarded(root, name):
    name = relative_name(name)
    target = root / name
    for path in [root, *reversed(target.parents), target]:
        if path != root and not path.is_relative_to(root):
            continue
        try:
            info = path.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
            raise SecretError("Refusing a symlink or junction in a secret path.")
    return target


def run(command, **options):
    try:
        result = subprocess.run(
            command, capture_output=True, timeout=120, check=False, **options
        )
    except (OSError, subprocess.SubprocessError):
        raise SecretError(
            "Secret operation could not run; existing files were preserved."
        ) from None
    if result.returncode:
        # Profiles and age errors may contain sensitive diagnostics. Never echo them.
        raise SecretError(
            "Secret operation failed; check age/key/profile configuration."
        )
    return result.stdout


def executable(name):
    result = shutil.which(name)
    if not result:
        raise SecretError(f"Install {name} and ensure it is on PATH.")
    return result


def private_directory(path):
    path.chmod(0o700)
    if os.name == "nt":
        # Restrict the staging directory before writing any plaintext. Child files
        # inherit this ACL; moved NTFS files retain their restricted descriptor.
        rows = list(
            csv.reader(
                run(["whoami", "/user", "/fo", "csv", "/nh"]).decode().splitlines()
            )
        )
        sid = rows[0][-1] if rows else ""
        if not re.fullmatch(r"S-1-[0-9-]+", sid):
            raise SecretError("Unable to establish a private staging directory.")
        run(["icacls", str(path), "/inheritance:r", "/grant:r", f"*{sid}:(OI)(CI)F"])


@contextmanager
def workspace(root):
    # The fixed prefix is ignored by Git. Paths are generated under this root;
    # TemporaryDirectory cleanup cannot be redirected outside the workspace.
    with tempfile.TemporaryDirectory(prefix=".secrets-work-", dir=root) as name:
        path = Path(name)
        if path.parent != root or not path.name.startswith(".secrets-work-"):
            raise SecretError("Invalid staging directory.")
        private_directory(path)
        yield path


@contextmanager
def locked(root):
    path = guarded(root, ".secrets-work.lock")
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise SecretError(
            "Another secret operation is active; check the local lock before retrying."
        ) from None
    os.close(descriptor)
    try:
        yield
    finally:
        path.unlink()


def read_json(path):
    if not path.is_file() or path.stat().st_size > MAX_BUNDLE:
        raise SecretError(
            "Required secret metadata is missing or exceeds its size limit."
        )
    try:
        return json.loads(path.read_bytes())
    except (ValueError, UnicodeError):
        raise SecretError(
            "Invalid secret metadata; existing files were preserved."
        ) from None


def manifest(root):
    value = read_json(guarded(root, MANIFEST))
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise SecretError("Unsupported secret manifest.")
    for field in ["files", "required", "patterns", "directories"]:
        if not isinstance(value.get(field), list) or not all(
            isinstance(item, str) for item in value[field]
        ):
            raise SecretError("Invalid secret manifest entries.")
        for item in value[field]:
            relative_name(item.replace("*", "x").replace("?", "x"))
    return value


def excluded(name):
    lower = name.lower()
    return (
        lower.endswith((".age", ".agekey", ".example", ".tmp")) or ".example." in lower
    )


def allowed(name, config):
    relative_name(name)
    return not excluded(name) and (
        name in config["files"]
        or any(fnmatch.fnmatchcase(name, pattern) for pattern in config["patterns"])
        or any(name.startswith(directory + "/") for directory in config["directories"])
    )


def require_ignored(root, names):
    for name in names:
        # Keep plaintext out of source control even if a new manifest entry was added.
        try:
            result = subprocess.run(
                [
                    executable("git"),
                    "check-ignore",
                    "--no-index",
                    "--quiet",
                    "--",
                    name,
                ],
                cwd=root,
                capture_output=True,
                check=False,
                timeout=20,
            )
            tracked = subprocess.run(
                [executable("git"), "ls-files", "--error-unmatch", "--", name],
                cwd=root,
                capture_output=True,
                check=False,
                timeout=20,
            )
        except (OSError, subprocess.SubprocessError):
            raise SecretError("Unable to check plaintext Git exclusions.") from None
        if result.returncode or tracked.returncode == 0:
            raise SecretError(
                "A secret path is tracked or not ignored; fix Git exclusions first."
            )


def inventory(root, config):
    candidates = set(config["files"])
    for pattern in config["patterns"]:
        candidates.update(
            path.relative_to(root).as_posix() for path in root.glob(pattern)
        )
    for name in config["directories"]:
        directory = guarded(root, name)
        if directory.exists():
            if not directory.is_dir():
                raise SecretError("A secret directory is not a directory.")
            candidates.update(
                path.relative_to(root).as_posix() for path in directory.rglob("*")
            )
    found = {}
    for name in sorted(candidates):
        if not allowed(name, config):
            continue
        path = guarded(root, name)
        if not path.exists() or path.is_dir():
            continue
        if not path.is_file() or not 0 < path.stat().st_size <= MAX_FILE:
            raise SecretError(
                "A secret file is empty, unsupported or exceeds its size limit."
            )
        found[name] = path.read_bytes()
    if set(config["required"]) - found.keys():
        raise SecretError(
            "Required local secrets are missing; restore them before encrypting."
        )
    require_ignored(root, found)
    return found


def index(root):
    path = guarded(root, INDEX)
    if not path.exists():
        if guarded(root, BUNDLE).exists():
            raise SecretError(
                "Encrypted backup exists without its index; restore the index from Git."
            )
        return None
    value = read_json(path)
    if (
        not isinstance(value, dict)
        or value.get("schema_version") != 1
        or not isinstance(value.get("files"), list)
        or not value["files"]
        or len(value["files"]) > 256
    ):
        raise SecretError("Invalid encrypted-backup index.")
    for name in value["files"]:
        relative_name(name)
    if len({name.casefold() for name in value["files"]}) != len(value["files"]):
        raise SecretError("Duplicate secret paths in backup index.")
    return value


def recipient_key(root, supplied):
    value = (
        supplied
        or guarded(root, "scripts/config/age-recipient.txt").read_text().strip()
    )
    if not re.fullmatch(r"age1[0-9a-z]{20,150}", value):
        raise SecretError("Supply one age public recipient key beginning age1.")
    return value


def seal(payload, recipient, staging, *, agel=False):
    plaintext = staging / ".env"
    ciphertext = staging / ".env.age"
    plaintext.write_bytes(payload)
    plaintext.chmod(0o600)
    ciphertext.unlink(missing_ok=True)
    if agel:
        # Fixed script; no paths or secret values are interpolated into shell code.
        script = """$ErrorActionPreference = 'Stop'
if (-not (Get-Command agel -CommandType Function -ErrorAction SilentlyContinue)) { exit 2 }
$env:AGE_PUBLIC_KEY = $env:UNLABEL_AGE_RECIPIENT
agel | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath '.env.age')) { exit 3 }
"""
        environment = dict(os.environ, UNLABEL_AGE_RECIPIENT=recipient)
        run(
            [executable("pwsh"), "-NoLogo", "-NonInteractive", "-Command", script],
            cwd=staging,
            env=environment,
        )
    else:
        run([executable("age"), "-r", recipient, "-o", str(ciphertext), str(plaintext)])
    if not ciphertext.is_file() or not ciphertext.read_bytes().startswith(
        b"age-encryption.org/v1\n"
    ):
        raise SecretError(
            "Encryption produced an invalid age file; previous backups were preserved."
        )
    return ciphertext.read_bytes()


def publish(root, files, staging, *, overwrite=False):
    """Preflight all files, then publish. Roll back this batch on ordinary I/O failure."""
    before = {}
    for name, payload in files.items():
        target = guarded(root, name)
        if target.exists() and not target.is_file():
            raise SecretError("A restore destination is not a regular file.")
        previous = target.read_bytes() if target.exists() else None
        if previous is not None and previous != payload and not overwrite:
            raise SecretError(
                "Local secret differs from backup; use -Force only to replace it intentionally."
            )
        before[name] = previous
    changed = []
    try:
        for number, (name, payload) in enumerate(files.items()):
            if before[name] == payload:
                continue
            target = guarded(root, name)
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            temporary = staging / f"restore-{number}"
            temporary.write_bytes(payload)
            temporary.chmod(0o600)
            if before[name] is None:
                os.link(
                    temporary, target
                )  # Exclusive publication; no check/replace race.
            else:
                os.replace(temporary, target)
            changed.append(name)
    except OSError:
        try:
            for number, name in enumerate(reversed(changed)):
                target = guarded(root, name)
                if before[name] is None:
                    target.unlink()
                else:
                    recovery = staging / f"rollback-{number}"
                    recovery.write_bytes(before[name])
                    recovery.chmod(0o600)
                    os.replace(recovery, target)
        except OSError:
            raise SecretError(
                "Restore rollback failed; keep the encrypted backup and inspect destinations."
            ) from None
        raise SecretError(
            "Secret publication failed; this batch was rolled back."
        ) from None


def encrypt(root, *, recipient=None, agel=False):
    config = manifest(root)
    files = inventory(root, config)
    previous = index(root)
    if previous and set(previous["files"]) - files.keys():
        raise SecretError(
            "Previously backed-up files are missing locally; restore them before refreshing backup."
        )
    if len(files) > 256 or len({name.casefold() for name in files}) != len(files):
        raise SecretError("Too many or case-colliding secret paths.")
    recipient = recipient_key(root, recipient)
    payload = json.dumps(
        {
            "schema_version": 1,
            "files": {
                name: base64.b64encode(value).decode("ascii")
                for name, value in files.items()
            },
        },
        sort_keys=True,
    ).encode()
    if len(payload) > MAX_BUNDLE:
        raise SecretError("Secret backup exceeds its size limit.")
    with workspace(root) as staging:
        encrypted = seal(payload, recipient, staging, agel=agel)
        outputs = {BUNDLE: encrypted}
        # Keep existing setup.py / scripts/env.py restoration compatible.
        if "backend/.env" in files:
            outputs["backend/.env.age"] = seal(
                files["backend/.env"], recipient, staging, agel=agel
            )
        outputs[INDEX] = (
            json.dumps(
                {
                    "schema_version": 1,
                    "recipient": recipient,
                    "updated_at": datetime.now(UTC).isoformat(),
                    "files": sorted(files),
                },
                indent=2,
            )
            + "\n"
        ).encode()
        outputs["scripts/config/age-recipient.txt"] = (recipient + "\n").encode()
        publish(root, outputs, staging, overwrite=True)
    return sorted(files)


def open_backup(root, *, identity=None, private_key=None):
    metadata = index(root)
    if metadata is None:
        raise SecretError("No encrypted project backup exists yet; run encrypt first.")
    ciphertext = guarded(root, BUNDLE)
    if not ciphertext.is_file() or ciphertext.stat().st_size > MAX_BUNDLE + 65536:
        raise SecretError("Encrypted backup is missing or exceeds its size limit.")
    arguments = [executable("age"), "--decrypt", "-i"]
    options = {}
    if private_key is not None:
        private_key = private_key.strip()
        if not re.fullmatch(r"AGE-SECRET-KEY-1[0-9A-Z]{1,150}", private_key):
            raise SecretError(
                "Paste one native age private key beginning AGE-SECRET-KEY-1."
            )
        arguments += ["-"]
        options["input"] = (private_key + "\n").encode("ascii")
    elif identity is not None:
        path = Path(identity).expanduser().absolute()
        if not path.is_file() or path.is_symlink():
            raise SecretError("Private identity must be a regular local file.")
        arguments += [str(path)]
    else:
        raise SecretError("A private identity is required to decrypt.")
    # Buffer output: age may emit partial plaintext before reporting authentication
    # failure. No destination is touched unless age exits successfully.
    raw = run([*arguments, str(ciphertext)], **options)
    if len(raw) > MAX_BUNDLE:
        raise SecretError("Decrypted backup exceeds its size limit.")
    try:
        value = json.loads(raw)
        if value.get("schema_version") != 1 or not isinstance(value.get("files"), dict):
            raise ValueError()
        files = {
            name: base64.b64decode(encoded, validate=True)
            for name, encoded in value["files"].items()
        }
    except (ValueError, TypeError, AttributeError, binascii.Error):
        raise SecretError(
            "Invalid decrypted backup; no secret files were changed."
        ) from None
    config = manifest(root)
    if set(files) != set(metadata["files"]) or any(
        not allowed(name, config) or not 0 < len(payload) <= MAX_FILE
        for name, payload in files.items()
    ):
        raise SecretError(
            "Backup paths/content do not match the approved manifest and index."
        )
    require_ignored(root, files)
    for name in files:
        guarded(root, name)
    return files


def restore(root, *, overwrite=False, **identity):
    files = open_backup(root, **identity)
    with workspace(root) as staging:
        publish(root, files, staging, overwrite=overwrite)
    return sorted(files)


def verify(root, **identity):
    files = open_backup(root, **identity)
    if any(
        not guarded(root, name).is_file() or guarded(root, name).read_bytes() != value
        for name, value in files.items()
    ):
        raise SecretError(
            "Local secrets differ from the backup or are missing; no files were changed."
        )
    return sorted(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    save = commands.add_parser("encrypt")
    save.add_argument(
        "--recipient", help="Public age key; default is the tracked public recipient"
    )
    save.add_argument(
        "--agel",
        action="store_true",
        help="Use the user's PowerShell profile agel function",
    )
    for command in ["decrypt", "verify"]:
        child = commands.add_parser(command)
        keys = child.add_mutually_exclusive_group(required=True)
        keys.add_argument("--identity", type=Path)
        keys.add_argument("--paste-key", action="store_true")
        if command == "decrypt":
            child.add_argument("--force", action="store_true")
    commands.add_parser("status")
    args = parser.parse_args()
    try:
        with locked(ROOT):
            if args.command == "encrypt":
                names = encrypt(ROOT, recipient=args.recipient, agel=args.agel)
            elif args.command == "status":
                names = sorted(inventory(ROOT, manifest(ROOT)))
                saved = index(ROOT)
                print(f"Encrypted backup: {'present' if saved else 'not created'}")
                if saved:
                    print(
                        f"Backed-up files: {len(saved['files'])}; missing locally: {len(set(saved['files']) - set(names))}"
                    )
                print(
                    "Status does not verify content freshness; use verify with your private key."
                )
            else:
                identity = (
                    {"private_key": prompt_identity()}
                    if args.paste_key
                    else {"identity": args.identity}
                )
                names = (
                    restore(ROOT, overwrite=args.force, **identity)
                    if args.command == "decrypt"
                    else verify(ROOT, **identity)
                )
    except (SecretError, EnvError) as error:
        parser.exit(1, f"Secret setup failed: {error}\n")
    except (OSError, UnicodeError):
        parser.exit(
            1,
            "Secret setup failed: filesystem access failed; no secret diagnostics were printed.\n",
        )
    print(f"{args.command.capitalize()} complete: {len(names)} project secret files.")
    for name in names:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
