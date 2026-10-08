"""Read-only researched catalogue preserves source and identity boundaries."""

import gzip
import hashlib
import importlib
import importlib.util
import json
import sqlite3
from contextlib import closing
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

SCRIPT = Path(__file__).resolve().parents[3] / "scripts/build_popular_dataset.py"


def api():
    try:
        return importlib.import_module("app.research_catalogue.store")
    except ModuleNotFoundError:
        pytest.fail("The separate researched runtime catalogue is not implemented")


def candidate(name="Synthetic cola", code=None, quantity="250 mL", provider="manufacturer"):
    return {
        "source": {
            "provider": provider,
            "url": "https://example.org/india/synthetic-cola",
            "retrieved_at": "2026-10-08T04:00:00Z",
            "source_updated_at": None,
            "license": {
                "database": None,
                "contents": None,
                "images": None,
                "reuse_status": "factual_observations_only",
            },
        },
        "identity": {
            "barcode": code,
            "name": name,
            "brand": "Synthetic",
            "variant": "Original",
            "quantity": quantity,
            "market": "india",
            "match": "exact_sku" if code else "identity_unconfirmed",
            "barcode_evidence_url": "https://example.org/india/synthetic-cola" if code else None,
        },
        "sections": {"ingredients": {"text": "Water, sugar", "completeness": "complete"}},
        "nutrition": {
            "direct_tables": [
                {
                    "source": "manufacturer"
                    if provider == "manufacturer"
                    else "retailer_transcription",
                    "basis": {"amount": 100, "unit": "mL"},
                    "preparation": "as_sold",
                    "rows": [{"nutrient": "sugars", "value": 10, "unit": "g"}],
                }
            ]
        },
        "unknowns": ["Current package date unknown"],
    }


def source(tmp_path, rows=None):
    spec = importlib.util.spec_from_file_location("popular_dataset", SCRIPT)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    input_path = tmp_path / "research.json"
    input_path.write_text(json.dumps({"observations": rows or [candidate()]}), encoding="utf-8")
    directory = tmp_path / "source"
    module.build_dataset([input_path], [], directory)
    return directory


def test_source_ingredient_tokens_are_searchable_without_rewriting_observations(tmp_path):
    directory = source(tmp_path)
    output = tmp_path / 'runtime'
    api().build_research_bundle(directory, output)
    store = api().ResearchCatalogueStore(output)
    result = store.search('sugar')
    assert result.status == 'ready'
    assert result.candidates[0].identity.name == 'Synthetic cola'
    observation = store.lookup(result.candidates[0].entry_id).observation
    assert observation is not None
    assert observation.sections.ingredients.text == 'Water, sugar'


def built(tmp_path, rows=None):
    module = api()
    source_directory = source(tmp_path, rows)
    output = tmp_path / "runtime"
    receipt = module.build_research_bundle(source_directory, output)
    return module, source_directory, output, receipt, module.ResearchCatalogueStore(output)


def previous_v2(module, output):
    """Construct the published identity-only format without changing its facts."""
    receipt = json.loads((output / module.RECEIPT_FILENAME).read_text())
    receipt['format_version'] = 2
    with closing(sqlite3.connect(output / module.DATABASE_FILENAME)) as connection:
        connection.execute('PRAGMA user_version=2')
        connection.execute('DELETE FROM research_terms')
        for entry_id, data in connection.execute('SELECT entry_id,data FROM research_products'):
            identity = json.loads(data)['identity']
            tokens = module.identity_tokens(
                module._search_text(identity[key])
                for key in ('name', 'brand', 'variant', 'quantity') if identity[key] is not None
            )
            connection.executemany('INSERT INTO research_terms VALUES(?,?)',
                                   ((token, entry_id) for token in tokens))
        manifest = {key: value for key, value in receipt.items()
                    if key not in ('database_sha256', 'database_bytes')}
        connection.execute('UPDATE research_manifest SET data=?',
                           (module.canonical(manifest).decode(),))
        connection.commit()
    database = (output / module.DATABASE_FILENAME).read_bytes()
    receipt.update(database_bytes=len(database), database_sha256=hashlib.sha256(database).hexdigest())
    (output / module.RECEIPT_FILENAME).write_bytes(module.canonical(receipt) + b'\n')
    return receipt


