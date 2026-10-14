import gzip
import hashlib
import json
import sqlite3
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from pydantic import ValidationError

SOURCE_URL = "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"
EXPORTED_AT = datetime(2026, 10, 5, 9, 30, tzinfo=timezone(timedelta(hours=5, minutes=30)))


def catalogue_api():
    try:
        from app.catalogue.importer import build_catalogue
        from app.catalogue.store import CatalogueStore
    except ModuleNotFoundError:
        pytest.fail("The local streaming catalogue importer and store are not implemented")
    return build_catalogue, CatalogueStore


def india_product(code: object = "0123456789012", **fields):
    return {
        "code": code,
        "countries_tags": ["en:india"],
        "product_name": "Synthetic oats",
        "ingredients_text": "Oats, milk",
        "allergens_tags": ["en:milk"],
        "traces_tags": [],
        **fields,
    }


def write_rows(path, rows):
    data = b"".join((json.dumps(row, ensure_ascii=True) + "\n").encode() for row in rows)
    path.write_bytes(data)
    return data


def build(tmp_path, rows=None, **kwargs):
    importer, store_type = catalogue_api()
    source = tmp_path / "input.jsonl"
    write_rows(source, [india_product()] if rows is None else rows)
    directory = tmp_path / "catalogue"
    directory.mkdir(exist_ok=True)
    manifest = importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT, **kwargs)
    return manifest, store_type(directory), directory


def test_streaming_import_filters_exact_india_tag_and_retains_exact_barcode(tmp_path):
    manifest, store, _ = build(
        tmp_path,
        [
            india_product(countries_tags=["en:france"]),
            india_product("123456789012", countries_tags=["en:indian-ocean"]),
            india_product(),
        ],
    )
    assert manifest.rows_read == 3
    assert manifest.india_rows == 1
    assert manifest.indexed_products == 1
    result = store.lookup("0123456789012")
    assert result.status == "found"
    assert result.product is not None
    assert result.product.barcode == "0123456789012"
    assert store.lookup("123456789012").status == "not_found"
    assert result.manifest == manifest
    assert "source" not in result.model_dump()
    assert "retrieved_at" not in result.model_dump_json()


def test_source_hash_uses_complete_decoded_jsonl_and_export_date_is_preserved(tmp_path):
    importer, store_type = catalogue_api()
    source = tmp_path / "input.gz"
    decoded = (
        json.dumps(india_product()) + "\n" + json.dumps(india_product(countries_tags=[]))
    ).encode()
    source.write_bytes(gzip.compress(decoded))
    directory = tmp_path / "catalogue"
    directory.mkdir()
    manifest = importer(
        source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT, coverage="unverified"
    )
    assert manifest.source_sha256 == hashlib.sha256(decoded).hexdigest()
    assert manifest.exported_at == EXPORTED_AT
    assert manifest.exported_at.utcoffset() == timedelta(hours=5, minutes=30)
    assert manifest.indexed_at.utcoffset() == timedelta(0)
    assert manifest.coverage == "unverified"
    assert manifest.database_license == "ODbL-1.0"
    assert manifest.contents_license == "DbCL-1.0"
    assert manifest.license_url == "https://openfoodfacts.org/terms-of-use"
    assert manifest.attribution == "Product data from Open Food Facts"
    assert store_type(directory).manifest == manifest


@pytest.mark.parametrize(
    "expectation",
    [
        {"expected_source_sha256": "0" * 64},
        {"expected_rows_read": 10},
        {"expected_indexed_products": 10},
    ],
)
def test_bundle_expectation_mismatch_preserves_active_database(tmp_path, expectation):
    importer, store_type = catalogue_api()
    original, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    previous_bytes = active.read_bytes()
    source = tmp_path / "replacement.jsonl"
    write_rows(source, [india_product("8900000000001")])
    with pytest.raises(ValueError, match="expected bundle"):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT, **expectation)
    assert active.read_bytes() == previous_bytes
    assert store_type(directory).manifest == original
    assert not (directory / ".catalogue-import.lock").exists()


