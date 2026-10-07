import gzip
import hashlib
import importlib.util
import json
import socket
import sqlite3
from contextlib import closing
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]


def module(name, monkeypatch):
    monkeypatch.syspath_prepend(str(ROOT / "scripts"))
    spec = importlib.util.spec_from_file_location(f"workspace_{name}", ROOT / f"scripts/{name}.py")
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


@pytest.fixture
def clone(tmp_path):
    (tmp_path / "backend").mkdir()
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/workspace.json").write_bytes(
        (ROOT / "scripts/workspace.json").read_bytes()
    )
    (tmp_path / "backend/.env.example").write_text("GEMINI_API_KEY=\n")
    (tmp_path / "backend/.env.age").write_bytes(b"synthetic ciphertext")
    return tmp_path


def test_setup_preserves_existing_env_without_prompt(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    (clone / "backend/.env").write_bytes(b"existing private values")
    monkeypatch.setattr("builtins.input", lambda _: pytest.fail("Existing env must not prompt"))
    assert setup.ensure_env(clone, None, False) == "existing"
    assert (clone / "backend/.env").read_bytes() == b"existing private values"


def test_noninteractive_setup_uses_example_without_key(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    monkeypatch.delenv("AGE_IDENTITY_FILE", raising=False)
    assert setup.ensure_env(clone, None, True) == "example"
    assert (clone / "backend/.env").read_bytes() == (clone / "backend/.env.example").read_bytes()


def test_prompt_file_and_hidden_paste_paths(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    monkeypatch.delenv("AGE_IDENTITY_FILE", raising=False)
    monkeypatch.setattr(setup.sys.stdin, "isatty", lambda: True)
    responses = iter(["1", '"C:/outside/key.txt"'])
    monkeypatch.setattr("builtins.input", lambda _: next(responses))
    calls = []
    monkeypatch.setattr(setup, "decrypt_env", lambda root, key: calls.append((root, key)))
    assert setup.ensure_env(clone, None, False) == "decrypted"
    assert calls == [(clone, Path("C:/outside/key.txt"))]
    monkeypatch.setattr("builtins.input", lambda _: "2")
    monkeypatch.setattr(setup, "prompt_identity", lambda: "private fixture")
    monkeypatch.setattr(setup, "decrypt_env_text", lambda root, key: calls.append((root, key)))
    assert setup.ensure_env(clone, None, False) == "decrypted"
    assert calls[-1] == (clone, "private fixture")


def test_setup_refuses_implicit_key_prompt_in_non_terminal(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    monkeypatch.delenv("AGE_IDENTITY_FILE", raising=False)
    monkeypatch.setattr(setup.sys.stdin, "isatty", lambda: False)
    with pytest.raises(ValueError, match="No interactive terminal"):
        setup.ensure_env(clone, None, False)
    assert not (clone / "backend/.env").exists()


def source_bundle(clone, *, source_format="off_jsonl"):
    directory = clone / "data/catalogue"
    directory.mkdir(parents=True)
    product = {"code": "8900000000001", "countries_tags": ["en:india"]}
    if source_format == "off_jsonl":
        product["nutrition"] = {
            "input_sets": [
                {
                    "source": "packaging",
                    "preparation": "as_sold",
                    "per": "100g",
                    "per_quantity": 100,
                    "per_unit": "g",
                    "nutrients": {"sugars": {"value": 0, "unit": "g"}},
                }
            ]
        }
    decoded = (json.dumps(product) + "\n").encode()
    compressed = gzip.compress(decoded, mtime=0)
    (directory / "india-products.jsonl.gz").write_bytes(compressed)
    metadata = {
        "schema_version": "1",
        "source_file": "india-products.jsonl.gz",
        "source_format": source_format,
        "coverage": "unverified",
        "source_url": (
            "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"
            if source_format == "off_jsonl"
            else "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz"
        ),
        "exported_at": "2026-10-05T12:19:34Z",
        "compressed_bytes": len(compressed),
        "compressed_sha256": hashlib.sha256(compressed).hexdigest(),
        "decoded_bytes": len(decoded),
        "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
        "expected_input_rows": 1,
        "indexed_products": 1,
    }
    (directory / "bundle.json").write_text(json.dumps(metadata))
    return directory, metadata


@pytest.mark.parametrize("layer", ["compressed", "decoded"])
def test_setup_progress_reports_failed_hash_without_verification(clone, monkeypatch, capsys, layer):
    setup = module("setup", monkeypatch)
    directory, metadata = source_bundle(clone)
    metadata[f"{layer}_sha256"] = "0" * 64
    (directory / "bundle.json").write_text(json.dumps(metadata))
    with pytest.raises(ValueError, match="checksum/size mismatch"):
        setup.verified_bundle(clone)
    output = capsys.readouterr().err
    label = f"Validate {layer} catalogue"
    assert f"Stopped: {label}" in output
    assert f"Verified: {label}" not in output
    assert not (clone / "backend/storage/runtime/india/catalogue.sqlite3").exists()


@pytest.mark.parametrize("source_format", ["off_jsonl", "off_csv_projection"])
def test_setup_rebuilds_then_reuses_index_and_retains_different_valid_index(
    clone, monkeypatch, source_format
):
    setup = module("setup", monkeypatch)
    directory, _ = source_bundle(clone, source_format=source_format)
    assert setup.prepare_catalogue(clone) == "built"
    active = clone / "backend/storage/runtime/india/catalogue.sqlite3"
    original = active.read_bytes()
    assert setup.prepare_catalogue(clone) == "reused"
    assert active.read_bytes() == original
    from app.catalogue.store import CatalogueStore

    assert CatalogueStore(active.parent).supports_facts == (source_format == "off_jsonl")
    metadata = json.loads((directory / "bundle.json").read_text())
    metadata["exported_at"] = "2026-10-06T12:19:34Z"
    (directory / "bundle.json").write_text(json.dumps(metadata))
    assert setup.prepare_catalogue(clone) == "preserved"
    assert active.read_bytes() == original


def test_setup_migrates_same_source_identity_only_jsonl_index_with_explicit_replacement(
    clone, monkeypatch
):
    from app.catalogue.store import CatalogueStore

    setup = module("setup", monkeypatch)
    _, metadata = source_bundle(clone)
    assert setup.prepare_catalogue(clone) == "built"
    directory = clone / "backend/storage/runtime/india"
    active = directory / "catalogue.sqlite3"
    # An older importer can legitimately have indexed the same JSONL identities
    # before the optional facts table was implemented.
    with closing(sqlite3.connect(active)) as connection:
        connection.execute("DROP TABLE catalogue_facts")
        connection.commit()
    old_store = CatalogueStore(directory)
    assert old_store.manifest.source_sha256 == metadata["decoded_sha256"]
    assert old_store.supports_facts is False
    previous = active.read_bytes()
    assert setup.prepare_catalogue(clone) == "preserved"
    assert active.read_bytes() == previous
    assert setup.prepare_catalogue(clone, replace=True) == "built"
    restored = CatalogueStore(directory)
    assert restored.supports_facts is True
    assert restored.manifest.source_sha256 == metadata["decoded_sha256"]
    facts = restored.lookup_facts("8900000000001")
    assert facts.status == "found"
    assert facts.details is not None
    assert facts.details.nutrition.snapshot.tables[0].nutrients["sugars"].value == 0
    assert setup.prepare_catalogue(clone, replace=True) == "reused"


def test_setup_upgrades_same_source_missing_discovery_without_replacing_different_data(
    clone, monkeypatch
):
    from app.catalogue.store import CatalogueStore

    setup = module("setup", monkeypatch)
    _, metadata = source_bundle(clone)
    assert setup.prepare_catalogue(clone) == "built"
    directory = clone / "backend/storage/runtime/india"
    with closing(sqlite3.connect(directory / "catalogue.sqlite3")) as connection:
        for table in (
            "catalogue_search_terms",
            "catalogue_search_prefixes",
            "catalogue_search_counts",
            "catalogue_search_format",
        ):
            connection.execute(f"DROP TABLE {table}")
        connection.commit()
    old = CatalogueStore(directory)
    assert old.supports_facts is True and old.supports_search is False
    assert setup.prepare_catalogue(clone) == "built"
    restored = CatalogueStore(directory)
    assert restored.manifest.source_sha256 == metadata["decoded_sha256"]
    assert restored.supports_search is True
    assert setup.prepare_catalogue(clone) == "reused"


def test_setup_rejects_tampered_bundle_before_replacing_index(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    directory, _ = source_bundle(clone)
    assert setup.prepare_catalogue(clone) == "built"
    active = clone / "backend/storage/runtime/india/catalogue.sqlite3"
    previous = active.read_bytes()
    with (directory / "india-products.jsonl.gz").open("ab") as stream:
        stream.write(b"damage")
    with pytest.raises(ValueError, match="compressed checksum"):
        setup.prepare_catalogue(clone, replace=True)
    assert active.read_bytes() == previous


def test_setup_wrong_expected_counts_preserve_active_index(clone, monkeypatch):
    setup = module("setup", monkeypatch)
    directory, metadata = source_bundle(clone)
    assert setup.prepare_catalogue(clone) == "built"
    active = clone / "backend/storage/runtime/india/catalogue.sqlite3"
    previous = active.read_bytes()
    metadata["indexed_products"] = 2
    (directory / "bundle.json").write_text(json.dumps(metadata))
    with pytest.raises(ValueError, match="expected bundle"):
        setup.prepare_catalogue(clone, replace=True)
    assert active.read_bytes() == previous


def test_runner_rejects_occupied_port(monkeypatch):
    runner = module("run_local", monkeypatch)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        with pytest.raises(ValueError, match="already in use"):
            runner.check_port_available(listener.getsockname()[1])


@pytest.mark.parametrize(
    "url",
    [
        "http://user:private@host",
        "https://host/?token=private",
        "javascript:private",
        "https://host&echo",
        "https://host%PATH%",
        'https://host"quoted',
        "https://host|echo",
        "https://host^echo",
    ],
)
def test_backend_origin_rejects_credentials_and_non_origin_urls(monkeypatch, url):
    workspace = module("_workspace", monkeypatch)
    with pytest.raises(ValueError, match="without credentials"):
        workspace.public_origin(url)


def test_local_frontend_metadata_reads_canonical_version(tmp_path, monkeypatch):
    workspace = module("_workspace", monkeypatch)
    (tmp_path / "frontend").mkdir()
    pubspec = tmp_path / "frontend/pubspec.yaml"
    pubspec.write_text("name: unlabel\nversion: 0.1.0+2\n")
    assert workspace.frontend_version(tmp_path) == ("0.1.0", "2")
    pubspec.write_text("version: 0.1.0+0\n")
    with pytest.raises(ValueError, match="positive build"):
        workspace.frontend_version(tmp_path)