def test_previous_search_format_upgrades_only_after_verified_backup(tmp_path):
    module, source_dir, output, _, _ = built(tmp_path)
    old = previous_v2(module, output)
    before = (output / module.DATABASE_FILENAME).read_bytes()
    with pytest.raises(ValueError):
        module.verify_research_bundle(output)
    current = module.build_research_bundle(source_dir, output)
    assert current['format_version'] == 3
    backup = output / '.research-backups' / old['database_sha256']
    assert (backup / module.DATABASE_FILENAME).read_bytes() == before
    assert module.ResearchCatalogueStore(output).search('sugar').matched_count == 1


def test_corrupt_previous_format_is_preserved_and_rejected(tmp_path):
    module, source_dir, output, _, _ = built(tmp_path)
    previous_v2(module, output)
    with (output / module.DATABASE_FILENAME).open('ab') as stream:
        stream.write(b'changed')
    before = (output / module.DATABASE_FILENAME).read_bytes()
    with pytest.raises(ValueError):
        module.build_research_bundle(source_dir, output)
    assert (output / module.DATABASE_FILENAME).read_bytes() == before
    assert not (output / '.research-build.lock').exists()


def test_rebuild_cannot_discard_newly_retained_source_records(tmp_path):
    module, _, output, _, _ = built(tmp_path, [candidate(), candidate('Synthetic extra')])
    (tmp_path / 'fewer').mkdir()
    fewer = source(tmp_path / 'fewer', [candidate()])
    before = (output / module.DATABASE_FILENAME).read_bytes()
    with pytest.raises(ValueError, match='discard or alter'):
        module.build_research_bundle(fewer, output)
    assert (output / module.DATABASE_FILENAME).read_bytes() == before


def test_brand_apostrophes_and_latin_accents_match_without_changing_sources(tmp_path):
    _, _, _, receipt, store = built(
        tmp_path,
        [
            candidate("Lay’s Classic Salted"),
            candidate("Réal Mixed Fruit"),
            candidate("सामग्री मिश्रण"),
        ],
    )
    assert receipt["format_version"] == 3
    for query in ["Lays", "Lay's", "Lay’s"]:
        result = store.search(query)
        assert result.matched_count == 1
        assert result.candidates[0].identity.name == "Lay’s Classic Salted"
    assert store.search("Real").matched_count == 1
    assert store.search("Réal").matched_count == 1
    assert store.search("सामग्री").matched_count == 1
    assert store.search("समगरी").matched_count == 0


def test_unknown_barcode_product_search_and_detail_preserve_source_observation(tmp_path):
    module, source_dir, output, receipt, store = built(tmp_path)
    assert store.status()["status"] == "ready"
    assert store.status()["observation_count"] == 1
    assert (
        receipt["database_sha256"]
        == hashlib.sha256((output / "research.sqlite3").read_bytes()).hexdigest()
    )
    result = store.search("synthetic co")
    assert result.status == "ready" and result.matched_count == 1
    item = result.candidates[0]
    assert item.identity.barcode is None
    assert item.source.provider == "manufacturer"
    assert len(item.entry_id) == 64
    detail = store.lookup(item.entry_id)
    assert detail.status == "found" and detail.observation is not None
    assert detail.observation.identity.barcode is None
    assert detail.observation.source.retrieved_at == "2026-10-08T04:00:00Z"
    assert detail.observation.source.source_updated_at is None
    raw = json.loads(gzip.decompress((source_dir / "observations.jsonl.gz").read_bytes()))
    assert detail.observation.model_dump(exclude_unset=True) == raw
    assert module.verify_research_bundle(output) == receipt
    with module.read_only_connection(output / "research.sqlite3") as connection:
        with pytest.raises(sqlite3.DatabaseError):
            connection.execute("DELETE FROM research_products")


