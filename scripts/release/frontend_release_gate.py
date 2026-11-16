"""Build mobile releases only for a canonical version/build increase on main."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from version_metadata import frontend_version, parse_frontend_version


def version_changed(previous: str, current: tuple[str, str]) -> bool:
    old = parse_frontend_version(previous)
    if old == current:
        return False
    if tuple(map(int, current[0].split("."))) < tuple(
        map(int, old[0].split("."))
    ) or int(current[1]) <= int(old[1]):
        raise ValueError(
            "A mobile release must not lower SemVer and must increase the build number."
        )
    return True


def previous_frontend_manifest(before: str) -> str | None:
    command = ["git", "show", f"{before}:frontend/pubspec.yaml"]
    previous = subprocess.run(command, capture_output=True, text=True, check=False)
    if previous.returncode:
        subprocess.run(
            ["git", "fetch", "--no-tags", "origin", before],
            capture_output=True,
            text=True,
            check=False,
        )
        previous = subprocess.run(command, capture_output=True, text=True, check=False)
    if previous.returncode:
        print(
            "::warning::Could not retrieve the push base; skipping automatic mobile "
            "release because the version increase cannot be verified.",
            file=sys.stderr,
        )
        return None
    return previous.stdout


def requested() -> bool:
    if os.environ["GITHUB_EVENT_NAME"] == "workflow_dispatch":
        return True
    if (
        os.environ["GITHUB_EVENT_NAME"] != "push"
        or os.environ["GITHUB_REF"] != "refs/heads/main"
    ):
        return False
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    before = event["before"]
    if not isinstance(before, str) or not re.fullmatch(r"[0-9a-f]{40}", before):
        raise ValueError("Push event requires an exact previous commit.")
    if before == "0" * 40:
        return True
    previous = previous_frontend_manifest(before)
    if previous is None:
        return False
    return version_changed(previous, frontend_version())


if __name__ == "__main__":
    print(f"requested={'true' if requested() else 'false'}")
