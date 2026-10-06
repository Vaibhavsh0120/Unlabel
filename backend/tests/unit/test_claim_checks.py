import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.claims.engine import assess_claims
from app.claims.knowledge import KnowledgeStore
from app.claims.models import ClaimsRequest

KNOWLEDGE = Path(__file__).resolve().parents[3] / "knowledge"
NOW = datetime(2026, 10, 6, 18, 0, tzinfo=UTC)


@pytest.fixture
def store():
    return KnowledgeStore(KNOWLEDGE)


def request(
    claim="low_sugar",
    *,
    value: float | None = 5.0,
    nutrient="sugars",
    form="solid",
    energy: float | None = 400.0,
    basis=None,
    preparation="as_sold",
    category="ordinary_general_food",
):
    quantity = basis or {
        "kind": "quantity",
        "amount": 100.0,
        "unit": "mL" if form == "liquid" else "g",
    }
    rows = [
        {
            "row_id": "nutrient",
            "table_id": "table-a",
            "nutrient": nutrient,
            "value": value,
            "unit": "g",
            "basis": quantity,
            "preparation": preparation,
        }
    ]
    if energy is not None:
        rows.append(
            {
                "row_id": "energy",
                "table_id": "table-a",
                "nutrient": "energy",
                "value": energy,
                "unit": "kcal",
                "basis": quantity,
                "preparation": preparation,
            }
        )
    return ClaimsRequest.model_validate(
        {
            "client_request_id": str(uuid4()),
            "capture_session_id": str(uuid4()),
            "input_revision": 4,
            "confirmed": True,
            "completeness": "partial",
            "rows": rows,
            "claims": [{"claim_id": "front-claim", "claim": claim, "region_id": "front-region"}],
            "selected_table_id": "table-a",
            "context": {
                "food_category": category,
                "form": form,
                "preparation": preparation,
            },
        }
    )


BOUNDARIES = [
    ("source_of_fibre", "fibre", "solid", 3.0, "gte"),
    ("source_of_fibre", "fibre", "liquid", 1.5, "gte"),
    ("high_fibre", "fibre", "solid", 6.0, "gte"),
    ("high_fibre", "fibre", "liquid", 3.0, "gte"),
    ("low_sugar", "sugars", "solid", 5.0, "lte"),
    ("low_sugar", "sugars", "liquid", 2.5, "lte"),
    ("sugar_free", "sugars", "solid", 0.5, "lte"),
    ("sugar_free", "sugars", "liquid", 0.5, "lte"),
    ("low_sodium", "sodium", "solid", 0.120, "lte"),
    ("low_sodium", "sodium", "liquid", 0.120, "lte"),
    ("very_low_sodium", "sodium", "solid", 0.040, "lte"),
    ("very_low_sodium", "sodium", "liquid", 0.040, "lte"),
    ("sodium_free", "sodium", "solid", 0.005, "lte"),
    ("sodium_free", "sodium", "liquid", 0.005, "lte"),
]


@pytest.mark.parametrize("claim,nutrient,form,threshold,operator", BOUNDARIES)
def test_exact_boundary_and_immediately_outside(store, claim, nutrient, form, threshold, operator):
    body = request(claim, value=threshold, nutrient=nutrient, form=form)
    result = assess_claims(body, store, now=NOW)
    assessment = result.assessments[0]
    assert assessment.status == "supported"
    assert assessment.scope == "numeric_criterion_only"
    assert assessment.row_ids == (["nutrient", "energy"] if nutrient == "fibre" else ["nutrient"])
    assert result.client_request_id == body.client_request_id
    assert result.input_revision == 4
    assert assessment.region_id == "front-region"
    outside = threshold - 0.000001 if operator == "gte" else threshold + 0.000001
    result = assess_claims(
        request(claim, value=outside, nutrient=nutrient, form=form), store, now=NOW
    )
    assert result.assessments[0].status == "contradicted"


