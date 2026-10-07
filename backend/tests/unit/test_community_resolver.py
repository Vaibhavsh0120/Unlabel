import importlib.util
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.catalogue.facts import FactsLookup, project_facts
from app.catalogue.models import Manifest
from app.schemas.products import Product
from tests.community_fixtures import (
    CODE,
    NOW,
    approved_revision,
    candidate_revision,
    contribution_request,
)


def resolve(snapshot, community, knowledge_version=None):
    assert importlib.util.find_spec("app.community.resolver") is not None, "resolver missing"
    from app.community.resolver import resolve_product

    return resolve_product(snapshot, community, knowledge_version)


def lookup(*revisions, status=None, barcode=CODE):
    from app.community.models import CommunityLookup

    return CommunityLookup(
        requested_barcode=barcode,
        status=status or ("found" if revisions else "not_found"),
        revisions=list(revisions),
    )


def off(
    sugar=0,
    per_unit="g",
    ingredients="Oats, milk",
    name="Synthetic community oats",
    quantity="300 g",
):
    manifest = Manifest(
        snapshot_id="synthetic-off-test",
        source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
        source_sha256="b" * 64,
        exported_at=NOW,
        indexed_at=NOW,
        rows_read=1,
        india_rows=1,
        indexed_products=1,
        unsupported_barcodes=0,
        missing_name=0,
        missing_ingredients=0,
    )
    raw = {
        "allergens_tags": [],
        "traces_tags": [],
        "nutrition": {
            "input_sets": [
                {
                    "source": "packaging",
                    "preparation": "as_sold",
                    "per": "100g" if per_unit == "g" else "100ml",
                    "per_quantity": 100,
                    "per_unit": "ml" if per_unit == "mL" else per_unit,
                    "nutrients": {"sugars": {"value": sugar, "unit": "g"}},
                }
            ]
        },
    }
    details, _ = project_facts(raw, CODE)
    return FactsLookup(
        requested_barcode=CODE,
        status="found",
        manifest=manifest,
        product=Product(
            barcode=CODE,
            name=name,
            brands="Synthetic test brand",
            quantity_text=quantity,
            ingredients_text=ingredients,
        ),
        details=details,
    )


def comparison(result, field):
    return next(item for item in result.comparisons if item.field == field)


def test_sources_and_licenses_remain_intact_with_no_fabricated_claim_assessment():
    snapshot = off()
    community = lookup(approved_revision())
    result = resolve(snapshot, community, "fssai-numeric-v1")
    assert result.off_snapshot == snapshot
    assert result.community == community
    assert result.off_snapshot is not None and result.off_snapshot.manifest is not None
    assert result.off_snapshot.manifest.database_license == "ODbL-1.0"
    assert result.community.revisions[0].license == "CC0-1.0"
    assert result.knowledge_version == "fssai-numeric-v1"
    payload = result.model_dump()
    assert (
        not {"preferred_source", "merged_facts", "claim_assessments", "health_score"}
        & payload.keys()
    )
    assert "community_assertions_not_current_label_confirmation" in result.warnings


def test_equal_known_zero_agrees_without_filling_unknown_protein():
    result = resolve(off(), lookup(approved_revision()))
    sugar = comparison(result, "nutrition.as_sold.100g.sugars")
    assert sugar.state == "agreement"
    assert set(sugar.source_ids) == {"off:synthetic-off-test", "community:" + "a" * 64}
    assert comparison(result, "nutrition.as_sold.100g.protein").state == "unknown"
    assert comparison(result, "ingredients").state == "agreement"


def test_nutrient_disagreement_is_visible_and_values_remain_unmodified():
    result = resolve(off(sugar=2), lookup(approved_revision()))
    assert comparison(result, "nutrition.as_sold.100g.sugars").state == "conflict"
    assert result.off_snapshot is not None and result.off_snapshot.details is not None
    assert result.off_snapshot.details.nutrition.snapshot.tables[0].nutrients["sugars"].value == 2
    assert result.community.revisions[0].snapshot.tables[0].nutrients["sugars"].value == 0
    assert "sources_disagree_requires_confirmation" in result.warnings


def test_quantity_or_identity_conflicts_block_cross_source_nutrition_comparison():
    for changed in (off(quantity="400 g"), off(name="Synthetic chocolate cereal")):
        result = resolve(changed, lookup(approved_revision()))
        assert "identity_conflict_requires_confirmation" in result.warnings
        assert comparison(result, "nutrition.as_sold.100g.sugars").state == "not_comparable"


def test_incompatible_mass_volume_and_unknown_serving_never_agree():
    result = resolve(off(per_unit="mL"), lookup(approved_revision()))
    assert comparison(result, "nutrition.as_sold.100g.sugars").state == "not_comparable"
    assert comparison(result, "nutrition.as_sold.100mL.sugars").state == "not_comparable"
    rows = [
        {
            "row_id": "sugars",
            "table_id": "serving",
            "nutrient": "sugars",
            "value": 0,
            "unit": "g",
            "basis": {"kind": "serving", "amount": None, "unit": None},
            "preparation": "as_sold",
        }
    ]
    result = resolve(off(), lookup(approved_revision(rows=rows)))
    assert comparison(result, "nutrition.as_sold.serving.sugars").state == "not_comparable"
    assert comparison(result, "nutrition.as_sold.100g.sugars").state == "not_comparable"


