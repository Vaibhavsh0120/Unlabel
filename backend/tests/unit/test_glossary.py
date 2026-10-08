import hashlib
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from app.reports.glossary import GlossaryResponse, GlossaryStore


def projection():
    current = Path(__file__).resolve().parents[2] / "app/reports/glossary-v2.json"
    return json.loads(current.read_text(encoding="utf-8"))


def write_projection(directory, value):
    (directory / "glossary-v2.json").write_text(json.dumps(value), encoding="utf-8")


def test_glossary_is_bounded_reviewed_bilingual_function_content():
    store = GlossaryStore()
    assert store.version == "ingredients-2026-10-08.1"
    assert len(store.entries()) == 6
    assert len(store.sources()) == 6
    assert store.artifact.entry_count == 6
    assert len(store.artifact.sha256) == 64
    assert all(entry.name_hi and entry.function_hi for entry in store.entries())
    assert all(source.scope == "name_and_technological_function_only" for source in store.sources())


@pytest.mark.parametrize(
    "text,identifier,code,source",
    [
        ("Guar gum", "guar_gum", "412", "codex-gsfa-guar-gum"),
        ("ग्वार गम", "guar_gum", "412", "codex-gsfa-guar-gum"),
        ("INS 412", "guar_gum", "412", "codex-gsfa-guar-gum"),
        ("Sodium benzoate", "sodium_benzoate", "211", "codex-gsfa-sodium-benzoate"),
        ("सोडियम बेंजोएट", "sodium_benzoate", "211", "codex-gsfa-sodium-benzoate"),
        ("E211", "sodium_benzoate", "211", "codex-gsfa-sodium-benzoate"),
        ("Potassium sorbate", "potassium_sorbate", "202", "codex-gsfa-potassium-sorbate"),
        ("पोटैशियम सोर्बेट", "potassium_sorbate", "202", "codex-gsfa-potassium-sorbate"),
        ("INS-202", "potassium_sorbate", "202", "codex-gsfa-potassium-sorbate"),
    ],
)
def test_expanded_reviewed_functions_keep_exact_identity_code_source_and_span(
    text, identifier, code, source
):
    matches = GlossaryStore().match("Oats, " + text + ", unknown spice")
    assert len(matches) == 1
    match = matches[0]
    assert match.entry.entry_id == identifier
    assert match.entry.ins_codes == [code]
    assert match.entry.source_ids == [source]
    assert match.matched_text == text
    assert match.start == 6 and match.end == 6 + len(text)
    assert match.entry.name_hi and match.entry.function_hi


def test_known_but_wrong_source_cannot_support_another_ingredient(tmp_path):
    value = projection()
    value["entries"][0]["source_ids"] = ["codex-gsfa-citric-acid"]
    write_projection(tmp_path, value)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


@pytest.mark.parametrize("alias", ["citric acid", "CITRIC ACID", "E330", "INS 330"])
def test_one_reviewed_entry_cannot_take_another_entries_alias_or_code(tmp_path, alias):
    value = projection()
    value["entries"][0]["aliases"].append(alias)
    write_projection(tmp_path, value)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


@pytest.mark.parametrize("field", ["reviewed_on", "url", "ins_codes"])
def test_changed_review_date_url_or_additive_subtype_is_rejected(tmp_path, field):
    value = projection()
    if field == "reviewed_on":
        future = (datetime.now(UTC).date() + timedelta(days=1)).isoformat()
        value["reviewed_on"] = future
        for source in value["sources"]:
            source["reviewed_on"] = future
    elif field == "url":
        value["sources"][0]["url"] = "https://example.invalid/unreviewed"
    else:
        value["entries"][0]["ins_codes"] = ["322(ii)"]
    write_projection(tmp_path, value)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


@pytest.mark.parametrize("field", ["name_en", "function_en", "function_hi"])
def test_unreviewed_projection_content_cannot_keep_a_reviewed_version(tmp_path, field):
    value = projection()
    value["entries"][0][field] = "Unreviewed synthetic explanation"
    write_projection(tmp_path, value)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


@pytest.mark.parametrize(
    "text,identifier",
    [
        ("Emulsifier (INS 322(i))", "lecithin"),
        ("citric acid, salt", "citric_acid"),
        ("Acidity regulator: INS-330", "citric_acid"),
        ("E 415", "xanthan_gum"),
        ("ज़ैंथन गम", "xanthan_gum"),
        ("लेसिथिन", "lecithin"),
        ("साइट्रिक अम्ल", "citric_acid"),
    ],
)
def test_exact_alias_matches_keep_original_spans(text, identifier):
    result = GlossaryStore().match(text)
    assert len(result) == 1
    assert result[0].entry.entry_id == identifier
    assert text[result[0].start : result[0].end] == result[0].matched_text


