"""Bounded anonymous-account maintenance with an EXECUTE-only database role."""

import argparse
import signal
import threading

import psycopg
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class GuestCleanupSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="UNLABEL_", extra="ignore", hide_input_in_errors=True
    )
    guest_cleanup_database_url: SecretStr


def connect(settings):
    return psycopg.connect(
        settings.guest_cleanup_database_url.get_secret_value(),
        connect_timeout=5,
        options="-c statement_timeout=5000 -c lock_timeout=500",
    )


def prune(settings):
    with connect(settings) as connection:
        return connection.execute("SELECT auth_maintenance.prune_inactive_guests()").fetchone()[0]


def healthy(settings):
    with connect(settings) as connection:
        return connection.execute("SELECT auth_maintenance.guest_cleanup_healthy()").fetchone()[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--healthcheck", action="store_true")
    args = parser.parse_args()
    settings = GuestCleanupSettings()
    if args.healthcheck:
        try:
            raise SystemExit(0 if healthy(settings) else 1)
        except psycopg.Error:
            raise SystemExit(1) from None
    stopped = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())
    while not stopped.is_set():
        try:
            count = prune(settings)
            print(f"Guest cleanup completed: {count} expired accounts removed.", flush=True)
        except psycopg.Error:
            # Never log exception details: connection errors can include credentials.
            print("Guest cleanup failed; next scheduled run will retry.", flush=True)
            if args.once:
                raise SystemExit(1) from None
        if args.once or stopped.wait(86400):
            break


if __name__ == "__main__":
    main()
