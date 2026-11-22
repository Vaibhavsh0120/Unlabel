import copy
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from scripts.data.research_batch import (  # noqa: E402
    BASE,
    merge_records,
    prepare,
    product_key,
    snapshot,
)


def record():
    return next(x for x in snapshot(BASE)[1] if x["identity"]["barcode"])


def updated(original):
    raw = copy.deepcopy(original)
    raw.pop("observation_id")
    raw["sections"]["ingredients"] = {"text": "Synthetic reviewed replacement", "completeness": "complete"}
    raw["raw_projection"] = None
    return raw


def test_replaces_current_facts_without_merging_previous_ingredients():
    original = record()
    result, plan = merge_records([original], [{"observation": updated(original)}])
    assert len(result) == 1
    assert result[0]["sections"]["ingredients"]["text"] == "Synthetic reviewed replacement"
    assert result[0]["observation_id"] != original["observation_id"]
    assert plan[0]["action"] == "replace"
    assert "sections.ingredients.text" in plan[0]["changed_fields"] or "sections.ingredients" in plan[0]["changed_fields"]
    again, changes = merge_records(result, [{"observation": updated(original)}])
    assert again == result and changes[0]["action"] == "unchanged"


def test_duplicate_products_and_wrong_variant_are_rejected():
    original = record()
    incoming = {"observation": updated(original)}
    with pytest.raises(ValueError, match="Duplicate product"):
        merge_records([original], [incoming, incoming])
    incoming["observation"]["identity"]["quantity"] = "99999 g"
    with pytest.raises(ValueError, match="identity differs"):
        merge_records([original], [incoming])


def test_explicit_exact_id_can_correct_identity_without_losing_unrelated_products():
    original = record()
    incoming = updated(original)
    incoming["identity"]["quantity"] = "99999 g"
    result, plan = merge_records([original], [{"observation": incoming, "replace_entry_ids": [original["observation_id"]]}])
    assert len(result) == 1 and result[0]["identity"]["quantity"] == "99999 g"
    assert plan[0]["previous_entry_ids"] == [original["observation_id"]]


def test_missing_identity_cannot_replace_by_fuzzy_name():
    incoming = updated(record())
    incoming["identity"].update(barcode=None, match="identity_unconfirmed", barcode_evidence_url=None, variant=None)
    with pytest.raises(ValueError, match="Without a barcode"):
        product_key(incoming)


def test_prepared_snapshot_is_hashed_replayable_and_does_not_mutate_base(tmp_path):
    before = (BASE / "observations.jsonl.gz").read_bytes()
    original = record()
    batch = {"schema_version": "1", "products": [{"observation": updated(original)}]}
    directory, receipt = prepare(batch, BASE, tmp_path)
    manifest, observations = snapshot(directory)
    assert manifest["decoded_sha256"] == receipt["snapshot_sha256"]
    assert any(x["sections"]["ingredients"] and x["sections"]["ingredients"]["text"] == "Synthetic reviewed replacement" for x in observations)
    assert json.loads((directory / "request.json").read_text()) == batch
    assert prepare(batch, BASE, tmp_path) == (directory, receipt)
    assert (BASE / "observations.jsonl.gz").read_bytes() == before
