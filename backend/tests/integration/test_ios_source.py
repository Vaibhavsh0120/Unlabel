import copy
import hashlib
import importlib.util
import plistlib
import struct
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]


def module():
    spec = importlib.util.spec_from_file_location("ios_source_test", ROOT / "scripts/ios_source.py")
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def executable(*, cpu=0x0100000C, encrypted=False, entitlements=None, der_only=False):
    commands = []
    signature = b""
    if encrypted:
        commands.append(struct.pack("<IIIIII", 0x2C, 24, 0, 0, 1, 0))
    if entitlements is not None or der_only:
        blob = plistlib.dumps(entitlements or {})
        blob = struct.pack(">II", 0xFADE7171, len(blob) + 8) + blob
        signature = struct.pack(">III", 0xFADE0CC0, len(blob) + 20, 1)
        signature += struct.pack(">II", 7 if der_only else 5, 20) + blob
        command_bytes = sum(len(command) for command in commands) + 16
        commands.append(struct.pack("<IIII", 0x1D, 16, 32 + command_bytes, len(signature)))
    header = struct.pack(
        "<IIIIIIII", 0xFEEDFACF, cpu, 0, 2, len(commands), sum(len(c) for c in commands), 0, 0
    )
    return header + b"".join(commands) + signature


def ipa(
    tmp_path, *, version="0.7.0", build="11", machine=None, extensions=False, platform="iPhoneOS"
):
    path = tmp_path / f"unlabel-{version}-{build}.ipa"
    info = {
        "CFBundleIdentifier": "in.unlabel.unlabel",
        "CFBundleDisplayName": "Unlabel",
        "CFBundleExecutable": "Runner",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "MinimumOSVersion": "15.0",
        "CFBundleSupportedPlatforms": [platform],
        "NSCameraUsageDescription": "Read food labels with the camera.",
        "NSPhotoLibraryUsageDescription": "Choose label images.",
    }
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(info))
        archive.writestr("Payload/Runner.app/Runner", machine or executable())
        if extensions:
            extension = {
                "CFBundleExecutable": "Extension",
                "NSMicrophoneUsageDescription": "Synthetic extension privacy.",
            }
            archive.writestr(
                "Payload/Runner.app/PlugIns/Test.appex/Info.plist", plistlib.dumps(extension)
            )
            archive.writestr(
                "Payload/Runner.app/PlugIns/Test.appex/Extension",
                executable(entitlements={"com.apple.developer.siri": True}),
            )
    return path


def source(tool, path, existing=None):
    return tool.create_source(
        path,
        f"https://github.com/Vaibhavsh0120/Unlabel/releases/download/mobile-v0.7.0%2B11/{path.name}",
        date="2026-10-12T12:00:00Z",
        icon_url="https://example.test/icon.png",
        existing=existing,
    )


def test_source_uses_actual_device_ipa_identity_privacy_size_and_hash(tmp_path):
    tool = module()
    path = ipa(tmp_path, extensions=True)
    result = source(tool, path)
    app = result["apps"][0]
    assert app["bundleIdentifier"] == "in.unlabel.unlabel"
    assert app["appPermissions"]["entitlements"] == ["com.apple.developer.siri"]
    assert set(app["appPermissions"]["privacy"]) == {
        "NSCameraUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "NSMicrophoneUsageDescription",
    }
    assert app["versions"][0] == {
        "version": "0.7.0",
        "buildVersion": "11",
        "date": "2026-10-12T12:00:00Z",
        "downloadURL": f"https://github.com/Vaibhavsh0120/Unlabel/releases/download/mobile-v0.7.0%2B11/{path.name}",
        "size": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "minOSVersion": "15.0",
    }
    assert "unsigned" in app["localizedDescription"]


def test_source_preserves_verified_versions_in_numeric_newest_first_order(tmp_path):
    tool = module()
    older = source(tool, ipa(tmp_path, version="0.2.0", build="3"))
    result = source(tool, ipa(tmp_path), older)
    assert [(v["version"], v["buildVersion"]) for v in result["apps"][0]["versions"]] == [
        ("0.7.0", "11"),
        ("0.2.0", "3"),
    ]
    assert len(older["apps"][0]["versions"]) == 1
    assert source(tool, ipa(tmp_path), result) == result


@pytest.mark.parametrize(("version", "build"), [("0.2.0", "3"), ("0.7.0", "10")])
def test_source_rejects_older_publish_without_changing_latest_permissions(tmp_path, version, build):
    tool = module()
    existing = source(tool, ipa(tmp_path, extensions=True))
    original = copy.deepcopy(existing)
    with pytest.raises(ValueError, match="older than the latest"):
        source(tool, ipa(tmp_path, version=version, build=build), existing)
    assert existing == original
    latest = existing["apps"][0]
    assert latest["versions"][0]["version"] == "0.7.0"
    assert latest["versions"][0]["buildVersion"] == "11"
    assert latest["appPermissions"]["entitlements"] == ["com.apple.developer.siri"]
    assert "NSMicrophoneUsageDescription" in latest["appPermissions"]["privacy"]


def test_source_rejects_silent_replacement_of_same_version(tmp_path):
    tool = module()
    path = ipa(tmp_path)
    existing = source(tool, path)
    with zipfile.ZipFile(path, "a") as archive:
        archive.writestr("Payload/Runner.app/new-file", "different bytes")
    with pytest.raises(ValueError, match="silently replaced"):
        source(tool, path, existing)


@pytest.mark.parametrize(
    "machine",
    [
        executable(cpu=0x01000007),
        executable(encrypted=True),
        executable(der_only=True),
        b"not executable",
    ],
)
def test_source_rejects_simulator_encrypted_unknown_entitlement_or_invalid_executable(
    tmp_path, machine
):
    with pytest.raises(ValueError):
        source(module(), ipa(tmp_path, machine=machine))


def test_source_rejects_simulator_metadata_and_unsafe_or_duplicate_archive_paths(tmp_path):
    tool = module()
    with pytest.raises(ValueError, match="iPhoneOS"):
        source(tool, ipa(tmp_path, platform="iPhoneSimulator"))
    path = ipa(tmp_path)
    with zipfile.ZipFile(path, "a") as archive:
        archive.writestr("../outside", "synthetic")
    with pytest.raises(ValueError, match="unsafe archive"):
        source(tool, path)


@pytest.mark.parametrize(
    "url",
    [
        "http://example.test/app.ipa",
        "https://user:secret@example.test/app.ipa",
        "https://example.test/with space.ipa",
    ],
)
def test_source_rejects_credential_or_non_public_download_urls(tmp_path, url):
    with pytest.raises(ValueError, match="public HTTPS"):
        module().create_source(
            ipa(tmp_path), url, date="2026-10-12", icon_url="https://example.test/icon.png"
        )
