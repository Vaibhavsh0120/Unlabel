"""Dated catalogue arithmetic never acquires user confirmation or a package verdict."""

import copy
from types import SimpleNamespace

import pytest

from app.ai.admission import Baseline
from app.claims.catalogue import CatalogueClaimsRequest, assess_catalogue_claims
from app.claims.knowledge import KnowledgeStore
from app.community.store import StoreUnavailable
from tests.unit.test_claim_checks import KNOWLEDGE

CODE = "8901764051258"


def baseline(*, amount=100, unit="g", preparation="as_sold", rows=None):
    identity = {"barcode": CODE, "name": "Synthetic oats", "brand": "Synthetic",
                "quantity": "300 g", "variant": None}
    return Baseline(CODE, identities=[identity], source_ids=["synthetic-source"], tables=[{
        "source_id": "synthetic-source", "table_id": "direct-table",
        "basis": {"amount": amount, "unit": unit}, "preparation": preparation,
        "rows": rows or [{"nutrient": "sugars", "value": 5, "unit": "g", "qualifier": "exact"}],
    }])


def check(monkeypatch, value, *claims, knowledge=True):
    monkeypatch.setattr("app.claims.catalogue.known_baseline", lambda *_: value)
    return assess_catalogue_claims(SimpleNamespace(),
        CatalogueClaimsRequest(barcode=CODE, claims=list(claims)),
        KnowledgeStore(KNOWLEDGE) if knowledge else None)


@pytest.mark.parametrize("amount,sugars,outcome", [(100, 5, "pass"), (100, 5.001, "fail"),
                                                  (50, 2.5, "pass")])
def test_exact_numeric_boundary_retains_dated_source_and_no_final_verdict(monkeypatch, amount, sugars, outcome):
    source = baseline(amount=amount, rows=[{"nutrient": "sugars", "value": sugars,
                                         "unit": "g", "qualifier": "exact"}])
    before = copy.deepcopy(source)
    result = check(monkeypatch, source, "Low sugar")
    assessment = result.assessments[0]
    assert result.status == "ready" and result.assessment_basis == "catalogue_historical"
    assert assessment.status == "insufficient_information"
    assert assessment.comparisons[0].outcome == outcome
    assert assessment.comparisons[0].source_id == "synthetic-source"
    assert assessment.comparisons[0].table_id == "direct-table"
    assert assessment.comparisons[1].outcome == "not_applicable"
    assert "current_package_not_confirmed" in assessment.reasons
    assert len(assessment.rule_source_ids) >= 2
    assert source == before
    assert '"confirmed"' not in result.model_dump_json()


def test_mass_conversion_and_statutory_energy_alternative(monkeypatch):
    source = baseline(rows=[
        {"nutrient": "fibre", "value": 1500, "unit": "mg", "qualifier": "exact"},
        {"nutrient": "energy", "value": 420, "unit": "kJ", "qualifier": "exact"},
        {"nutrient": "sodium", "value": 120, "unit": "mg", "qualifier": "exact"},
    ])
    result = check(monkeypatch, source, "Source of fibre", "Low sodium")
    fibre, sodium = result.assessments
    energy = next(row for row in fibre.comparisons if row.basis == "per_100_kcal")
    assert energy.value == 1.5 and energy.outcome == "pass"
    assert sodium.comparisons[0].value == .12 and sodium.comparisons[0].outcome == "pass"


@pytest.mark.parametrize("change", [{"qualifier": "less_than"}, {"value": None}])
def test_unknown_or_qualified_values_never_become_zero(monkeypatch, change):
    source = baseline()
    source.tables[0]["rows"][0].update(change)
    result = check(monkeypatch, source, "Sugar free")
    assert result.assessments[0].comparisons[0].outcome == "unknown"
    assert result.assessments[0].comparisons[0].value is None


@pytest.mark.parametrize("nutrient,unit,claim", [("sugars", "kcal", "Low sugar"),
                                                ("energy", "g", "Source of fibre")])
def test_preserved_but_incompatible_research_units_cannot_establish_comparisons(monkeypatch, nutrient, unit, claim):
    source = baseline(rows=[{"nutrient": nutrient, "value": 1,
                             "unit": unit, "qualifier": "exact"}])
    if nutrient == "energy":
        source.tables[0]["rows"].append({"nutrient": "fibre", "value": 1.5,
                                          "unit": "g", "qualifier": "exact"})
    result = check(monkeypatch, source, claim)
    selected_basis = "per_100_kcal" if nutrient == "energy" else "per_100_g"
    comparison = next(row for row in result.assessments[0].comparisons if row.basis == selected_basis)
    assert comparison.value is None and comparison.outcome == "unknown"


def test_nutrient_and_identity_disagreements_block_numeric_comparisons(monkeypatch):
    source = baseline()
    source.values = [{"nutrition.as_sold.100g.sugars.g": {"5", "10"}}]
    result = check(monkeypatch, source, "Low sugar")
    assert "catalogue_nutrient_conflict" in result.assessments[0].reasons
    assert all(row.value is None for row in result.assessments[0].comparisons)
    source.values = []
    source.identities.append({**source.identities[0], "quantity": "600 g"})
    result = check(monkeypatch, source, "Low sugar")
    assert "catalogue_identity_conflict" in result.assessments[0].reasons
    assert all(row.value is None for row in result.assessments[0].comparisons)


def test_unknown_products_and_unsupported_claims_fail_closed(monkeypatch):
    result = check(monkeypatch, Baseline(CODE), "No added sugar", "Naturally awesome")
    assert result.status == "not_found"
    assert all(not item.comparisons and item.status == "insufficient_information"
               for item in result.assessments)
    assert result.assessments[0].claim == "no_added_sugar"
    assert result.assessments[1].claim is None
    assert check(monkeypatch, baseline(), "Low sugar", knowledge=False).status == "unavailable"


def test_unavailable_source_returns_no_guessed_data(monkeypatch):
    def unavailable(*_):
        raise StoreUnavailable()
    monkeypatch.setattr("app.claims.catalogue.known_baseline", unavailable)
    result = assess_catalogue_claims(SimpleNamespace(),
        CatalogueClaimsRequest(barcode=CODE, claims=["Low sugar"]), KnowledgeStore(KNOWLEDGE))
    assert result.status == "unavailable"
    assert result.source_ids == []
    assert all(row.value is None for row in result.assessments[0].comparisons)
