"""Create verified, non-overwriting backups of the two public SQLite catalogues."""

import argparse
import hashlib
import json
import os
import sqlite3
import tempfile
from contextlib import closing
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATABASES = {
    "catalogue": ROOT / "backend/app/catalogue/data/catalogue.sqlite3",
    "research": ROOT / "backend/app/research_catalogue/data/research.sqlite3",
}


def logical_inventory(connection: sqlite3.Connection) -> dict:
    result = {}
    for (table,) in connection.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    ):
        # Names come from the schema, never from user SQL. Quote embedded quotes.
        quoted = '"' + table.replace('"', '""') + '"'
        columns = len(connection.execute(f"SELECT * FROM {quoted} LIMIT 0").description)
        digest, count = hashlib.sha256(), 0
        for row in connection.execute(f"SELECT * FROM {quoted} ORDER BY " + ",".join(str(i + 1) for i in range(columns))):
            public = [value.hex() if isinstance(value, bytes) else value for value in row]
            digest.update(json.dumps(public, ensure_ascii=True, separators=(",", ":"), allow_nan=False).encode())
            digest.update(b"\n")
            count += 1
        result[table] = {"rows": count, "sha256": digest.hexdigest()}
    return result


def backup(source: Path, destination: Path) -> dict:
    source = source.resolve(strict=True)
    if destination.exists() or source == destination.resolve():
        raise ValueError("Backup must be a new file")
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(dir=destination.parent, prefix=".catalogue-backup-", suffix=".sqlite3")
    os.close(descriptor)
    staging = Path(name)
    try:
        with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)) as original:
            with closing(sqlite3.connect(staging)) as copy:
                original.backup(copy)
                if copy.execute("PRAGMA integrity_check").fetchone() != ("ok",):
                    raise ValueError("Backup failed its integrity check")
                inventory = logical_inventory(copy)
                if inventory != logical_inventory(original):
                    raise ValueError("Catalogue changed or backup lost records")
        # Exclusive publication never replaces an earlier backup.
        os.link(staging, destination)
        with destination.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        return {"database_bytes": destination.stat().st_size,
                "database_sha256": digest,
                "tables": inventory}
    finally:
        staging.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".local-tools/catalogue-backups")
    args = parser.parse_args()
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")
    directory = args.output / stamp
    receipt = {"schema_version": "catalogue-backup-v1", "created_at": datetime.now(UTC).isoformat(), "databases": {}}
    for label, source in DATABASES.items():
        if source.is_file():
            receipt["databases"][label] = backup(source, directory / (label + ".sqlite3"))
    if not receipt["databases"]:
        raise ValueError("No generated public catalogue found; restore setup first")
    (directory / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"backup_directory": str(directory), "verified": True,
                      "tables": {label: data["tables"] for label, data in receipt["databases"].items()}}, indent=2))


if __name__ == "__main__":
    main()