@pytest.mark.parametrize(
    "text",
    [
        "330",
        "E3300",
        "INS 4150",
        "lecithinized",
        "xanthan gummies",
        "INS 322(ii)",
        "INS 322",
        "E322(ii)",
        "E 330 (i)",
        "INS 415(i)",
        "INS 412(i)",
        "E211(ii)",
        "INS 202 (i)",
        "E4120",
        "INS ４１２",
        "INS २०२",
        "İNS 330",
        "ıns 330",
        "E330\u00a0(i)",
        "INS 412\u202f(i)",
        "E211\u2003(ii)",
    ],
)
def test_unreviewed_codes_and_partial_words_do_not_match(text):
    assert GlossaryStore().match(text) == []


@pytest.mark.parametrize(
    "text",
    [
        "लेसिथिनी",
        "ज़ैंथन गमी",
        "साइट्रिक अम्ली",
        "lecithin\u0301",
        "\u0301citric acid",
        "INS 330\u0301",
        "\u0301INS 415",
        "lecithin\u200dase",
        "lecithin\u200case",
        "pre\u200dlecithin",
        "pre\u200clecithin",
        "लेसिथिन\u200dयुक्त",
        "ग्वार गमी",
        "sodium benzoates",
        "potassium sorbate\u0301",
        "INS 211\u200d0",
        "\u0301INS 202",
        "lecithin\u2060ase",
        "pre\u2060lecithin",
        "lecithin\u00adized",
        "INS 211\u20600",
        "citric acid\u200e",
    ],
)
def test_combining_marks_are_part_of_the_ingredient_word(text):
    assert GlossaryStore().match(text) == []


def test_matching_does_not_claim_whole_ingredient_list_is_explained():
    text = "Oats, mysterious ingredient, lecithin, INS 330"
    matches = GlossaryStore().match(text)
    assert [match.entry.entry_id for match in matches] == ["lecithin", "citric_acid"]
    assert "mysterious ingredient" not in [match.matched_text for match in matches]


def test_matching_has_a_finite_output_budget():
    assert len(GlossaryStore().match(", ".join(["citric acid"] * 100))) == 64
    with pytest.raises(ValueError):
        GlossaryStore().match("a" * 16001)


def test_glossary_requires_known_unique_evidence(tmp_path):
    value = projection()
    value["entries"][0]["source_ids"] = ["unreviewed"]
    write_projection(tmp_path, value)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


def test_glossary_rejects_oversize_and_duplicate_fields(tmp_path):
    destination = tmp_path / "glossary-v2.json"
    destination.write_bytes(b"x" * 65537)
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)
    destination.write_text('{"version":"1","version":"2"}', encoding="utf-8")
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


def test_glossary_response_retains_sources_and_integrity():
    store = GlossaryStore()
    response = store.response()
    assert response.status == "ready"
    assert response.glossary_version == store.version
    assert response.artifact == store.artifact
    assert response.entries == store.entries()
    assert response.sources == store.sources()


def test_caller_changes_cannot_alter_later_glossary_matches_or_responses():
    store = GlossaryStore()
    response = store.response()
    response.entries[0].aliases.clear()
    response.entries[0].source_ids.clear()
    response.sources.clear()
    response.warnings.clear()
    matches = store.match("lecithin")
    assert len(matches) == 1
    assert matches[0].entry.source_ids == ["codex-gsfa-lecithin"]
    matches[0].entry.aliases.clear()
    assert store.match("lecithin")[0].entry.aliases == ["lecithin", "लेसिथिन"]
    assert store.response().sources
    assert store.response().warnings


def test_preserved_historical_three_entry_response_remains_readable():
    origin = Path(__file__).resolve().parents[2] / "app/reports/glossary-v1.json"
    raw = origin.read_bytes()
    value = json.loads(raw)
    value.pop("reviewed_on")
    value["artifact"] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), "entry_count": 3}
    result = GlossaryResponse.model_validate_json(json.dumps(value))
    assert result.glossary_version == "ingredients-2026-10-07.1"
    assert len(result.entries) == 3
    assert result.artifact.entry_count == 3


def test_historical_artifact_omitted_count_retains_its_three_entry_default():
    from app.reports.glossary import GlossaryArtifact

    artifact = GlossaryArtifact.model_validate({"sha256": "a" * 64, "bytes": 100})
    assert artifact.entry_count == 3


def test_json_whitespace_does_not_change_reviewed_facts(tmp_path):
    value = projection()
    write_projection(tmp_path, value)
    store = GlossaryStore(tmp_path)
    assert store.match("INS 412")[0].entry.entry_id == "guar_gum"
    assert store.artifact.bytes == len((tmp_path / "glossary-v2.json").read_bytes())


def test_response_cannot_claim_a_count_that_disagrees_with_its_entries():
    value = GlossaryStore().response().model_dump(mode="json")
    value["artifact"]["entry_count"] = 3
    with pytest.raises(ValueError):
        GlossaryResponse.model_validate_json(json.dumps(value))


def test_long_code_spacing_cannot_overflow_the_bounded_match_contract():
    store = GlossaryStore()
    matches = store.match("INS" + " " * 250 + "330")
    assert len(matches) == 1 and len(matches[0].matched_text) == 256
    assert store.match("INS" + " " * 251 + "330") == []
