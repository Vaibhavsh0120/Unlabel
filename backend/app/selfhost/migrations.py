"""Serialized, checksum-verified PostgreSQL migrations with transactional receipts."""

import hashlib
import re
from pathlib import Path


class MigrationMismatch(RuntimeError):
    pass


def migrate(connection, directory: Path | None = None) -> list[str]:
    directory = directory or Path(__file__).resolve().parents[2] / "migrations/next_major"
    applied = []
    with connection.transaction():
        connection.execute("SELECT pg_advisory_xact_lock(842317224)")
        connection.execute("CREATE SCHEMA IF NOT EXISTS platform_meta")
        connection.execute("REVOKE ALL ON SCHEMA platform_meta FROM PUBLIC")
        connection.execute("""CREATE TABLE IF NOT EXISTS platform_meta.migrations (
            version text PRIMARY KEY, sha256 char(64) NOT NULL,
            applied_at timestamptz NOT NULL DEFAULT now())""")
        connection.execute("REVOKE ALL ON platform_meta.migrations FROM PUBLIC")
        paths = sorted(directory.glob("*.sql"))
        if not paths:
            raise MigrationMismatch("No versioned migrations were found")
        for path in paths:
            if path.is_symlink() or not re.fullmatch(r"[0-9]{4}_[a-z0-9_]+\.sql", path.name):
                raise MigrationMismatch("Invalid migration source")
            raw = path.read_bytes()
            checksum = hashlib.sha256(raw).hexdigest()
            previous = connection.execute(
                "SELECT sha256 FROM platform_meta.migrations WHERE version=%s", (path.name,)
            ).fetchone()
            if previous:
                if previous[0] != checksum:
                    raise MigrationMismatch("An applied migration changed; use a new migration")
                continue
            # Multiple source statements belong to this one surrounding transaction.
            connection.execute(raw.decode("utf-8"), prepare=False)
            connection.execute(
                "INSERT INTO platform_meta.migrations(version,sha256) VALUES(%s,%s)",
                (path.name, checksum),
            )
            applied.append(path.name)
    return applied