def test_csv_projection_provenance_has_no_api_wrapper(tmp_path):
    manifest, store, _ = build(tmp_path, source_format="off_csv_projection")
    assert manifest.source_format == "off_csv_projection"
    result = store.lookup("0123456789012")
    assert result.manifest is not None
    assert "csv_projection" in result.manifest.source_format
    serialized = result.model_dump(mode="json")
    assert "source" not in serialized
    assert "upstream_api_version" not in serialized["manifest"]
    assert "retrieved_at" not in serialized["manifest"]


def test_zero_prefixes_identify_separate_products_without_normalization(tmp_path):
    manifest, store, _ = build(
        tmp_path,
        [india_product("123456789012"), india_product("0123456789012", product_name="Other")],
    )
    assert manifest.indexed_products == 2
    first = store.lookup("123456789012")
    second = store.lookup("0123456789012")
    assert first.product is not None and second.product is not None
    assert first.product.name == "Synthetic oats"
    assert second.product.name == "Other"
    assert store.lookup("00123456789012").status == "not_found"


def test_unsupported_barcodes_are_counted_without_coercion(tmp_path):
    manifest, _, _ = build(
        tmp_path,
        [
            india_product(),
            india_product("１２３４５６７８"),
            india_product(12345678),
            india_product("123456789"),
        ],
    )
    assert manifest.india_rows == 4
    assert manifest.indexed_products == 1
    assert manifest.unsupported_barcodes == 3


def test_missing_invalid_and_oversized_optional_fields_remain_unknown(tmp_path):
    manifest, store, _ = build(
        tmp_path,
        [
            india_product(
                product_name=" " * 4,
                brands="b" * 2001,
                quantity=True,
                ingredients_text="i" * 16001,
                allergens_tags="milk",
                traces_tags=["t"] * 101,
                nutriscore_grade="unknown",
                nova_group=True,
                image_url="https://example.test/image.png",
                secret_raw_field="not part of the product contract",
            )
        ],
    )
    result = store.lookup("0123456789012")
    assert manifest.missing_name == 1
    assert manifest.missing_ingredients == 1
    assert result.product is not None
    assert result.product.name is None
    assert result.product.brands is None
    assert result.product.quantity_text is None
    assert result.product.ingredients_text is None
    assert result.product.allergen_tags == []
    assert result.product.trace_tags == []
    assert result.product.insights.nova_group is None
    assert result.product.insights.nutri_score_grade is None
    assert "allergens_tags_invalid" in result.warnings
    assert "traces_tags_invalid" in result.warnings
    assert "ingredients_missing" in result.warnings
    assert "allergen_safety_not_assessed" in result.warnings
    assert "community_record_not_package_verified" in result.warnings
    assert "snapshot_age_needs_review" in result.warnings
    assert "secret_raw_field" not in result.model_dump_json()
    assert "image_url" not in result.model_dump_json()


def test_missing_allergen_data_is_marked_missing_instead_of_allergen_free(tmp_path):
    row = india_product()
    del row["allergens_tags"]
    del row["traces_tags"]
    _, store, _ = build(tmp_path, [row])
    result = store.lookup("0123456789012")
    assert result.product is not None
    assert result.product.allergen_tags == []
    assert "allergens_tags_missing" in result.warnings
    assert "traces_tags_missing" in result.warnings
    assert "allergen_safety_not_assessed" in result.warnings