@pytest.mark.parametrize("form", ["solid", "liquid"])
@pytest.mark.parametrize(
    "claim,value,energy",
    [
        ("source_of_fibre", 1.0, 100.0 / 1.5),
        ("high_fibre", 2.0, 100.0 / 1.5),
    ],
)
def test_energy_alternative_can_support_mass_failure(store, form, claim, value, energy):
    # Use a ratio clearly above the threshold rather than floating-point near equality.
    result = assess_claims(
        request(claim, value=value, nutrient="fibre", energy=energy - 1.0, form=form),
        store,
        now=NOW,
    )
    assessment = result.assessments[0]
    assert assessment.status == "supported"
    assert assessment.criteria[-1].outcome == "pass"
    assert assessment.criteria[-1].row_ids == ["nutrient", "energy"]


@pytest.mark.parametrize(
    "claim,value,energy",
    [
        ("source_of_fibre", 1.5, 100.0),
        ("high_fibre", 3.0, 100.0),
    ],
)
def test_exact_energy_boundary(store, claim, value, energy):
    result = assess_claims(
        request(claim, value=value, nutrient="fibre", energy=energy), store, now=NOW
    )
    assert result.assessments[0].status == "supported"
    assert result.assessments[0].criteria[-1].value == value


@pytest.mark.parametrize("energy", [None, 0.0])
def test_fibre_mass_failure_with_unknown_energy_is_not_contradiction(store, energy):
    result = assess_claims(
        request("high_fibre", value=2.0, nutrient="fibre", energy=energy), store, now=NOW
    )
    assessment = result.assessments[0]
    assert assessment.status == "insufficient_information"
    assert "positive_energy_same_table_required" in assessment.missing_inputs


def test_fibre_mass_pass_with_unknown_energy_remains_supported(store):
    result = assess_claims(
        request("high_fibre", value=6.0, nutrient="fibre", energy=None), store, now=NOW
    )
    assert result.assessments[0].status == "supported"
    assert "positive_energy_same_table_required" in result.assessments[0].missing_inputs


