"""Stream private Oracle database backups into age ciphertext on the operator's machine."""

import argparse
import json
import re
import shlex
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from project_secrets import SecretError, private_directory


def commands():
    resources = json.loads(
        (ROOT / "infrastructure/production/resources.json").read_text()
    )
    pg = resources["databases"]["app"]
    mongo = resources["databases"]["evidence"]
    for name in (pg, mongo):
        if not re.fullmatch(r"[a-z0-9]{24}", name):
            raise ValueError("Unexpected database resource ID")
    for database in ("unlabel_app", "unlabel_auth"):
        yield (
            database + ".dump.age",
            [
                "docker",
                "exec",
                pg,
                "pg_dump",
                "-Fc",
                "-U",
                "unlabel_migrator",
                "-d",
                database,
            ],
        )
    yield (
        "postgres-roles.sql.age",
        ["docker", "exec", pg, "pg_dumpall", "--roles-only", "-U", "unlabel_migrator"],
    )
    # The existing container credentials stay inside the container. The dump
    # tool reads a temporary protected config rather than a password argument.
    mongo_script = """
set -eu
umask 077
config=$(mktemp)
trap 'rm -f "$config"' EXIT
printf 'password: "%s"\\n' "$MONGO_INITDB_ROOT_PASSWORD" > "$config"
mongodump --config "$config" --username "$MONGO_INITDB_ROOT_USERNAME" \
    --authenticationDatabase admin --db unlabel_evidence --archive --gzip
"""
    yield (
        "unlabel_evidence.archive.gz.age",
        ["docker", "exec", mongo, "sh", "-c", mongo_script],
    )


def stream_backup(ssh, command, recipient, target):
    with subprocess.Popen(
        [*ssh, shlex.join(command)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    ) as source:
        try:
            with subprocess.Popen(
                ["age", "-r", recipient, "-o", str(target)],
                stdin=source.stdout,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ) as encryption:
                assert source.stdout is not None
                source.stdout.close()
                try:
                    cipher_status = encryption.wait(timeout=300)
                except BaseException:
                    encryption.kill()
                    raise
            dump_status = source.wait(timeout=10)
            if cipher_status or dump_status or target.stat().st_size < 256:
                raise RuntimeError("Backup stream failed")
        except BaseException:
            source.kill()
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--ssh-host", default="Volcanica")
    args = parser.parse_args()
    destination = args.destination.resolve()
    if destination.is_relative_to(ROOT):
        parser.error("Choose a backup directory outside the repository.")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", args.ssh_host):
        parser.error("Supply a configured SSH host alias.")
    recipient = (ROOT / "scripts/config/age-recipient.txt").read_text().strip()
    batch = destination / datetime.now(UTC).strftime("unlabel-%Y%m%dT%H%M%S.%fZ")
    batch.mkdir(parents=True, mode=0o700)
    private_directory(batch)
    ssh = [
        "ssh",
        "-T",
        "-o",
        "RemoteCommand=none",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=10",
        args.ssh_host,
    ]
    inventory = []
    for name, command in commands():
        encrypted = batch / name
        partial = encrypted.with_suffix(".partial.age")
        try:
            stream_backup(ssh, command, recipient, partial)
            partial.replace(encrypted)
        finally:
            partial.unlink(missing_ok=True)
        inventory.append({"file": name, "bytes": encrypted.stat().st_size})
    (batch / "complete.json").write_text(
        json.dumps(inventory, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Encrypted database backup completed: {batch}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, SecretError, ValueError, RuntimeError, subprocess.SubprocessError):
        raise SystemExit(
            "Backup failed. Use only sets containing complete.json."
        ) from None
