"""Read independent release identities from their canonical component manifests."""

import argparse
import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def frontend_version(root: Path = ROOT) -> tuple[str, str]:
    text = (root / "frontend/pubspec.yaml").read_text(encoding="utf-8")
    matches = re.findall(rf"^version:\s*({SEMVER})\+([1-9][0-9]*)\s*$", text, re.MULTILINE)
    if len(matches) != 1 or len(re.findall(r"^version:", text, re.MULTILINE)) != 1:
        raise ValueError("frontend/pubspec.yaml requires one version and positive build number.")
    if int(matches[0][1]) > 2_100_000_000:
        raise ValueError("Frontend build number exceeds Android's versionCode limit.")
    return matches[0]


def backend_version(root: Path = ROOT) -> str:
    metadata = tomllib.loads((root / "backend/pyproject.toml").read_text(encoding="utf-8"))
    version = metadata["project"]["version"]
    if not isinstance(version, str) or re.fullmatch(SEMVER, version) is None:
        raise ValueError("backend/pyproject.toml requires a three-part release version.")
    return version


def metadata(component: str, root: Path = ROOT) -> dict[str, str]:
    if component == "backend":
        return {"component": component, "version": backend_version(root)}
    version, build_number = frontend_version(root)
    config = json.loads((root / "scripts/workspace.json").read_text(encoding="utf-8"))
    flutter_version = config["flutter_version"]
    if not isinstance(flutter_version, str) or re.fullmatch(SEMVER, flutter_version) is None:
        raise ValueError("scripts/workspace.json requires a pinned Flutter release version.")
    return {
        "component": component,
        "version": version,
        "build_number": build_number,
        "pubspec_version": f"{version}+{build_number}",
        "flutter_version": flutter_version,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--component", choices=["frontend", "backend"], required=True)
    parser.add_argument("--format", choices=["json", "github"], default="json")
    args = parser.parse_args()
    try:
        value = metadata(args.component)
    except (OSError, ValueError, KeyError):
        print("Component version metadata is missing or invalid.", file=sys.stderr)
        return 1
    if args.format == "github":
        for key, item in value.items():
            print(f"{key}={item}")
    else:
        print(json.dumps(value, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
