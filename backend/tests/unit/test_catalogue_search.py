import base64
import json
import sqlite3
from contextlib import closing
from datetime import UTC, datetime

import pytest

from app.catalogue.importer import build_catalogue
from app.catalogue.store import CatalogueStore, read_only_connection

SOURCE = "https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz"


def build(tmp_path, products):
    directory = tmp_path / "catalogue"
    directory.mkdir(exist_ok=True)
    source = tmp_path / "products.jsonl"
    source.write_text(
        "".join(
            json.dumps({"code": f"89000000{index:05}", "countries_tags": ["en:india"], **row})
            + "\n"
            for index, row in enumerate(products)
        ),
        encoding="utf-8",
    )
    manifest = build_catalogue(
        source, directory, source_url=SOURCE, exported_at=datetime(2026, 10, 6, tzinfo=UTC)
    )
    return CatalogueStore(directory), manifest, directory


def test_discovery_indexes_identity_tokens_and_returns_original_provenance(tmp_path):
    store, manifest, _ = build(
        tmp_path,
        [
            {"product_name": "Whole Grain Oats", "brands": "True Elements", "quantity": "300 g"},
            {"product_name": "Chocolate Granola", "brands": "Synthetic Brand"},
        ],
    )
    assert store.supports_search is True
    result = store.search("TRUE Oa")
    assert result.status == "ready"
    assert result.normalized_query == "true oa"
    assert result.matched_count == 1 and result.ambiguous is False
    assert result.manifest == manifest
    candidate = result.candidates[0]
    assert candidate.identity.name == "Whole Grain Oats"
    assert candidate.identity.quantity_text == "300 g"
    assert candidate.source_id == f"off:{manifest.source_sha256}:8900000000000"
    assert "insights" not in result.model_dump_json()
    assert "ingredients_text" not in result.model_dump_json()
    assert "candidate_requires_identity_confirmation" in candidate.warnings
    assert "community_record_not_package_verified" in candidate.warnings
    assert store.search("gra").matched_count == 2
    assert store.search("gra oa").status == "not_found"  # Non-final terms must be exact.
    assert store.search("whole grain oa").status == "ready"


@pytest.mark.parametrize(
    "query", ["गेहूँ", "गेहू", "मैदा", "दूध", "दू", "STRAẞE", "ＳＴＲＡＳＳＥ", "क़ि", "क़ि"]
)
def test_unicode_casefold_nfkc_and_hindi_combining_marks_remain_searchable(tmp_path, query):
    store, _, _ = build(tmp_path, [{"product_name": "गेहूँ मैदा दूध Straße क़िला"}])
    assert store.search(query).status == "ready"


@pytest.mark.parametrize(
    "query",
    [
        "",
        " ",
        "a",
        "\u0301\u0302",
        "a" * 65,
        "ab " * 9,
        "x" * 129,
        "milk\x00",
        "milk\n",
        "\ud800",
        "milk\u202e",
    ],
)
def test_query_rejects_unbounded_or_non_text_search_input(tmp_path, query):
    store, _, _ = build(tmp_path, [{"product_name": "Milk"}])
    with pytest.raises(ValueError):
        store.search(query)


def test_search_sql_metacharacters_are_data_and_do_not_change_database(tmp_path):
    store, _, directory = build(tmp_path, [{"product_name": "Whole oats"}])
    before = (directory / "catalogue.sqlite3").read_bytes()
    assert store.search("oats' OR true; DROP TABLE catalogue_products;--").status == "not_found"
    assert store.lookup("8900000000000").status == "found"
    assert (directory / "catalogue.sqlite3").read_bytes() == before


def test_stable_bounded_pagination_and_cursor_query_options_snapshot_binding(tmp_path):
    store, _, directory = build(tmp_path, [{"product_name": "Whole oats"} for _ in range(7)])
    first = store.search("oa", limit=3)
    assert first.matched_count == 7 and first.ambiguous is True
    assert first.next_cursor is not None
    second = store.search("oa", limit=3, cursor=first.next_cursor)
    third = store.search("oa", limit=3, cursor=second.next_cursor)
    assert [len(page.candidates) for page in (first, second, third)] == [3, 3, 1]
    assert third.next_cursor is None
    codes = [item.identity.barcode for page in (first, second, third) for item in page.candidates]
    assert codes == sorted(set(codes))
    for query, limit in [("whole", 3), ("oa", 4)]:
        with pytest.raises(ValueError):
            store.search(query, limit=limit, cursor=first.next_cursor)
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        raw = json.loads(connection.execute("SELECT data FROM catalogue_manifest").fetchone()[0])
        raw["snapshot_id"] = "replacement"
        connection.execute("UPDATE catalogue_manifest SET data=?", (json.dumps(raw),))
    with pytest.raises(ValueError):
        store.search("oa", limit=3, cursor=first.next_cursor)