def test_indic_search_preserves_marks_and_parameterized_sql_resists_injection(tmp_path):
    _, _, _, _, store = built(tmp_path, [candidate(name="कुरकुरे मसाला")])
    assert store.search("कुरकुरे मसा").status == "ready"
    with pytest.raises(ValueError):
        store.search("' OR 1=1 --")
    assert store.search("' OR 1=1 -- cola").status == "not_found"
    assert store.search("कुरकुरे").matched_count == 1


def test_snapshot_query_and_limit_bound_cursor_with_distinct_null_barcode_entries(tmp_path):
    _, _, _, _, store = built(tmp_path, [candidate(name=f"Synthetic cola {i}") for i in range(4)])
    first = store.search("synthetic", limit=2)
    assert first.matched_count == 4 and len(first.candidates) == 2 and first.next_cursor
    second = store.search("synthetic", limit=2, cursor=first.next_cursor)
    assert len(second.candidates) == 2 and second.next_cursor is None
    assert not {c.entry_id for c in first.candidates} & {c.entry_id for c in second.candidates}
    for query, limit, cursor in [
        ("cola", 2, first.next_cursor),
        ("synthetic", 1, first.next_cursor),
        ("synthetic", 2, "malformed"),
    ]:
        with pytest.raises(ValueError, match="cursor"):
            store.search(query, limit=limit, cursor=cursor)
    with pytest.raises(ValueError):
        store.search("synthetic", limit=21)


def test_exact_barcode_index_excludes_unconfirmed_and_conflicting_identity_groups(tmp_path):
    first = candidate(code="8900000000001")
    conflict = candidate(code="8900000000001", quantity="500 mL")
    unconfirmed = candidate(code="8900000000002")
    unconfirmed["identity"]["match"] = "identity_unconfirmed"
    exact = candidate(code="8900000000003")
    _, _, _, _, store = built(tmp_path, [first, conflict, unconfirmed, exact])
    assert store.by_barcode("8900000000001").status == "not_found"
    assert store.by_barcode("8900000000002").status == "not_found"
    result = store.by_barcode("8900000000003")
    assert result.status == "found" and len(result.candidates) == 1
    conflict_search = store.search("synthetic")
    conflicting = [c for c in conflict_search.candidates if c.identity.barcode == "8900000000001"]
    assert len(conflicting) == 2
    assert all("identity.quantity" in c.conflict_fields for c in conflicting)


def test_mixed_manufacturer_and_retailer_records_never_merge_tables_or_licenses(tmp_path):
    manufacturer = candidate()
    retailer = candidate(provider="retailer")
    retailer["nutrition"]["direct_tables"][0]["rows"][0]["value"] = 12
    _, _, _, _, store = built(tmp_path, [manufacturer, retailer])
    result = store.search("cola")
    assert result.matched_count == 2
    details = [store.lookup(c.entry_id).observation for c in result.candidates]
    assert {d.source.provider for d in details if d} == {"manufacturer", "retailer"}
    assert {d.nutrition.direct_tables[0].rows[0].value for d in details if d} == {10, 12}
    assert {d.nutrition.direct_tables[0].source for d in details if d} == {
        "manufacturer",
        "retailer_transcription",
    }


@pytest.mark.parametrize("target", ["research.sqlite3", "receipt.json"])
def test_changed_runtime_database_or_receipt_is_rejected(tmp_path, target):
    module, _, output, _, _ = built(tmp_path)
    path = output / target
    if target.endswith(".sqlite3"):
        with sqlite3.connect(path) as connection:
            connection.execute("DELETE FROM research_products")
    else:
        data = json.loads(path.read_text(encoding="utf-8"))
        data["observation_count"] = 99
        path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValueError):
        module.ResearchCatalogueStore(output)