@pytest.mark.parametrize("claim", ["source_of_fibre", "low_sugar", "low_sodium"])
def test_unmeasured_serving_never_used_for_numerical_claim(store, claim):
    nutrient = {"source_of_fibre": "fibre", "low_sugar": "sugars", "low_sodium": "sodium"}[claim]
    body = request(
        claim, value=0.0, nutrient=nutrient, basis={"kind": "serving", "amount": None, "unit": None}
    )
    result = assess_claims(body, store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert "measured_quantity_basis_required" in result.assessments[0].missing_inputs


def test_measured_serving_scales_and_preserves_row_provenance(store):
    body = request(value=2.0, basis={"kind": "serving", "amount": 40.0, "unit": "g"})
    result = assess_claims(body, store, now=NOW)
    assert result.assessments[0].status == "supported"
    assert result.assessments[0].criteria[0].value == 5.0
    assert result.snapshot.tables[0].original_basis.amount == 40.0
    assert result.snapshot.tables[0].normalized_basis.amount == 100.0


@pytest.mark.parametrize("category", ["unknown", "special_food"])
def test_non_general_food_scope_is_insufficient(store, category):
    result = assess_claims(request(value=0.0, category=category), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert "ordinary_general_food_scope_not_confirmed" in result.assessments[0].missing_inputs


def test_unknown_form_blocks_even_energy_alternative(store):
    result = assess_claims(
        request("source_of_fibre", value=6.0, nutrient="fibre", form="unknown"), store, now=NOW
    )
    assert result.assessments[0].status == "insufficient_information"
    assert "food_form_not_confirmed" in result.assessments[0].missing_inputs


@pytest.mark.parametrize("form,unit", [("solid", "mL"), ("liquid", "g")])
def test_no_density_is_inferred(store, form, unit):
    result = assess_claims(
        request(value=0.0, form=form, basis={"kind": "quantity", "amount": 100.0, "unit": unit}),
        store,
        now=NOW,
    )
    assert result.assessments[0].status == "insufficient_information"
    assert "food_form_and_quantity_unit_mismatch" in result.assessments[0].missing_inputs


@pytest.mark.parametrize("preparation", ["unknown", "as_prepared"])
def test_context_preparation_must_match_selected_table(store, preparation):
    payload = request(value=0.0).model_dump(mode="json")
    payload["context"]["preparation"] = preparation
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"


def test_confirmed_as_prepared_table_is_explicitly_scoped(store):
    result = assess_claims(request(value=0.0, preparation="as_prepared"), store, now=NOW)
    assert result.assessments[0].status == "supported"
    assert "preparation_instructions_not_independently_verified" in result.warnings


def test_missing_selected_table_is_not_silently_replaced(store):
    payload = request(value=0.0).model_dump(mode="json")
    payload["selected_table_id"] = "does-not-exist"
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert "selected_table_missing" in result.assessments[0].missing_inputs


def test_selected_table_is_not_merged_with_other_table(store):
    payload = request(value=10.0).model_dump(mode="json")
    other = dict(payload["rows"][0], row_id="other", table_id="table-b", value=0.0)
    payload["rows"].append(other)
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "contradicted"
    assert result.assessments[0].row_ids == ["nutrient"]


def test_energy_from_other_table_cannot_complete_fibre_alternative(store):
    payload = request("high_fibre", value=2.0, nutrient="fibre", energy=None).model_dump(
        mode="json"
    )
    payload["rows"].append(
        dict(
            payload["rows"][0],
            row_id="energy-other",
            table_id="table-b",
            nutrient="energy",
            unit="kcal",
            value=10.0,
        )
    )
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert result.assessments[0].criteria[-1].row_ids == ["nutrient"]


def test_conflicting_nutrient_values_need_correction(store):
    payload = request(value=0.0).model_dump(mode="json")
    payload["rows"].append(dict(payload["rows"][0], row_id="conflicting", value=10.0))
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.snapshot.status == "needs_correction"
    assert result.assessments[0].status == "insufficient_information"


def test_unknown_value_is_not_zero(store):
    result = assess_claims(request(value=None), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert result.assessments[0].criteria[0].value is None


def test_sodium_uses_canonical_grams_without_salt_inference(store):
    payload = request("low_sodium", value=120.0, nutrient="sodium").model_dump(mode="json")
    payload["rows"][0]["unit"] = "mg"
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "supported"
    assert result.assessments[0].criteria[0].value == 0.120
    payload["rows"][0]["nutrient"] = "salt"
    payload["rows"][0]["value"] = 0.0
    result = assess_claims(ClaimsRequest.model_validate(payload), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert result.snapshot.tables[0].nutrients["sodium"].value is None


def test_added_sugars_cannot_substitute_for_total_sugars(store):
    result = assess_claims(request(value=0.0, nutrient="added_sugars"), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"


@pytest.mark.parametrize(
    "claim", ["high_protein", "source_of_protein", "no_added_sugar", "multigrain"]
)
def test_unreviewed_claims_do_not_manufacture_verdicts(store, claim):
    result = assess_claims(request(claim, value=0.0, nutrient="added_sugars"), store, now=NOW)
    assessment = result.assessments[0]
    assert assessment.status == "insufficient_information"
    assert assessment.applicability == "not_reviewed"
    assert assessment.rule_id is None
    assert assessment.criteria == []
    assert assessment.missing_inputs


@pytest.mark.parametrize("confirmed", [False, "true", 1])
def test_confirmation_cannot_be_coerced(confirmed):
    payload = request().model_dump(mode="json")
    payload["confirmed"] = confirmed
    with pytest.raises(ValidationError):
        ClaimsRequest.model_validate(payload)


def test_explicit_context_and_claim_region_are_required():
    payload = request().model_dump(mode="json")
    del payload["claims"][0]["region_id"]
    with pytest.raises(ValidationError):
        ClaimsRequest.model_validate(payload)
    payload = request().model_dump(mode="json")
    del payload["context"]["preparation"]
    with pytest.raises(ValidationError):
        ClaimsRequest.model_validate(payload)


def test_claim_count_and_unique_id_limits():
    payload = request().model_dump(mode="json")
    payload["claims"] *= 2
    with pytest.raises(ValidationError):
        ClaimsRequest.model_validate(payload)
    payload["claims"] = [
        dict(payload["claims"][0], claim_id=f"claim-{index}") for index in range(17)
    ]
    with pytest.raises(ValidationError):
        ClaimsRequest.model_validate(payload)


@pytest.fixture
def knowledge_copy(tmp_path):
    target = tmp_path / "knowledge"
    shutil.copytree(KNOWLEDGE / "rules", target / "rules")
    shutil.copytree(KNOWLEDGE / "sources/registry", target / "sources/registry")
    return target


@pytest.mark.parametrize("status", ["needs_review", "superseded"])
def test_source_review_status_blocks_numerical_verdicts(knowledge_copy, status):
    path = knowledge_copy / "sources/registry/fssai-claims-v1.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["sources"][0]["verification_status"] = status
    path.write_text(json.dumps(payload), encoding="utf-8")
    result = assess_claims(request(value=0.0), KnowledgeStore(knowledge_copy), now=NOW)
    assert result.assessments[0].status == "insufficient_information"
    assert "reviewed_source_not_current" in result.assessments[0].missing_inputs


def test_future_review_date_is_not_current(knowledge_copy):
    for relative in ["rules/claims/reviewed-v1.json", "sources/registry/fssai-claims-v1.json"]:
        path = knowledge_copy / relative
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload["reviewed_on"] = "2027-01-01"
        if "sources" in payload:
            for source in payload["sources"]:
                source["verified_on"] = "2027-01-01"
        path.write_text(json.dumps(payload), encoding="utf-8")
    result = assess_claims(request(value=0.0), KnowledgeStore(knowledge_copy), now=NOW)
    assert result.assessments[0].status == "insufficient_information"


@pytest.mark.parametrize(
    "damage",
    ["url", "source_id", "threshold", "duplicate_rule", "missing", "duplicate_json", "oversize"],
)
def test_invalid_knowledge_is_rejected(knowledge_copy, damage):
    source_path = knowledge_copy / "sources/registry/fssai-claims-v1.json"
    rule_path = knowledge_copy / "rules/claims/reviewed-v1.json"
    if damage == "missing":
        source_path.unlink()
    elif damage == "duplicate_json":
        source_path.write_text('{"schema_version":"1","schema_version":"1"}', encoding="utf-8")
    elif damage == "oversize":
        source_path.write_bytes(b" " * 262_145)
    elif damage in ("url", "source_id"):
        payload = json.loads(source_path.read_text(encoding="utf-8"))
        payload["sources"][0]["url" if damage == "url" else "source_id"] = (
            "https://untrusted.example/private" if damage == "url" else "unknown-source"
        )
        source_path.write_text(json.dumps(payload), encoding="utf-8")
    else:
        payload = json.loads(rule_path.read_text(encoding="utf-8"))
        if damage == "threshold":
            payload["rules"][0]["criteria"][0]["threshold"] = 0.0
        else:
            payload["rules"][1] = payload["rules"][0]
        rule_path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises((ValueError, OSError)):
        KnowledgeStore(knowledge_copy)


@pytest.mark.parametrize("claim,fibre", [("source_of_fibre", 1.5), ("high_fibre", 3.0)])
@pytest.mark.parametrize("amount", [100, 40])
@pytest.mark.parametrize(
    "delta,status", [(0, "supported"), (-0.000001, "contradicted"), (0.000001, "supported")]
)
def test_statutory_kj_conversion_exact_boundary(store, claim, fibre, amount, delta, status):
    body = request(
        claim,
        value=(fibre + delta) * amount / 100,
        nutrient="fibre",
        energy=420 * amount / 100,
        basis={"kind": "quantity", "amount": amount, "unit": "g"},
    )
    body.rows[1].unit = "kJ"
    result = assess_claims(body, store, now=NOW)
    assert result.assessments[0].status == status
    energy_criterion = result.assessments[0].criteria[-1]
    assert energy_criterion.value == pytest.approx(fibre + delta)
    assert result.energy_conversion.kj_per_kcal == 4.2
    assert result.assessment_basis == "user_confirmed_label"
    assert result.snapshot.normalization_version == "1"


def test_regulatory_mixed_energy_disagreement_is_unknown(store):
    body = request("source_of_fibre", value=1.5, nutrient="fibre", energy=100)
    body.rows.append(
        body.rows[1].model_copy(update={"row_id": "energy-kj", "unit": "kJ", "value": 418.4})
    )
    result = assess_claims(body, store, now=NOW)
    assert result.snapshot.status != "needs_correction"
    assert result.assessments[0].status == "insufficient_information"
    assert result.assessments[0].criteria[-1].outcome == "unknown"


def test_tiny_positive_energy_reports_bounded_unknown_alternative(store):
    result = assess_claims(
        request("high_fibre", value=6.0, nutrient="fibre", energy=5e-324), store, now=NOW
    )
    assessment = result.assessments[0]
    assert assessment.status == "supported"
    assert assessment.criteria[0].outcome == "pass"
    assert assessment.criteria[-1].outcome == "unknown"
    assert assessment.criteria[-1].reason == "criterion_conversion_out_of_bounds"


@pytest.mark.parametrize(
    "claim,nutrient,value,amount,energy,energy_unit,criterion_index",
    [
        ("source_of_fibre", "fibre", 0.18, 6.0, 400.0, "kcal", 0),
        ("high_fibre", "fibre", 0.18, 3.0, 400.0, "kcal", 0),
        ("low_sugar", "sugars", 0.3, 6.0, 400.0, "kcal", 0),
        ("sugar_free", "sugars", 0.03, 6.0, 400.0, "kcal", 0),
        ("low_sodium", "sodium", 0.0072, 6.0, 400.0, "kcal", 0),
        ("very_low_sodium", "sodium", 0.0024, 6.0, 400.0, "kcal", 0),
        ("sodium_free", "sodium", 0.0003, 6.0, 400.0, "kcal", 0),
        ("source_of_fibre", "fibre", 0.015, 14.0, 4.2, "kJ", -1),
        ("high_fibre", "fibre", 0.03, 14.0, 4.2, "kJ", -1),
    ],
)
def test_exact_threshold_with_nonterminating_basis_scaling(
    store, claim, nutrient, value, amount, energy, energy_unit, criterion_index
):
    body = request(
        claim,
        value=value,
        nutrient=nutrient,
        energy=energy,
        basis={"kind": "quantity", "amount": amount, "unit": "g"},
    )
    body.rows[1].unit = energy_unit
    result = assess_claims(body, store, now=NOW)
    assessment = result.assessments[0]
    criterion = assessment.criteria[criterion_index]
    assert criterion.value == criterion.threshold
    assert criterion.outcome == "pass"
    assert assessment.status == "supported"
    outside = value - 0.0000001 if criterion.operator == "gte" else value + 0.0000001
    body.rows[0].value = outside
    assert assess_claims(body, store, now=NOW).assessments[0].status == "contradicted"


@pytest.mark.parametrize("field", ["publication_date", "effective_date"])
def test_future_source_dates_block_current_verdict(knowledge_copy, field):
    path = knowledge_copy / "sources/registry/fssai-claims-v1.json"
    data = json.loads(path.read_text())
    data["sources"][0][field] = "2027-01-01"
    path.write_text(json.dumps(data), encoding="utf-8")
    store = KnowledgeStore(knowledge_copy)
    result = assess_claims(request(value=0), store, now=NOW)
    assert result.assessments[0].status == "insufficient_information"
