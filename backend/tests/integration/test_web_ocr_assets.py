"""The offline OCR build gate must reject incomplete or untrusted asset receipts."""

import hashlib
import importlib.util
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]


@pytest.fixture
def vendor():
    spec = importlib.util.spec_from_file_location(
        "web_ocr_vendor", ROOT / "scripts/vendor_web_ocr.py"
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def bundle(tmp_path, monkeypatch, vendor):
    manifest = json.loads((ROOT / "frontend/web/ocr/provenance.json").read_text())
    for entry in manifest["files"]:
        target = tmp_path / entry["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"x")
        entry["bytes"] = 1
        entry["sha256"] = hashlib.sha256(b"x").hexdigest()
    monkeypatch.setattr(vendor, "TARGET", tmp_path)
    return vendor, tmp_path, manifest


def verify(bundle):
    vendor, directory, manifest = bundle
    (directory / "provenance.json").write_text(json.dumps(manifest), encoding="utf-8")
    vendor.check()


def test_current_tracked_bundle_verifies_without_downloading(vendor, monkeypatch, capsys):
    monkeypatch.setattr(
        vendor, "download", lambda _: pytest.fail("Offline verification must not download")
    )
    vendor.check()
    assert "Verified 21 pinned local OCR assets" in capsys.readouterr().out


def test_complete_bounded_fixture_verifies(bundle):
    verify(bundle)


@pytest.mark.parametrize("change", ["empty", "missing", "duplicate", "extra"])
def test_rejects_incomplete_or_duplicate_asset_sets(bundle, change):
    _, directory, manifest = bundle
    if change == "empty":
        manifest["files"] = []
    elif change == "missing":
        manifest["files"].pop()
    elif change == "duplicate":
        manifest["files"].append(dict(manifest["files"][0]))
    else:
        entry = dict(manifest["files"][0], path="extra.js")
        (directory / "extra.js").write_bytes(b"x")
        manifest["files"].append(entry)
    with pytest.raises(ValueError):
        verify(bundle)


@pytest.mark.parametrize("path_kind", ["dot", "backslash", "absolute", "parent"])
def test_rejects_noncanonical_or_untrusted_asset_paths(bundle, path_kind):
    _, directory, manifest = bundle
    entry = manifest["files"][0]
    entry["path"] = {
        "dot": "core/./tesseract-core-lstm.wasm",
        "backslash": "core\\tesseract-core-lstm.wasm",
        "absolute": str(directory / "core/tesseract-core-lstm.wasm"),
        "parent": "../outside.wasm",
    }[path_kind]
    with pytest.raises(ValueError):
        verify(bundle)


@pytest.mark.parametrize(
    "change",
    ["schema", "extra_key", "empty_sources", "duplicate_source", "engine", "model", "origin"],
)
def test_rejects_untrusted_manifest_or_source_metadata(bundle, change):
    manifest = bundle[2]
    if change == "schema":
        manifest["schema_version"] = True
    elif change == "extra_key":
        manifest["unexpected"] = "unreviewed"
    elif change == "empty_sources":
        manifest["sources"] = []
    elif change == "duplicate_source":
        manifest["sources"].append(dict(manifest["sources"][0]))
    elif change == "engine":
        manifest["sources"][0]["version"] = "6.0.0"
    elif change == "model":
        manifest["sources"][2]["revision"] = "0" * 40
    else:
        manifest["files"][0]["source"] = "https://untrusted.test/engine.tgz"
    with pytest.raises(ValueError):
        verify(bundle)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("bytes", True),
        ("bytes", 1.0),
        ("bytes", 0),
        ("bytes", 100 * 1024 * 1024 + 1),
        ("sha256", "A" * 64),
        ("sha256", "0" * 63),
    ],
)
def test_rejects_invalid_asset_size_or_hash_metadata(bundle, field, value):
    bundle[2]["files"][0][field] = value
    with pytest.raises(ValueError):
        verify(bundle)


def test_rejects_manifest_exceeding_a_finite_byte_budget(bundle):
    bundle[2]["purpose"] = "x" * (1024 * 1024)
    with pytest.raises(ValueError):
        verify(bundle)


def test_rejects_duplicate_json_keys(bundle):
    vendor, directory, manifest = bundle
    text = json.dumps(manifest).replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1')
    (directory / "provenance.json").write_text(text, encoding="utf-8")
    with pytest.raises(ValueError):
        vendor.check()


def test_rejects_changed_asset_bytes(bundle):
    _, directory, manifest = bundle
    (directory / manifest["files"][0]["path"]).write_bytes(b"modified")
    with pytest.raises(ValueError):
        verify(bundle)
