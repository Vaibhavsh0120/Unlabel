import gzip
import hashlib
import importlib
import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest

EXPORTED_AT = "2026-10-05T12:19:34Z"
SOURCE_URL = "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"


def bundle_api():
    try:
        return importlib.import_module("app.catalogue.bundle")
    except ModuleNotFoundError:
        pytest.fail("The packaged catalogue builder and verifier are not implemented")


def source_bundle(tmp_path):
    directory = tmp_path / "source"
    directory.mkdir()
    decoded = (
        json.dumps(
            {
                "code": "0123456789012",
                "countries_tags": ["en:india"],
                "product_name": "Synthetic oats",
                "ingredients_text": "Oats, milk",
                "allergens_tags": ["en:milk"],
                "traces_tags": [],
            }
        )
        + "\n"
    ).encode()
    compressed = gzip.compress(decoded, mtime=0)
    (directory / "india-products.jsonl.gz").write_bytes(compressed)
    descriptor = {
        "schema_version": "1",
        "source_file": "india-products.jsonl.gz",
        "source_format": "off_csv_projection",
        "source_url": SOURCE_URL,
        "exported_at": EXPORTED_AT,
        "coverage": "unverified",
        "compressed_sha256": hashlib.sha256(compressed).hexdigest(),
        "compressed_bytes": len(compressed),
        "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
        "decoded_bytes": len(decoded),
        "expected_input_rows": 1,
        "indexed_products": 1,
        "unsupported_barcodes": 0,
        "market_tag": "en:india",
        "database_license": "ODbL-1.0",
        "contents_license": "DbCL-1.0",
        "attribution": "Product data from Open Food Facts",
        "refresh_interval_months": 9,
    }
    write_descriptor(directory, descriptor)
    return directory, descriptor


def write_descriptor(directory, descriptor):
    (directory / "bundle.json").write_text(json.dumps(descriptor), encoding="utf-8")


def built_bundle(tmp_path):
    module = bundle_api()
    source, descriptor = source_bundle(tmp_path)
    output = tmp_path / "package"
    receipt = module.build_bundle(source, output)
    return module, source, descriptor, output, receipt


def test_build_indexes_the_verified_local_source_and_returns_only_public_metadata(tmp_path):
    module, _, descriptor, output, receipt = built_bundle(tmp_path)
    from app.catalogue.store import CatalogueStore

    assert receipt["schema_version"] == "1"
    assert receipt["database_file"] == "catalogue.sqlite3"
    assert receipt["database_bytes"] == (output / "catalogue.sqlite3").stat().st_size
    assert (
        receipt["database_sha256"]
        == hashlib.sha256((output / "catalogue.sqlite3").read_bytes()).hexdigest()
    )
    assert receipt["source_sha256"] == descriptor["decoded_sha256"]
    assert receipt["source_compressed_sha256"] == descriptor["compressed_sha256"]
    assert receipt["exported_at"] == EXPORTED_AT
    assert receipt["indexed_products"] == 1
    assert receipt["coverage"] == "unverified"
    assert receipt["source_format"] == "off_csv_projection"
    assert "Synthetic oats" not in json.dumps(receipt)
    assert "Oats, milk" not in json.dumps(receipt)
    assert CatalogueStore(output).lookup("0123456789012").status == "found"
    assert module.verify_bundle(output) == receipt
    assert sorted(path.name for path in output.iterdir()) == ["catalogue.sqlite3", "receipt.json"]


@pytest.mark.parametrize(
    "field,value",
    [
        ("compressed_sha256", "0" * 64),
        ("decoded_sha256", "0" * 64),
        ("compressed_bytes", 1),
        ("decoded_bytes", 1),
        ("expected_input_rows", 2),
        ("indexed_products", 2),
        ("unsupported_barcodes", 1),
        ("compressed_bytes", True),
        ("decoded_bytes", 100 * 1024**2 + 1),
        ("source_file", "../private.jsonl.gz"),
        ("schema_version", "2"),
        ("exported_at", "2026-10-05T12:19:34"),
        ("exported_at", "0001-01-01T00:00:00+01:00"),
        ("exported_at", "9999-12-31T23:59:59-01:00"),
        ("exported_at", "9999-12-31T12:00:00Z"),
        ("coverage", "complete"),
        ("source_url", "https://example.com/catalogue.gz"),
    ],
)
def test_invalid_source_metadata_preserves_the_active_database_and_receipt(tmp_path, field, value):
    module, source, descriptor, output, _ = built_bundle(tmp_path)
    original = {path.name: path.read_bytes() for path in output.iterdir()}
    descriptor[field] = value
    write_descriptor(source, descriptor)
    with pytest.raises((ValueError, OSError)):
        module.build_bundle(source, output)
    assert {path.name: path.read_bytes() for path in output.iterdir()} == original


def test_a_truncated_gzip_with_matching_compressed_hash_cannot_replace_the_active_bundle(tmp_path):
    module, source, descriptor, output, _ = built_bundle(tmp_path)
    original = {path.name: path.read_bytes() for path in output.iterdir()}
    path = source / "india-products.jsonl.gz"
    compressed = path.read_bytes()[:-6]
    path.write_bytes(compressed)
    descriptor["compressed_bytes"] = len(compressed)
    descriptor["compressed_sha256"] = hashlib.sha256(compressed).hexdigest()
    write_descriptor(source, descriptor)
    with pytest.raises((ValueError, OSError)):
        module.build_bundle(source, output)
    assert {path.name: path.read_bytes() for path in output.iterdir()} == original