@pytest.mark.parametrize(
    "tail",
    [
        b'{"code":',
        b"[]\n",
        b'{"countries_tags":"en:india"}\n',
        b'{"countries_tags":[null]}\n',
        b'{"countries_tags":[],"number":NaN}\n',
        b'{"countries_tags":[],"number":1e999}\n',
        b'{"countries_tags":[],"number":0.1234567890123456789}\n',
        b'{"countries_tags":[],"bad":"\xff"}\n',
        b"x" * (512 * 1024 + 1),
    ],
    ids=[
        "truncated",
        "nonobject",
        "countries-type",
        "countries-item",
        "nan",
        "infinite",
        "precision",
        "utf8",
        "oversized",
    ],
)
def test_malformed_late_row_preserves_previous_snapshot_and_user_files(tmp_path, tail):
    importer, store_type = catalogue_api()
    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    unrelated = directory / ".catalogue-user.sqlite3"
    unrelated.write_bytes(b"user owned file")
    source = tmp_path / "broken.jsonl"
    source.write_bytes((json.dumps(india_product("123456789012")) + "\n").encode() + tail)
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original
    assert unrelated.read_bytes() == b"user owned file"
    assert set(directory.iterdir()) == {active, unrelated}
    assert store_type(directory).lookup("0123456789012").status == "found"


def test_duplicate_exact_barcode_aborts_without_replacing_previous_snapshot(tmp_path):
    importer, _ = catalogue_api()
    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    source = tmp_path / "duplicates.jsonl"
    write_rows(source, [india_product(), india_product(product_name="Conflicting row")])
    with pytest.raises(ValueError, match="[Dd]uplicate"):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original
    assert list(directory.iterdir()) == [active]


def test_concurrent_import_is_rejected_before_staging_while_first_waits_to_publish(
    tmp_path, monkeypatch
):
    importer, store_type = catalogue_api()
    from app.catalogue import importer as importer_module

    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    first_source = tmp_path / "first.jsonl"
    second_source = tmp_path / "second.jsonl"
    write_rows(first_source, [india_product("123456789012", product_name="First importer")])
    write_rows(second_source, [india_product("876543210987", product_name="Second importer")])
    ready_to_publish = threading.Event()
    release_publish = threading.Event()
    original_replace = importer_module.os.replace

    def paused_replace(source, target):
        if threading.current_thread() is not threading.main_thread():
            ready_to_publish.set()
            assert release_publish.wait(5), "test did not release the first importer"
        return original_replace(source, target)

    monkeypatch.setattr(importer_module.os, "replace", paused_replace)
    with ThreadPoolExecutor(max_workers=1) as executor:
        first = executor.submit(
            importer, first_source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT
        )
        try:
            assert ready_to_publish.wait(5), "first importer did not reach publication"
            before = {path: path.read_bytes() for path in directory.iterdir()}
            with pytest.raises(ValueError, match="[Bb]usy|[Ll]ock"):
                importer(second_source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
            assert {path: path.read_bytes() for path in directory.iterdir()} == before
            assert active.read_bytes() == original
        finally:
            release_publish.set()
            first.result(timeout=5)
    store = store_type(directory)
    first = store.lookup("123456789012")
    assert first.product is not None
    assert first.product.name == "First importer"
    assert store.lookup("876543210987").status == "not_found"
    assert list(directory.iterdir()) == [active]


def test_existing_import_lock_is_preserved_and_requires_operator_review(tmp_path):
    importer, _ = catalogue_api()
    _, _, directory = build(tmp_path)
    lock = directory / ".catalogue-import.lock"
    lock.write_bytes(b"unreviewed lock from a previous process")
    unrelated = directory / "operator-notes.txt"
    unrelated.write_bytes(b"preserve this operator file")
    before = {path: path.read_bytes() for path in directory.iterdir()}
    source = tmp_path / "next.jsonl"
    write_rows(source, [india_product("123456789012")])
    with pytest.raises(ValueError, match="[Bb]usy|[Ll]ock"):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert {path: path.read_bytes() for path in directory.iterdir()} == before


def test_changed_lock_aborts_publication_and_does_not_delete_operator_lock(tmp_path, monkeypatch):
    importer, _ = catalogue_api()
    from app.catalogue import importer as importer_module

    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    lock = directory / ".catalogue-import.lock"
    replacement = b"operator replaced lock; review before importing"
    source = tmp_path / "next.jsonl"
    write_rows(source, [india_product("123456789012")])
    original_rows = importer_module._stream_rows

    def changed_lock_rows(source, digest):
        yield from original_rows(source, digest)
        lock.write_bytes(replacement)

    monkeypatch.setattr(importer_module, "_stream_rows", changed_lock_rows)
    with pytest.raises(ValueError, match="lock changed"):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original
    assert lock.read_bytes() == replacement
    assert set(directory.iterdir()) == {active, lock}


def test_truncated_gzip_requires_eof_before_replacing_snapshot(tmp_path):
    importer, _ = catalogue_api()
    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    source = tmp_path / "truncated.gz"
    source.write_bytes(gzip.compress((json.dumps(india_product()) + "\n").encode())[:-8])
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original


@pytest.mark.parametrize("kwargs", [{"max_artifact_bytes": 8192}, {"max_work_bytes": 4096}])
def test_resource_budget_failure_preserves_previous_snapshot(tmp_path, kwargs):
    importer, _ = catalogue_api()
    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    source = tmp_path / "next.jsonl"
    write_rows(source, [india_product("123456789012")])
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT, **kwargs)
    assert active.read_bytes() == original
    assert list(directory.iterdir()) == [active]


