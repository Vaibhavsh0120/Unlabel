"""Inspect or switch the one global AI credential using backend machine access."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="Exact configured Firebase project")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status")
    activate = commands.add_parser("activate")
    activate.add_argument("credential_id", help="Configured slot, e.g. gemini-primary or openai-primary")
    activate.add_argument("--expected-revision", type=int, required=True)
    args = parser.parse_args(argv)
    runtime = None
    try:
        from app.ai.configuration import configuration_digest, credentials
        from app.ai.store import AiSelectionConflict
        from app.community.auth import AuthenticationUnavailable, create_runtime
        from app.community.store import StoreUnavailable
        from app.core.config import Settings

        config = Settings()
        values = credentials(config)
        by_id = {value.id: value for value in values}
        digest = configuration_digest(values)
        if (
            not config.ai_enabled or not config.community_enabled
            or args.project != config.community_project_id
            or config.community_service_account_json is None
            or config.ai_initial_credential_id not in by_id
        ):
            raise ValueError()
        runtime = create_runtime(
            config.community_project_id, config.community_database_id,
            config.community_service_account_json.get_secret_value(),
        )
        store = runtime.ai_store
        if args.command == "activate":
            if args.credential_id not in by_id:
                raise ValueError()
            current = store.activate(
                args.credential_id, args.expected_revision, config.ai_initial_credential_id, digest,
            )
        else:
            current = store.read(config.ai_initial_credential_id, digest)
        value = by_id.get(current.credential_id)
        print(json.dumps({
            "scope": "global", "credential_id": current.credential_id,
            "provider": value.provider if value else None, "model": value.model if value else None,
            "revision": current.revision, "configuration_matches": current.configuration == digest,
            "configured_slots": [{"id": item.id, "provider": item.provider} for item in values],
        }, indent=2))
        return 0
    except (ValueError, AuthenticationUnavailable, StoreUnavailable, AiSelectionConflict):
        print("AI operation failed; check target, configured slots and current revision.", file=sys.stderr)
        return 1
    finally:
        if runtime is not None:
            try:
                runtime.close()
            except Exception:  # noqa: BLE001 - provider cleanup must not print secrets.
                print("AI connection cleanup failed.", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
