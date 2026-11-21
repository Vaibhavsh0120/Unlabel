"""Bounded, private, single-use operator migration process; never an API role."""

import argparse
import json
import os
import signal
import threading
from pathlib import Path

import psycopg
from psycopg.conninfo import conninfo_to_dict

from app.selfhost.migrations import migrate

READY = Path("/tmp/unlabel-migrations-ready")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hold-seconds", type=int, default=600, choices=range(601))
    args = parser.parse_args()
    dsn = os.environ["UNLABEL_MIGRATION_DATABASE_URL"]
    target = conninfo_to_dict(dsn)
    if (
        target.get("host") != "lbhz7c20afhuzadjkpsmwmaj"
        or target.get("user") != "unlabel_migrator"
        or target.get("dbname") != "unlabel_app"
    ):
        raise ValueError("Unexpected migration destination")
    READY.unlink(missing_ok=True)
    with psycopg.connect(dsn, connect_timeout=5,
                         options="-c statement_timeout=60000 -c lock_timeout=5000") as connection:
        applied = migrate(connection)
        connection.execute("SELECT avatar_preference FROM accounts.profiles LIMIT 0")
    print(json.dumps({"migration_status": "ready", "applied": applied}), flush=True)
    READY.write_text("ready\n")
    stopped = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())
    try:
        stopped.wait(args.hold_seconds)
    finally:
        READY.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Private migration did not complete; inspect version receipts with the operator.", flush=True)
        raise SystemExit(1) from None