def test_source_hash_or_immutable_observation_tampering_rejects_build(tmp_path):
    module = api()
    directory = source(tmp_path)
    packed = directory / "observations.jsonl.gz"
    observation = json.loads(gzip.decompress(packed.read_bytes()))
    observation["sections"]["ingredients"]["text"] = "Changed ingredients"
    decoded = (
        json.dumps(observation, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
        + b"\n"
    )
    compressed = gzip.compress(decoded, mtime=0)
    packed.write_bytes(compressed)
    manifest_path = directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.update(
        compressed_sha256=hashlib.sha256(compressed).hexdigest(),
        compressed_bytes=len(compressed),
        decoded_sha256=hashlib.sha256(decoded).hexdigest(),
        decoded_bytes=len(decoded),
    )
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(ValueError, match="observation"):
        module.build_research_bundle(directory, tmp_path / "out")
    assert not (tmp_path / "out/research.sqlite3").exists()


def test_source_and_output_never_share_directory_and_bulk_source_stays_unchanged(tmp_path):
    module = api()
    directory = source(tmp_path)
    before = {path.name: path.read_bytes() for path in directory.iterdir()}
    with pytest.raises(ValueError):
        module.build_research_bundle(directory, directory)
    assert before == {path.name: path.read_bytes() for path in directory.iterdir()}


def test_router_search_detail_not_found_invalid_and_unavailable_statuses(tmp_path):
    _, _, _, _, store = built(tmp_path)
    router = importlib.import_module("app.research_catalogue.router")
    application = FastAPI()
    application.include_router(router.build_router(lambda _: store))
    with TestClient(application) as client:
        search = client.get("/v1/researched/products/search", params={"q": "synthetic"})
        assert search.status_code == 200 and search.headers["cache-control"] == "no-store"
        assert search.json()["schema_version"] == "1"
        assert search.json()["search_version"] == "research-search-v1"
        assert search.json()["next_cursor"] is None
        entry_id = search.json()["candidates"][0]["entry_id"]
        detail = client.get("/v1/researched/products/" + entry_id)
        assert detail.json()["schema_version"] == "1"
        assert (
            detail.status_code == 200
            and detail.json()["observation"]["identity"]["barcode"] is None
        )
        assert client.get("/v1/researched/products/" + "0" * 64).status_code == 404
        assert client.get("/v1/researched/products/not-a-hash").status_code == 422
        assert (
            client.get(
                "/v1/researched/products/search", params={"q": "synthetic", "cursor": "bad"}
            ).status_code
            == 422
        )
    offline = FastAPI()
    offline.include_router(router.build_router(lambda _: None))
    with TestClient(offline) as client:
        assert client.get("/v1/researched/products/search", params={"q": "cola"}).status_code == 503
        assert client.get("/v1/researched/products/" + "0" * 64).status_code == 503


def test_active_database_replacement_cannot_silently_change_a_store_snapshot(tmp_path):
    module, _, output, _, store = built(tmp_path)
    path = output / "research.sqlite3"
    with sqlite3.connect(path) as connection:
        data = json.loads(connection.execute("SELECT data FROM research_products").fetchone()[0])
        data["identity"]["name"] = "Altered source"
        connection.execute("UPDATE research_products SET data=?", (json.dumps(data),))
    with pytest.raises(ValueError):
        store.search("synthetic")
    with pytest.raises(ValueError):
        module.verify_research_bundle(output)


def rehash_receipt(output):
    path = output / "receipt.json"
    receipt = json.loads(path.read_text(encoding="utf-8"))
    database = (output / "research.sqlite3").read_bytes()
    receipt["database_sha256"] = hashlib.sha256(database).hexdigest()
    receipt["database_bytes"] = len(database)
    path.write_text(json.dumps(receipt), encoding="utf-8")


def test_rehashed_database_cannot_erase_source_conflicts_to_enable_barcode_linking(tmp_path):
    module, _, output, _, _ = built(
        tmp_path,
        [candidate(code="8900000000001"), candidate(code="8900000000001", quantity="500 mL")],
    )
    with sqlite3.connect(output / "research.sqlite3") as connection:
        connection.execute(
            "UPDATE research_products SET conflict_fields='[]',eligible_barcode=barcode"
        )
    rehash_receipt(output)
    with pytest.raises(ValueError, match="conflict"):
        module.verify_research_bundle(output)


def test_rehashed_database_cannot_add_untracked_private_tables(tmp_path):
    module, _, output, _, _ = built(tmp_path)
    with sqlite3.connect(output / "research.sqlite3") as connection:
        connection.execute("CREATE TABLE untracked_private_data (value TEXT)")
    rehash_receipt(output)
    with pytest.raises(ValueError, match="schema"):
        module.verify_research_bundle(output)


def test_bad_query_never_becomes_a_server_error_and_barcode_route_is_exact_only(tmp_path):
    _, _, _, _, store = built(tmp_path)
    router = importlib.import_module("app.research_catalogue.router")
    application = FastAPI()
    application.include_router(router.build_router(lambda _: store))
    with TestClient(application) as client:
        for query in ["?", "x", "\u0000", "one two three four five six seven eight nine"]:
            assert (
                client.get("/v1/researched/products/search", params={"q": query}).status_code == 422
            )
        result = client.get("/v1/researched/products/by-barcode/8900000000001")
        assert result.status_code == 404 and result.json()["candidates"] == []
        assert client.get("/v1/researched/products/by-barcode/not-a-code").status_code == 422


def test_cursor_from_another_source_snapshot_is_rejected(tmp_path):
    _, _, _, _, first = built(
        tmp_path, [candidate(name="Synthetic cola 1"), candidate(name="Synthetic cola 2")]
    )
    cursor = first.search("synthetic", limit=1).next_cursor
    second_directory = tmp_path / "second"
    second_directory.mkdir()
    _, _, _, _, second = built(
        second_directory, [candidate(name="Synthetic cola 3"), candidate(name="Synthetic cola 4")]
    )
    with pytest.raises(ValueError, match="cursor"):
        second.search("synthetic", limit=1, cursor=cursor)


def test_rehashed_database_cannot_replace_an_observation_under_original_dataset_hash(tmp_path):
    module, _, output, _, _ = built(tmp_path)
    with sqlite3.connect(output / "research.sqlite3") as connection:
        observation = json.loads(
            connection.execute("SELECT data FROM research_products").fetchone()[0]
        )
        old_id = observation.pop("observation_id")
        observation["sections"]["ingredients"]["text"] = (
            "Different independently researched ingredients"
        )
        new_id = hashlib.sha256(
            json.dumps(
                observation, ensure_ascii=False, sort_keys=True, separators=(",", ":")
            ).encode()
        ).hexdigest()
        observation["observation_id"] = new_id
        connection.execute(
            "UPDATE research_products SET entry_id=?,data=?",
            (
                new_id,
                json.dumps(observation, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
            ),
        )
        connection.execute(
            "UPDATE research_terms SET entry_id=? WHERE entry_id=?", (new_id, old_id)
        )
    rehash_receipt(output)
    with pytest.raises(ValueError, match="dataset"):
        module.verify_research_bundle(output)


def test_broad_query_returns_refinement_before_exposing_more_than_one_thousand_matches(tmp_path):
    _, _, _, _, store = built(
        tmp_path, [candidate(name=f"Synthetic cola {index}") for index in range(1001)]
    )
    result = store.search("synthetic")
    assert result.status == "refine_query"
    assert result.matched_count is None and result.candidates == [] and result.next_cursor is None