def test_partial_ingredients_and_missing_allergen_declarations_are_not_safety_agreement():
    section = {
        "status": "present",
        "text": "Oats, milk",
        "completeness": "partial",
        "origin": "independently_transcribed_package",
    }
    result = resolve(off(), lookup(approved_revision(ingredients=section)))
    assert comparison(result, "ingredients").state == "not_comparable"
    assert comparison(result, "may_contain").state == "unknown"
    assert "allergen_safety_not_assessed" in result.warnings


def test_cross_language_ingredient_disagreement_is_not_translation_conflict():
    identity = {
        "name": "Synthetic community oats",
        "brand": "Synthetic test brand",
        "variant": "Plain",
        "quantity": "300 g",
        "language": "hi",
    }
    section = {
        "status": "present",
        "text": "ओट्स, दूध",
        "completeness": "complete",
        "origin": "independently_transcribed_package",
    }
    result = resolve(off(), lookup(approved_revision(identity=identity, ingredients=section)))
    assert comparison(result, "ingredients").state == "not_comparable"


def test_community_variants_require_confirmation_and_are_not_flattened():
    first = approved_revision()
    identity = first.facts.identity.model_dump()
    identity["variant"] = "Chocolate"
    second = approved_revision(identity=identity, submission_id=str(uuid4())).model_copy(
        update={"revision_id": "c" * 64}
    )
    result = resolve(None, lookup(first, second))
    assert comparison(result, "identity.variant").state == "conflict"
    assert comparison(result, "nutrition.as_sold.100g.sugars").state == "not_comparable"
    assert len(result.community.revisions) == 2


def test_unavailable_and_not_found_sources_preserve_unknown_and_single_source():
    unavailable = FactsLookup(
        requested_barcode=CODE, status="unavailable", warnings=["off_unavailable"]
    )
    empty = resolve(unavailable, lookup(status="unavailable"))
    assert all(item.state == "unknown" for item in empty.comparisons)
    assert empty.off_snapshot is not None
    assert empty.off_snapshot.status == "unavailable"
    result = resolve(unavailable, lookup(approved_revision()))
    assert comparison(result, "identity.name").state == "single_source"
    assert comparison(result, "nutrition.as_sold.100g.sugars").state == "single_source"


def test_exact_barcode_and_public_acceptance_bounds_are_enforced():
    with pytest.raises(ValueError, match="barcode"):
        resolve(off(), lookup(status="not_found", barcode="123456789012"))
    with pytest.raises(ValidationError):
        lookup(approved_revision(), status="not_found")
    with pytest.raises(ValidationError):
        lookup(approved_revision(), approved_revision())


def resolved_field(result, name):
    return next(item for item in result.fields if item.field == name)


def nutrient_row(
    nutrient,
    value,
    *,
    table="back-table",
    unit="g",
    amount=100,
    per_unit="g",
    preparation="as_sold",
):
    return {
        "row_id": nutrient,
        "table_id": table,
        "nutrient": nutrient,
        "value": value,
        "unit": unit,
        "basis": {"kind": "quantity", "amount": amount, "unit": per_unit},
        "preparation": preparation,
    }


def test_missing_ingredients_and_whole_nutrition_can_fill_separate_compatible_domains():
    snapshot = off(ingredients=" ")
    assert snapshot.details is not None
    from app.services.parsing.nutrition import normalize_rows

    snapshot = snapshot.model_copy(
        update={
            "details": snapshot.details.model_copy(
                update={
                    "nutrition": snapshot.details.nutrition.model_copy(
                        update={
                            "availability": "missing",
                            "input_tables": [],
                            "snapshot": normalize_rows([]),
                        }
                    )
                }
            )
        }
    )
    result = resolve(snapshot, lookup(candidate_revision()))
    ingredients = resolved_field(result, "ingredients")
    assert ingredients.value == "Oats, milk"
    assert ingredients.source_ids == ["community:" + "a" * 64]
    assert ingredients.evidence_state == "submitter_confirmed_not_moderator_reviewed"
    sugar = resolved_field(result, "nutrition.as_sold.100g.sugars")
    assert sugar.value == 0 and sugar.unit == "g"
    assert sugar.basis is not None and sugar.basis.amount == 100
    assert sugar.alternatives[0].source_table_id == "back-table"
    assert sugar.alternatives[0].source_row_ids == ["sugar"]
    assert result.off_snapshot == snapshot


