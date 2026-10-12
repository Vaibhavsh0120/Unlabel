"""Create a LiveContainer/AltStore source from a verified, completed device IPA."""

import argparse
import copy
import hashlib
import json
import plistlib
import re
import struct
import sys
import zipfile
from datetime import datetime
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

MAX_IPA_BYTES = 512 * 1024 * 1024
MAX_EXECUTABLE_BYTES = 256 * 1024 * 1024
MAX_PLIST_BYTES = 1024 * 1024
ARM64 = 0x0100000C
DESCRIPTION = (
    "Unlabel food-label reader. This is an unsigned device build for compatible "
    "LiveContainer or sideloading setups; physical-device compatibility is not verified. "
    "Normal iOS installation requires signing and provisioning."
)


def public_url(value: str) -> str:
    parsed = urlsplit(value)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.fragment
        or any(character.isspace() for character in value)
    ):
        raise ValueError("Source asset URLs must be public HTTPS URLs.")
    return value


def read_entry(archive: zipfile.ZipFile, name: str, limit: int) -> bytes:
    entry = archive.getinfo(name)
    if entry.file_size <= 0 or entry.file_size > limit:
        raise ValueError("IPA metadata or executable exceeds its bounded read budget.")
    return archive.read(entry)


def executable_entitlements(data: bytes) -> set[str]:
    """Inspect the arm64 Mach-O without executing it or trusting a sidecar plist."""
    if data[:4] in {b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"}:
        is_64 = data[:4] == b"\xca\xfe\xba\xbf"
        count = struct.unpack_from(">I", data, 4)[0]
        record_size = 32 if is_64 else 20
        if count > 32 or len(data) < 8 + count * record_size:
            raise ValueError("IPA has an invalid universal executable header.")
        slices = []
        for index in range(count):
            offset = 8 + index * record_size
            cpu = struct.unpack_from(">I", data, offset)[0]
            start, size = struct.unpack_from(">QQ" if is_64 else ">II", data, offset + 8)
            if cpu == ARM64:
                if start + size > len(data):
                    raise ValueError("IPA arm64 executable slice is truncated.")
                slices.append(data[start : start + size])
        if len(slices) != 1:
            raise ValueError("IPA requires one arm64 device executable slice.")
        data = slices[0]
    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("IPA executable must be an arm64 device Mach-O.")
    if struct.unpack_from("<I", data, 4)[0] != ARM64:
        raise ValueError("IPA executable must target arm64.")
    count, command_bytes = struct.unpack_from("<II", data, 16)
    if count > 4096 or command_bytes > 2 * 1024 * 1024 or 32 + command_bytes > len(data):
        raise ValueError("IPA executable load commands are invalid.")
    cursor, entitlements = 32, set()
    for _ in range(count):
        if cursor + 8 > 32 + command_bytes:
            raise ValueError("IPA executable load command is truncated.")
        command, size = struct.unpack_from("<II", data, cursor)
        if size < 8 or cursor + size > 32 + command_bytes:
            raise ValueError("IPA executable load command is invalid.")
        if command in {0x21, 0x2C} and (
            size < 20 or struct.unpack_from("<I", data, cursor + 16)[0] != 0
        ):
            raise ValueError("Encrypted App Store executables cannot be added to this source.")
        if command == 0x1D:  # LC_CODE_SIGNATURE
            if size < 16:
                raise ValueError("IPA code signature command is invalid.")
            start, length = struct.unpack_from("<II", data, cursor + 8)
            if length > 16 * 1024 * 1024 or start + length > len(data):
                raise ValueError("IPA code signature exceeds its bounded read budget.")
            signature = data[start : start + length]
            if len(signature) < 12:
                raise ValueError("IPA code signature is truncated.")
            magic, declared, slots = struct.unpack_from(">III", signature)
            if magic != 0xFADE0CC0 or declared != len(signature) or slots > 128:
                raise ValueError("IPA code signature container is invalid.")
            if 12 + slots * 8 > declared:
                raise ValueError("IPA code signature index is truncated.")
            xml_found, der_found = False, False
            for index in range(slots):
                slot, offset = struct.unpack_from(">II", signature, 12 + index * 8)
                if offset + 8 > declared:
                    raise ValueError("IPA code signature entry is truncated.")
                blob_magic, blob_size = struct.unpack_from(">II", signature, offset)
                if blob_size < 8 or offset + blob_size > declared:
                    raise ValueError("IPA code signature entry is invalid.")
                if slot == 5:  # CSSLOT_ENTITLEMENTS, XML encoded
                    if blob_magic != 0xFADE7171 or blob_size > MAX_PLIST_BYTES:
                        raise ValueError("IPA entitlement plist is invalid.")
                    values = plistlib.loads(signature[offset + 8 : offset + blob_size])
                    if not isinstance(values, dict):
                        raise ValueError("IPA entitlements must be a dictionary.")
                    entitlements.update(values)
                    xml_found = True
                elif slot == 7:
                    der_found = True
            if der_found and not xml_found:
                raise ValueError(
                    "DER-only entitlements require independent extraction before publication."
                )
        cursor += size
    if cursor != 32 + command_bytes:
        raise ValueError("IPA executable command size does not match its header.")
    return entitlements - {"application-identifier", "com.apple.developer.team-identifier"}


def inspect_ipa(path: Path) -> dict:
    size = path.stat().st_size
    if path.is_symlink() or not 0 < size <= MAX_IPA_BYTES:
        raise ValueError("IPA must be a regular file within the release size budget.")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or len(names) > 100_000:
            raise ValueError("IPA contains duplicate or excessive archive entries.")
        if any(name.startswith("/") or ".." in PurePosixPath(name).parts for name in names):
            raise ValueError("IPA contains unsafe archive paths.")
        roots = [name for name in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(roots) != 1:
            raise ValueError("IPA requires exactly one top-level app bundle.")
        main_name = roots[0]
        main = plistlib.loads(read_entry(archive, main_name, MAX_PLIST_BYTES))
        required = [
            "CFBundleIdentifier",
            "CFBundleShortVersionString",
            "CFBundleVersion",
            "MinimumOSVersion",
        ]
        if any(not isinstance(main.get(key), str) or not main[key] for key in required):
            raise ValueError("IPA app version, identity or minimum iOS metadata is missing.")
        if main.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise ValueError("IPA must contain an iPhoneOS device build.")
        privacy, entitlements = {}, set()
        bundles = [main_name] + [
            name
            for name in names
            if name.startswith(main_name.removesuffix("Info.plist"))
            and re.search(r"/[^/]+\.appex/Info\.plist$", name)
        ]
        for name in bundles:
            info = (
                main
                if name == main_name
                else plistlib.loads(read_entry(archive, name, MAX_PLIST_BYTES))
            )
            executable = info.get("CFBundleExecutable")
            if (
                not isinstance(executable, str)
                or not executable
                or "/" in executable
                or "\\" in executable
            ):
                raise ValueError("IPA bundle executable metadata is invalid.")
            prefix = name.removesuffix("Info.plist")
            entitlements.update(
                executable_entitlements(
                    read_entry(archive, prefix + executable, MAX_EXECUTABLE_BYTES)
                )
            )
            for key, value in info.items():
                if key.endswith("UsageDescription"):
                    if not isinstance(value, str) or not value:
                        raise ValueError("IPA privacy descriptions must be non-empty strings.")
                    if key in privacy and privacy[key] != value:
                        raise ValueError("IPA extensions have conflicting privacy descriptions.")
                    privacy[key] = value
    return {
        "bundle_identifier": main["CFBundleIdentifier"],
        "version": main["CFBundleShortVersionString"],
        "build_number": main["CFBundleVersion"],
        "min_os_version": main["MinimumOSVersion"],
        "name": main.get("CFBundleDisplayName") or main.get("CFBundleName") or "Unlabel",
        "privacy": dict(sorted(privacy.items())),
        "entitlements": sorted(entitlements),
        "size": size,
        "sha256": digest.hexdigest(),
    }


def create_source(
    ipa_path: Path,
    download_url: str,
    *,
    date: str,
    icon_url: str,
    existing: dict | None = None,
) -> dict:
    metadata = inspect_ipa(ipa_path)
    datetime.fromisoformat(date)
    if (
        re.fullmatch(r"\d+\.\d+\.\d+", metadata["version"]) is None
        or not metadata["build_number"].isdigit()
    ):
        raise ValueError("IPA version must use the project's release numbering.")
    version = {
        "version": metadata["version"],
        "buildVersion": metadata["build_number"],
        "date": date,
        "downloadURL": public_url(download_url),
        "size": metadata["size"],
        "sha256": metadata["sha256"],
        "minOSVersion": metadata["min_os_version"],
    }
    source = (
        copy.deepcopy(existing)
        if existing is not None
        else {
            "name": "Unlabel iOS",
            "identifier": "in.unlabel.ios-source",
            "website": "https://github.com/Vaibhavsh0120/Unlabel",
            "description": DESCRIPTION,
            "apps": [],
            "news": [],
        }
    )
    if not isinstance(source.get("apps"), list) or len(source["apps"]) > 1:
        raise ValueError("Existing source must contain only the Unlabel app.")
    old = source["apps"][0] if source["apps"] else {}
    if old and old.get("bundleIdentifier") != metadata["bundle_identifier"]:
        raise ValueError("Existing source has a different app identity.")
    versions = old.get("versions", [])
    if not isinstance(versions, list):
        raise TypeError("Existing source versions must be a list.")

    def release_order(item):
        return tuple(int(part) for part in item["version"].split(".")), int(item["buildVersion"])

    if versions and release_order(version) < max(release_order(item) for item in versions):
        # Permissions describe the latest app. An older publication must not
        # replace them while the newer version remains first in the source.
        raise ValueError("Incoming IPA is older than the latest published source version.")
    for previous in versions:
        public_url(previous["downloadURL"])
        if (
            previous["version"] == version["version"]
            and previous["buildVersion"] == version["buildVersion"]
        ):
            if any(previous.get(key) != version[key] for key in ["downloadURL", "size", "sha256"]):
                raise ValueError("An existing source version cannot be silently replaced.")
            version = previous
    versions = [
        item
        for item in versions
        if (item["version"], item["buildVersion"]) != (version["version"], version["buildVersion"])
    ]
    versions.append(version)
    versions.sort(key=release_order, reverse=True)
    source["apps"] = [
        {
            "name": metadata["name"],
            "bundleIdentifier": metadata["bundle_identifier"],
            "developerName": "Vaibhav",
            "localizedDescription": DESCRIPTION,
            "iconURL": public_url(icon_url),
            "tintColor": "#174B38",
            "versions": versions,
            "appPermissions": {
                "entitlements": metadata["entitlements"],
                "privacy": metadata["privacy"],
            },
        }
    ]
    return source


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--date", required=True)
    parser.add_argument("--icon-url", required=True)
    parser.add_argument("--existing", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        existing = json.loads(args.existing.read_text(encoding="utf-8")) if args.existing else None
        source = create_source(
            args.ipa, args.download_url, date=args.date, icon_url=args.icon_url, existing=existing
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        struct.error,
        zipfile.BadZipFile,
        plistlib.InvalidFileException,
    ):
        print(
            "iOS source generation failed: IPA or source metadata did not validate.",
            file=sys.stderr,
        )
        return 1
    print(
        "Generated iOS source from actual IPA metadata and bytes; device compatibility remains unverified."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
