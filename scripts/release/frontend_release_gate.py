"""Build mobile releases only for a canonical version/build increase on main."""

import json
import os
import re
import subprocess
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
    previous = subprocess.run(
        ["git", "show", f"{before}:frontend/pubspec.yaml"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return version_changed(previous, frontend_version())


if __name__ == "__main__":
    print(f"requested={'true' if requested() else 'false'}")
