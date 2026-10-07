"""Inspect/review automatic observations using explicit backend credentials."""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))


def sha256(value: str) -> str:
    if re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise argparse.ArgumentTypeError("Expected a lowercase SHA-256 identifier")
    return value


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument(
        "--project", required=True, help="Must match the configured project"
    )
    commands = result.add_subparsers(dest="command", required=True)
    pending = commands.add_parser("pending")
    pending.add_argument("--limit", type=int, choices=range(1, 21), default=20)
    inspect = commands.add_parser("inspect")
    inspect.add_argument("revision_id", type=sha256)
    for decision in ("approve", "reject"):
        review = commands.add_parser(decision)
        review.add_argument("revision_id", type=sha256)
        review.add_argument("--expected-hash", required=True, type=sha256)
        if decision == "approve":
            review.add_argument(
                "--supersedes", action="append", type=sha256, default=[]
            )
    cleanup = commands.add_parser("cleanup")
    cleanup.add_argument("--limit", type=int, choices=range(1, 21), default=20)
    return result


def execute(args: argparse.Namespace, runtime):
    store = runtime.store
    if args.command == "pending":
        return [item.model_dump(mode="json") for item in store.pending(args.limit)]
    if args.command == "inspect":
        item = store.inspect(args.revision_id)
        return item.model_dump(mode="json") if item is not None else None
    if args.command == "cleanup":
        return {"removed_staged_records": store.cleanup_expired(args.limit)}
    return store.review(
        args.revision_id,
        args.command,
        args.expected_hash,
        supersedes=getattr(args, "supersedes", []),
    ).model_dump(mode="json")


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    from app.community.auth import AuthenticationUnavailable, create_runtime
    from app.community.store import StoreConflict, StoreQuotaExceeded, StoreUnavailable
    from app.core.config import Settings

    runtime = None
    try:
        config = Settings()
        if (
            not config.community_enabled
            or args.project != config.community_project_id
            or config.community_service_account_json is None
        ):
            raise ValueError("Explicit target mismatch")
        runtime = create_runtime(
            config.community_project_id,
            config.community_database_id,
            config.community_service_account_json.get_secret_value(),
        )
        print(
            json.dumps(
                execute(args, runtime), ensure_ascii=False, allow_nan=False, indent=2
            )
        )
        return 0
    except (
        ValueError,
        AuthenticationUnavailable,
        StoreUnavailable,
        StoreConflict,
        StoreQuotaExceeded,
    ):
        print(
            "Community operation failed; check target, credentials, state and expected hash.",
            file=sys.stderr,
        )
        return 1
    finally:
        if runtime is not None:
            try:
                runtime.close()
            except Exception:  # noqa: BLE001 - provider cleanup must not print credentials.
                print("Community connection cleanup failed.", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
