"""Validate a public frontend API target and self-hosted dependency health."""

import argparse
import json
import urllib.error
import urllib.request
from urllib.parse import urlsplit

ORACLE_HOSTS = {"unlabel.duckdns.org", "www.unlabel.duckdns.org"}


def validate_backend_target(origin: str, selfhost_auth: bool) -> None:
    parsed = urlsplit(origin)
    _ = parsed.port
    if (
        len(origin) > 500
        or any(character.isspace() for character in origin)
        or parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in ("", "/")
    ):
        raise ValueError("Backend URL must be a public HTTPS origin.")
    if parsed.hostname.lower() in ORACLE_HOSTS and not selfhost_auth:
        raise ValueError(
            "The Oracle API requires self-hosted auth; enable it for this target."
        )
    if not selfhost_auth:
        return

    def read_json(path: str) -> dict[str, object]:
        request = urllib.request.Request(
            f"{origin.rstrip('/')}{path}",
            headers={"Accept": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=8) as response:
            if response.status != 200:
                raise ValueError(f"Self-hosted API {path} check did not return 200.")
            body = response.read(64 * 1024 + 1)
            if len(body) > 64 * 1024:
                raise ValueError(f"Self-hosted API {path} response is too large.")
            result = json.loads(body)
        if not isinstance(result, dict):
            raise ValueError(f"Self-hosted API {path} response is invalid.")
        return result

    try:
        dependencies = read_json("/health/dependencies")
    except (
        urllib.error.URLError,
        TimeoutError,
        json.JSONDecodeError,
        UnicodeDecodeError,
    ) as error:
        raise ValueError(
            "Self-hosted API readiness could not be verified; do not ship this "
            "client until the selected backend is ready."
        ) from error
    required_dependencies = {"postgresql", "mongodb", "redis", "identity"}
    reported_dependencies = dependencies.get("dependencies")
    if (
        dependencies.get("status") != "ready"
        or not isinstance(reported_dependencies, list)
        or not all(isinstance(item, str) for item in reported_dependencies)
        or not required_dependencies.issubset(set(reported_dependencies))
    ):
        raise ValueError(
            "Self-hosted API dependencies are not ready; do not ship this "
            "client until the selected backend is ready."
        )
    if dependencies.get("account_contract") != "selfhost-account-v2":
        raise ValueError(
            "The self-hosted account migration is not deployed; verify the "
            "profile migration and identity account policy before shipping this client."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("origin")
    parser.add_argument("selfhost_auth", choices=("true", "false"))
    args = parser.parse_args()
    try:
        validate_backend_target(args.origin, args.selfhost_auth == "true")
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