def test_work_budget_counts_unrelated_files_and_input_in_directory(tmp_path):
    importer, _ = catalogue_api()
    directory = tmp_path / "catalogue"
    directory.mkdir()
    user_file = directory / "notes.bin"
    user_file.write_bytes(b"x" * 40000)
    source = directory / "input.jsonl"
    write_rows(source, [india_product()])
    with pytest.raises(ValueError):
        importer(
            source,
            directory,
            source_url=SOURCE_URL,
            exported_at=EXPORTED_AT,
            max_work_bytes=40000,
        )
    assert user_file.read_bytes() == b"x" * 40000
    assert source.exists()
    assert not (directory / "catalogue.sqlite3").exists()


def test_work_budget_caps_staging_growth_before_batch_commit(tmp_path, monkeypatch):
    importer, _ = catalogue_api()
    from app.catalogue import importer as importer_module

    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    source = tmp_path / "larger.jsonl"
    write_rows(
        source,
        [india_product(f"{number:012d}", ingredients_text="i" * 16000) for number in range(100)],
    )
    limit = active.stat().st_size + 32 * 1024
    observed_sizes = []
    original_check = importer_module._check_work_budget

    def check(directory, budget):
        observed_sizes.append(sum(path.stat().st_size for path in directory.iterdir()))
        original_check(directory, budget)

    monkeypatch.setattr(importer_module, "_check_work_budget", check)
    with pytest.raises(ValueError):
        importer(
            source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT, max_work_bytes=limit
        )
    assert max(observed_sizes) <= limit
    assert active.read_bytes() == original
    assert list(directory.iterdir()) == [active]


def test_supported_optional_field_boundaries_and_unicode_surrogates(tmp_path):
    _, store, _ = build(
        tmp_path,
        [
            india_product(
                "123456789012",
                product_name="n" * 2000,
                ingredients_text="i" * 16000,
                allergens_tags=["a" * 256] * 100,
            ),
            india_product(product_name="\ud800", allergens_tags=["\udfff"]),
        ],
    )
    valid = store.lookup("123456789012")
    assert valid.product is not None
    assert valid.product.name is not None
    assert valid.product.ingredients_text is not None
    assert len(valid.product.name) == 2000
    assert len(valid.product.ingredients_text) == 16000
    assert len(valid.product.allergen_tags) == 100
    invalid = store.lookup("0123456789012")
    assert invalid.product is not None
    assert invalid.product.name is None
    assert invalid.product.allergen_tags == []
    assert "product_name_invalid" in invalid.warnings
    assert "allergens_tags_invalid" in invalid.warnings