def test_compatible_revision_can_complement_nutrient_cells_with_individual_lineage():
    first = candidate_revision(rows=[nutrient_row("sugars", 4)])
    second = candidate_revision(rows=[nutrient_row("protein", 5, amount=20)]).model_copy(
        update={"revision_id": "b" * 64}
    )
    result = resolve(None, lookup(first, second))
    assert resolved_field(result, "nutrition.as_sold.100g.sugars").value == 4
    protein = resolved_field(result, "nutrition.as_sold.100g.protein")
    assert protein.value == 25
    assert protein.source_ids == ["community:" + "b" * 64]
    assert protein.alternatives[0].basis is not None
    assert protein.alternatives[0].basis.amount == 100
    assert len(result.community.revisions) == 2


def test_unknown_revision_cannot_synthesize_cross_source_nutrition_panel():
    first = candidate_revision(rows=[nutrient_row("sugars", 4)], revision_context=None)
    second = candidate_revision(
        rows=[nutrient_row("protein", 3)], revision_context=None
    ).model_copy(update={"revision_id": "b" * 64})
    result = resolve(None, lookup(first, second))
    assert resolved_field(result, "nutrition.as_sold.100g.sugars").value is None
    assert resolved_field(result, "nutrition.as_sold.100g.protein").value is None
    assert "revision_compatibility_unknown" in result.warnings
    # A client-selected context string cannot prove equivalence with OFF's record.
    result = resolve(off(), lookup(candidate_revision(rows=[nutrient_row("protein", 3)])))
    assert resolved_field(result, "nutrition.as_sold.100g.protein").value is None


def test_conflicting_unreviewed_values_have_no_selected_winner_in_either_order():
    first = candidate_revision(rows=[nutrient_row("sugars", 4)])
    second = candidate_revision(rows=[nutrient_row("sugars", 8)]).model_copy(
        update={"revision_id": "b" * 64}
    )
    for revisions in ((first, second), (second, first)):
        cell = resolved_field(resolve(None, lookup(*revisions)), "nutrition.as_sold.100g.sugars")
        assert cell.state == "conflict" and cell.value is None
        assert {item.value for item in cell.alternatives} == {4, 8}
        assert cell.evidence_state is None


def test_partial_ingredients_stay_ordered_alternatives_without_concatenation():
    first = candidate_revision(
        ingredients={
            "status": "present",
            "text": "Oats, milk",
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        }
    )
    second = candidate_revision(
        ingredients={
            "status": "present",
            "text": "Sugar, salt",
            "completeness": "partial",
            "origin": "independently_transcribed_package",
        }
    ).model_copy(update={"revision_id": "b" * 64})
    section = resolved_field(resolve(None, lookup(first, second)), "ingredients")
    assert section.value is None and section.state == "not_comparable"
    assert [item.value for item in section.alternatives] == ["Oats, milk", "Sugar, salt"]


def test_blank_provider_text_is_unknown_and_never_wins_over_a_package_section():
    result = resolve(off(name=" ", ingredients=""), lookup(candidate_revision(rows=[])))
    assert resolved_field(result, "identity.name").value == "Synthetic community oats"
    assert resolved_field(result, "ingredients").value == "Oats, milk"
    assert comparison(result, "identity.name").state == "single_source"


def test_admission_detects_identity_ingredients_and_nutrient_conflicts():
    from app.community.service import contribution_conflicts, prepare_submission

    prepared = prepare_submission(contribution_request())
    assert contribution_conflicts(prepared, [candidate_revision()]) is False
    assert contribution_conflicts(prepared, [], off(sugar=5)) is True
    assert (
        contribution_conflicts(prepared, [candidate_revision(rows=[nutrient_row("sugars", 5)])])
        is True
    )
    assert contribution_conflicts(prepared, [], off(name="Different cereal")) is True
    assert contribution_conflicts(prepared, [], off(ingredients="Oats, sugar")) is True
    assert contribution_conflicts(prepared, [], off(ingredients="")) is False


@pytest.mark.parametrize(
    "rows",
    [
        [nutrient_row("protein", 101)],
        [nutrient_row("sugars", 2), nutrient_row("added_sugars", 3)],
        [nutrient_row("fat", 2), nutrient_row("saturated_fat", 3)],
    ],
)
def test_inconsistent_same_table_quantities_require_review_without_rejecting_the_observation(rows):
    from app.community.service import contribution_conflicts, prepare_submission

    prepared = prepare_submission(contribution_request(rows=rows))
    assert prepared.snapshot.status != "needs_correction"
    assert contribution_conflicts(prepared, []) is True


def test_anomaly_checks_do_not_guess_density_or_compare_different_tables():
    from app.community.service import contribution_conflicts, prepare_submission

    rows = [nutrient_row("sugars", 120, per_unit="mL")]
    assert contribution_conflicts(prepare_submission(contribution_request(rows=rows)), []) is False
    rows = [nutrient_row("fat", 2), nutrient_row("saturated_fat", 3, table="different")]
    assert contribution_conflicts(prepare_submission(contribution_request(rows=rows)), []) is False