def test_decoded_data_cannot_exceed_the_build_budget_even_if_metadata_understates_its_size(
    tmp_path, monkeypatch
):
    module = bundle_api()
    source, descriptor = source_bundle(tmp_path)
    descriptor["decoded_bytes"] = 100
    write_descriptor(source, descriptor)
    monkeypatch.setattr(module, "MAX_DECODED_BYTES", 128)
    with pytest.raises(ValueError):
        module.build_bundle(source, tmp_path / "package")
    assert not (tmp_path / "package" / "catalogue.sqlite3").exists()


@pytest.mark.parametrize(
    "field,value",
    [
        ("schema_version", "2"),
        ("database_file", "../catalogue.sqlite3"),
        ("database_sha256", "0" * 64),
        ("database_bytes", 1),
        ("database_bytes", True),
        ("database_bytes", 100 * 1024**2 + 1),
        ("source_sha256", "0" * 64),
        ("source_compressed_sha256", "not-a-hash"),
        ("indexed_products", 2),
        ("exported_at", "2026-10-04T12:19:34Z"),
        ("snapshot_id", "other-snapshot"),
        ("coverage", "sample"),
        ("source_format", "off_jsonl"),
    ],
)
def test_receipt_tampering_is_rejected_before_runtime_use(tmp_path, field, value):
    module, _, _, output, receipt = built_bundle(tmp_path)
    receipt[field] = value
    (output / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
    with pytest.raises((ValueError, OSError)):
        module.verify_bundle(output)


@pytest.mark.parametrize("content", ["{}", '{"schema_version":NaN}', "[]"])
def test_malformed_receipt_cannot_be_loaded(tmp_path, content):
    module, _, _, output, _ = built_bundle(tmp_path)
    (output / "receipt.json").write_text(content, encoding="utf-8")
    with pytest.raises((ValueError, OSError)):
        module.verify_bundle(output)


def test_corrupt_database_is_rejected_even_if_receipt_hash_is_updated(tmp_path):
    module, _, _, output, receipt = built_bundle(tmp_path)
    database = output / "catalogue.sqlite3"
    database.write_bytes(b"not a SQLite database")
    receipt["database_sha256"] = hashlib.sha256(database.read_bytes()).hexdigest()
    receipt["database_bytes"] = database.stat().st_size
    (output / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
    with pytest.raises((ValueError, OSError)):
        module.verify_bundle(output)


def test_deleted_record_cannot_pass_with_a_rehashed_database(tmp_path):
    module, _, _, output, receipt = built_bundle(tmp_path)
    database = output / "catalogue.sqlite3"
    with sqlite3.connect(database) as connection:
        connection.execute("DELETE FROM catalogue_products")
    receipt["database_sha256"] = hashlib.sha256(database.read_bytes()).hexdigest()
    receipt["database_bytes"] = database.stat().st_size
    (output / "receipt.json").write_text(json.dumps(receipt), encoding="utf-8")
    with pytest.raises((ValueError, OSError)):
        module.verify_bundle(output)


def test_bundle_can_be_rebuilt_from_the_same_source_without_relying_on_identical_sqlite_bytes(
    tmp_path,
):
    module, source, _, output, first = built_bundle(tmp_path)
    second = module.build_bundle(source, output)
    for key in ("source_sha256", "source_compressed_sha256", "indexed_products", "exported_at"):
        assert second[key] == first[key]
    assert module.verify_bundle(output) == second


def test_receipt_publication_failure_is_reported_and_staging_files_are_removed(
    tmp_path, monkeypatch
):
    module = bundle_api()
    source, _ = source_bundle(tmp_path)
    output = tmp_path / "package"
    original_replace = module.os.replace

    def failing_replace(source_path, destination):
        if Path(destination).name == "receipt.json":
            raise OSError("synthetic receipt publication failure")
        return original_replace(source_path, destination)

    monkeypatch.setattr(module.os, "replace", failing_replace)
    with pytest.raises(OSError, match="receipt publication failure"):
        module.build_bundle(source, output)
    assert sorted(path.name for path in output.iterdir()) == ["catalogue.sqlite3"]


@pytest.mark.parametrize("filename", ["receipt.json", "catalogue.sqlite3"])
def test_runtime_bundle_rejects_symlink_files(tmp_path, filename):
    module, _, _, output, _ = built_bundle(tmp_path)
    path = output / filename
    target = tmp_path / filename
    path.rename(target)
    try:
        path.symlink_to(target)
    except OSError:
        pytest.skip("This Windows account cannot create symlinks")
    with pytest.raises((ValueError, OSError)):
        module.verify_bundle(output)


def test_source_bundle_rejects_symlink_files_before_publication(tmp_path):
    module = bundle_api()
    source, _ = source_bundle(tmp_path)
    path = source / "india-products.jsonl.gz"
    target = tmp_path / "input.gz"
    path.rename(target)
    try:
        path.symlink_to(target)
    except OSError:
        pytest.skip("This Windows account cannot create symlinks")
    with pytest.raises((ValueError, OSError)):
        module.build_bundle(source, tmp_path / "package")
    assert not (tmp_path / "package" / "catalogue.sqlite3").exists()


def test_cli_builds_without_environment_decryption_and_prints_only_the_receipt(tmp_path):
    bundle_api()
    source, _ = source_bundle(tmp_path)
    output = tmp_path / "package"
    script = Path(__file__).resolve().parents[2] / "build_catalogue.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--source-directory",
            str(source),
            "--output-directory",
            str(output),
        ],
        cwd=script.parent,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    receipt = json.loads(result.stdout)
    assert receipt["indexed_products"] == 1
    assert receipt["database_file"] == "catalogue.sqlite3"
    assert "Synthetic oats" not in result.stdout
    assert "Oats, milk" not in result.stdout
    assert "decryption" not in result.stderr