def test_insufficient_disk_space_rejects_import_before_any_staging_file(tmp_path, monkeypatch):
    importer, _ = catalogue_api()
    from app.catalogue import importer as importer_module

    _, _, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    source = tmp_path / "next.jsonl"
    write_rows(source, [india_product("123456789012")])
    usage_type = type(importer_module.shutil.disk_usage(directory))
    monkeypatch.setattr(importer_module.shutil, "disk_usage", lambda _: usage_type(1, 1, 0))
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original
    assert list(directory.iterdir()) == [active]


def test_source_is_streamed_with_bounded_reads_instead_of_whole_file_loading(tmp_path, monkeypatch):
    importer, store_type = catalogue_api()
    source = tmp_path / "stream.jsonl"
    write_rows(source, [india_product(f"{number:012d}") for number in range(250)])
    directory = tmp_path / "catalogue"
    directory.mkdir()
    original_open = Path.open

    class BoundedFile:
        def __init__(self, wrapped):
            self.wrapped = wrapped

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return self.wrapped.__exit__(*args)

        def read(self, size=-1):
            assert 0 <= size <= 512 * 1024 + 1, "unbounded input read"
            return self.wrapped.read(size)

        def readline(self, size=-1):
            assert 0 < size <= 512 * 1024 + 1, "unbounded input line"
            return self.wrapped.readline(size)

        def __getattr__(self, name):
            return getattr(self.wrapped, name)

    def bounded_open(path, *args, **kwargs):
        handle = original_open(path, *args, **kwargs)
        return BoundedFile(handle) if path == source else handle

    monkeypatch.setattr(Path, "open", bounded_open)
    manifest = importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert manifest.rows_read == 250
    assert store_type(directory).lookup("000000000249").status == "found"


def test_store_never_creates_database_for_missing_snapshot(tmp_path):
    _, store_type = catalogue_api()
    with pytest.raises((ValueError, OSError)):
        store_type(tmp_path)
    assert list(tmp_path.iterdir()) == []


def test_store_lookup_uses_read_only_query_connections_and_closes_them(tmp_path, monkeypatch):
    _, store, directory = build(tmp_path)
    from app.catalogue import store as store_module

    original_connect = sqlite3.connect

    class ReadOnlyConnection(sqlite3.Connection):
        def execute(self, statement, *args, **kwargs):
            result = super().execute(statement, *args, **kwargs)
            if statement.strip().lower().startswith("pragma query_only"):
                with pytest.raises(sqlite3.OperationalError):
                    super().execute("CREATE TABLE intrusion (value TEXT)")
            return result

    def connect(database, *args, **kwargs):
        assert "mode=ro" in database
        assert kwargs.get("uri") is True
        return original_connect(database, *args, factory=ReadOnlyConnection, **kwargs)

    monkeypatch.setattr(store_module.sqlite3, "connect", connect)
    assert store.lookup("0123456789012").status == "found"
    assert store.lookup("123456789012").status == "not_found"
    active = directory / "catalogue.sqlite3"
    active.rename(directory / "moved.sqlite3")


def test_sql_injection_barcode_is_rejected_without_any_database_mutation(tmp_path):
    _, store, directory = build(tmp_path)
    active = directory / "catalogue.sqlite3"
    original = active.read_bytes()
    with pytest.raises(ValueError):
        store.lookup("0123456789012' OR 1=1 --")
    assert active.read_bytes() == original


@pytest.mark.parametrize(
    "field,value",
    [
        ("name", "n" * 2001),
        ("brands", "b" * 2001),
        ("quantity_text", "q" * 2001),
        ("ingredients_text", "i" * 16001),
        ("allergen_tags", ["a"] * 101),
        ("trace_tags", ["t" * 257]),
        ("name", "\ud800"),
    ],
    ids=[
        "name",
        "brands",
        "quantity",
        "ingredients",
        "allergen-count",
        "trace-length",
        "surrogate",
    ],
)
def test_corrupt_stored_optional_values_are_rejected_at_lookup(tmp_path, field, value):
    _, store, directory = build(tmp_path)
    result = store.lookup("0123456789012")
    assert result.product is not None
    product = result.product.model_dump(mode="json")
    product[field] = value
    record = json.dumps({"product": product, "warnings": ["allergen_safety_not_assessed"]})
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        connection.execute("UPDATE catalogue_products SET data = ?", (record,))
    with pytest.raises(ValueError):
        store.lookup("0123456789012")