@pytest.mark.parametrize("limit", [0, 21, True, 1.5, "2"])
def test_invalid_result_limit_is_rejected(tmp_path, limit):
    store, _, _ = build(tmp_path, [{"product_name": "Whole oats"}])
    with pytest.raises(ValueError):
        store.search("oa", limit=limit)


@pytest.mark.parametrize(
    "cursor", ["", "*" * 64, "a" * 1025, base64.urlsafe_b64encode(b"[]").decode()]
)
def test_invalid_cursor_is_rejected(tmp_path, cursor):
    store, _, _ = build(tmp_path, [{"product_name": "Whole oats"}])
    with pytest.raises(ValueError):
        store.search("oa", cursor=cursor)


def test_broad_queries_require_refinement_and_selective_exact_anchor_is_bounded(tmp_path):
    rows = [{"product_name": "Whole oats"} for _ in range(1001)]
    rows[-1]["brands"] = "Selective"
    store, _, _ = build(tmp_path, rows)
    broad = store.search("oa")
    assert broad.status == "refine_query"
    assert broad.matched_count is None and broad.ambiguous is None
    assert broad.candidates == [] and broad.next_cursor is None
    selective = store.search("selective oa")
    assert selective.status == "ready" and selective.matched_count == 1
    assert store.search("missing oa").status == "not_found"


def test_maximum_bounded_anchor_and_query_terms_complete_within_sql_budget(tmp_path):
    name = "Alpha Beta Gamma Delta Epsilon Zeta Eta Theta"
    store, _, _ = build(tmp_path, [{"product_name": name} for _ in range(1000)])
    result = store.search("alpha beta gamma delta epsilon zeta eta th", limit=20)
    assert result.status == "ready"
    assert result.matched_count == 1000 and len(result.candidates) == 20


def test_missing_runtime_count_is_unavailable_instead_of_false_miss(tmp_path):
    store, _, directory = build(tmp_path, [{"product_name": "Whole oats"}])
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        connection.execute("DELETE FROM catalogue_search_counts WHERE kind='prefix' AND term='oa'")
    assert store.search("oa").status == "unavailable"


@pytest.mark.parametrize("damage", ["absent", "partial", "format", "counts", "schema"])
def test_optional_or_malformed_search_does_not_disable_legacy_exact_facts(tmp_path, damage):
    store, _, directory = build(tmp_path, [{"product_name": "Whole oats"}])
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        if damage in {"absent", "partial"}:
            tables = [
                "catalogue_search_format",
                "catalogue_search_terms",
                "catalogue_search_prefixes",
                "catalogue_search_counts",
            ]
            for table in tables if damage == "absent" else tables[:1]:
                connection.execute(f"DROP TABLE {table}")
        elif damage == "format":
            connection.execute("UPDATE catalogue_search_format SET version='future'")
        elif damage == "counts":
            connection.execute("UPDATE catalogue_search_counts SET count=count+1")
        else:
            connection.execute("DROP TABLE catalogue_search_prefixes")
            connection.execute("CREATE TABLE catalogue_search_prefixes(prefix TEXT, barcode TEXT)")
    reopened = CatalogueStore(directory)
    assert reopened.supports_search is False
    assert reopened.lookup("8900000000000").status == "found"
    assert reopened.lookup_facts("8900000000000").status == "found"
    assert reopened.search("oa").status == "unavailable"


def test_corrupt_runtime_counts_cannot_force_unbounded_anchor_scans(tmp_path):
    store, _, directory = build(tmp_path, [{"product_name": "Whole oats"} for _ in range(1001)])
    with sqlite3.connect(directory / "catalogue.sqlite3") as connection:
        connection.execute(
            "UPDATE catalogue_search_counts SET count=1 WHERE kind='prefix' AND term='oa'"
        )
    result = store.search("oa")
    assert result.status == "unavailable"
    assert result.candidates == []


def test_search_uses_read_only_transaction_and_preserves_old_manifest_version(tmp_path):
    store, manifest, directory = build(tmp_path, [{"product_name": "Whole oats"}])
    before = (directory / "catalogue.sqlite3").read_bytes()
    assert store.search("oa").manifest == manifest
    with read_only_connection(directory / "catalogue.sqlite3") as connection:
        assert connection.execute("PRAGMA user_version").fetchone()[0] == 1
        with pytest.raises(sqlite3.OperationalError):
            connection.execute("DELETE FROM catalogue_search_terms")
    assert manifest.schema_version == "1"
    assert (directory / "catalogue.sqlite3").read_bytes() == before


def test_explicit_snapshot_replacement_rechecks_optional_index_without_restart(tmp_path):
    store, first, directory = build(tmp_path, [{"product_name": "Whole oats"}])
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
    assert old.supports_search is False
    assert old.search("oa").status == "unavailable"
    _, second, _ = build(tmp_path, [{"product_name": "Whole oats"}])
    assert first.snapshot_id != second.snapshot_id
    assert old.search("oa").status == "ready"
    assert old.supports_search is True
    assert old.search("oa").manifest == second
    assert store.search("oa").manifest == second
