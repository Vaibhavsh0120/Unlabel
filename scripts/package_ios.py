"""Verify an unsigned iPhoneOS app and package it for external signing/LiveContainer."""

import argparse
import json
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path


def validate_info(info: dict, version: str, build: str) -> None:
    if (
        info.get("CFBundleShortVersionString") != version
        or info.get("CFBundleVersion") != build
    ):
        raise ValueError("iOS version/build must match the canonical frontend version.")
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("Expected an iPhoneOS device app, not a simulator build.")
    if info.get("CFBundleIdentifier") != "in.unlabel.unlabel":
        raise ValueError("Unexpected iOS bundle identifier.")
    executable = info.get("CFBundleExecutable", "")
    if not executable or Path(executable).name != executable:
        raise ValueError("iOS bundle requires a plain executable name.")


def package(app: Path, output: Path, version: str, build: str) -> dict:
    info = plistlib.loads((app / "Info.plist").read_bytes())
    validate_info(info, version, build)
    executable = app / info["CFBundleExecutable"]
    if not executable.is_file():
        raise ValueError("iOS bundle executable is missing.")
    signature = subprocess.run(
        ["codesign", "-d", str(app)], capture_output=True, text=True, check=False
    )
    if signature.returncode == 0:
        raise ValueError("This distribution lane must contain an unsigned device app.")
    architecture = subprocess.check_output(
        ["lipo", "-archs", str(executable)], text=True
    ).strip()
    if "arm64" not in architecture.split():
        raise ValueError("The device executable must include arm64.")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise ValueError("Refusing to overwrite an existing IPA.")
    with tempfile.TemporaryDirectory(prefix="unlabel-ipa-") as staging:
        payload = Path(staging) / "Payload"
        payload.mkdir()
        shutil.copytree(app, payload / "Runner.app", symlinks=True)
        subprocess.run(
            ["zip", "-q", "-r", "-y", str(output.resolve()), "Payload"],
            cwd=staging,
            check=True,
        )
    return {
        "bundle_identifier": info["CFBundleIdentifier"],
        "architectures": architecture,
        "minimum_os_version": info.get("MinimumOSVersion"),
        "platform": "iPhoneOS",
        "signing": "unsigned_requires_host_signing",
        "livecontainer_runtime": "not_device_verified",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-number", required=True)
    args = parser.parse_args()
    metadata = package(args.app, args.output, args.version, args.build_number)
    (args.output.parent / "ios-package.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Packaged verified unsigned iPhoneOS app: {args.output.name}")


if __name__ == "__main__":
    main()