@pytest.mark.parametrize("existing", [b"not a sqlite database", None])
def test_unrecognized_or_corrupt_active_database_is_never_overwritten(tmp_path, existing):
    importer, _ = catalogue_api()
    directory = tmp_path / "catalogue"
    directory.mkdir()
    active = directory / "catalogue.sqlite3"
    if existing is None:
        with sqlite3.connect(active) as connection:
            connection.execute("CREATE TABLE user_notes (text TEXT)")
    else:
        active.write_bytes(existing)
    original = active.read_bytes()
    source = tmp_path / "input.jsonl"
    write_rows(source, [india_product()])
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert active.read_bytes() == original
    assert list(directory.iterdir()) == [active]


@pytest.mark.parametrize(
    "url",
    [
        "http://static.openfoodfacts.org/data.jsonl",
        "https://static.openfoodfacts.org.evil.test/data.jsonl",
        "https://user@static.openfoodfacts.org/data.jsonl",
        "https://static.openfoodfacts.org:444/data.jsonl",
        "https://static.openfoodfacts.org/data.jsonl#",
    ],
)
def test_unofficial_source_url_is_rejected_before_writing(tmp_path, url):
    importer, _ = catalogue_api()
    source = tmp_path / "input.jsonl"
    write_rows(source, [india_product()])
    directory = tmp_path / "catalogue"
    directory.mkdir()
    with pytest.raises(ValueError):
        importer(source, directory, source_url=url, exported_at=EXPORTED_AT)
    assert list(directory.iterdir()) == []


def test_naive_export_date_and_zero_india_rows_cannot_publish(tmp_path):
    importer, _ = catalogue_api()
    source = tmp_path / "input.jsonl"
    write_rows(source, [india_product(countries_tags=["en:france"])])
    directory = tmp_path / "catalogue"
    directory.mkdir()
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=datetime(2026, 10, 5))
    with pytest.raises(ValueError):
        importer(source, directory, source_url=SOURCE_URL, exported_at=EXPORTED_AT)
    assert list(directory.iterdir()) == []


def test_catalogue_models_are_frozen_strict_and_reject_complete_coverage(tmp_path):
    manifest, _, _ = build(tmp_path)
    from app.catalogue.models import Manifest

    with pytest.raises(ValidationError):
        manifest.coverage = "unverified"
    with pytest.raises(ValidationError):
        Manifest.model_validate({**manifest.model_dump(), "indexed_products": "1"})
    with pytest.raises(ValidationError):
        Manifest.model_validate({**manifest.model_dump(), "coverage": "complete"})
    with pytest.raises(ValidationError):
        Manifest.model_validate({**manifest.model_dump(), "indexed_at": EXPORTED_AT})


def test_cli_import_prints_only_manifest_and_artifact_size(tmp_path):
    source = tmp_path / "input.jsonl"
    write_rows(source, [india_product()])
    directory = tmp_path / "catalogue"
    directory.mkdir()
    script = Path(__file__).resolve().parents[3] / "scripts/data/import_india_catalogue.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--input",
            str(source),
            "--directory",
            str(directory),
            "--source-url",
            SOURCE_URL,
            "--exported-at",
            EXPORTED_AT.isoformat(),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    output = json.loads(result.stdout)
    assert output["manifest"]["indexed_products"] == 1
    assert output["artifact_bytes"] == (directory / "catalogue.sqlite3").stat().st_size
    assert "Synthetic oats" not in result.stdout
    assert "Oats, milk" not in result.stdout
