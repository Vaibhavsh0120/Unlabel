import json
from pathlib import Path

import pytest

from app.reports.glossary import GlossaryStore


def test_glossary_is_bounded_reviewed_bilingual_function_content():
    store = GlossaryStore()
    assert store.version == "ingredients-2026-10-07.1"
    assert len(store.entries()) == 3
    assert len(store.sources()) == 3
    assert store.artifact.entry_count == 3
    assert len(store.artifact.sha256) == 64
    assert all(entry.name_hi and entry.function_hi for entry in store.entries())
    assert all(source.scope == "name_and_technological_function_only" for source in store.sources())


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
    origin = Path(__file__).resolve().parents[2] / "app/reports/glossary-v1.json"
    value = json.loads(origin.read_text(encoding="utf-8"))
    value["entries"][0]["source_ids"] = ["unreviewed"]
    (tmp_path / "glossary-v1.json").write_text(json.dumps(value), encoding="utf-8")
    with pytest.raises(ValueError):
        GlossaryStore(tmp_path)


def test_glossary_rejects_oversize_and_duplicate_fields(tmp_path):
    destination = tmp_path / "glossary-v1.json"
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
