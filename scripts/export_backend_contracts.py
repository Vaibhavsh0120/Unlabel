"""Export current backend schemas and owned synthetic examples; keep historical OpenAPI files."""

import json
import sys
from datetime import UTC, datetime
from importlib import import_module
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
version = import_module("app").__version__
create_app = import_module("app.main").create_app
nutrition = import_module("app.schemas.nutrition")
products = import_module("app.schemas.nutrition_products")
normalize_rows = import_module("app.services.parsing.nutrition").normalize_rows
Settings = import_module("app.core.config").Settings
Source = import_module("app.schemas.products").Source
catalogue = import_module("app.catalogue.models")
catalogue_status = import_module("app.catalogue.status")
catalogue_facts = import_module("app.catalogue.facts")
errors = import_module("app.schemas.errors")
claims = import_module("app.claims.models")
claim_knowledge = import_module("app.claims.knowledge")
assess_claims = import_module("app.claims.engine").assess_claims


def write(directory: str, name: str, value):
    target = ROOT / "contracts" / directory / name
    target.write_text(
        json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8"
    )


def main():
    write(
        "schemas",
        f"backend-v{version}.openapi.json",
        create_app(Settings(_env_file=None)).openapi(),
    )
    for filename, model in {
        "nutrition-lookup-v1.schema.json": products.NutritionLookup,
        "nutrition-normalize-request-v1.schema.json": nutrition.NormalizeRequest,
        "nutrition-normalize-response-v1.schema.json": products.NormalizeResponse,
        "catalogue-lookup-v1.schema.json": catalogue.CatalogLookup,
        "catalogue-manifest-v1.schema.json": catalogue.Manifest,
        "catalogue-status-v1.schema.json": catalogue_status.CatalogueStatus,
        "catalogue-facts-v1.schema.json": catalogue_facts.FactsLookup,
        "validation-failure-v1.schema.json": errors.ValidationFailure,
        "claims-check-request-v1.schema.json": claims.ClaimsRequest,
        "claims-check-response-v1.schema.json": claims.ClaimsResponse,
        "claims-rules-v1.schema.json": claims.ClaimsRulesResponse,
        "claims-unavailable-v1.schema.json": claims.ClaimsUnavailable,
        "evidence-v1.schema.json": claims.EvidenceResponse,
    }.items():
        write("schemas", filename, model.model_json_schema())

    request = nutrition.NormalizeRequest.model_validate(
        {
            "schema_version": "1",
            "client_request_id": "4ca97170-4077-4af4-bc75-b1d4b632f01f",
            "capture_session_id": "960f1c01-981d-4fe6-8394-31c4470e7936",
            "input_revision": 2,
            "confirmed": True,
            "completeness": "complete",
            "rows": [
                {
                    "row_id": "protein-line",
                    "table_id": "back-panel",
                    "nutrient": "protein",
                    "value": 4,
                    "unit": "g",
                    "basis": {"kind": "serving", "amount": 40, "unit": "g"},
                    "preparation": "as_sold",
                }
            ],
        }
    )
    date = datetime(2026, 10, 5, 12, tzinfo=UTC)
    response = products.NormalizeResponse(
        client_request_id=request.client_request_id,
        capture_session_id=request.capture_session_id,
        input_revision=request.input_revision,
        normalized_at=date,
        snapshot=normalize_rows(request.rows, completeness=request.completeness),
    )
    lookup = products.NutritionLookup(
        requested_barcode="0123456789012",
        product_barcode="0123456789012",
        status="found",
        source=Source(
            product_url="https://world.openfoodfacts.org/product/0123456789012",
            retrieved_at=date,
        ),
        input_tables=[
            products.InputTableSource(
                table_id="back-panel", provider_source="packaging"
            )
        ],
        snapshot=normalize_rows(request.rows),
        warnings=["synthetic_example_not_a_real_product"],
    )
    for filename, model in {
        "nutrition-normalize-v1.request.synthetic.json": request,
        "nutrition-normalize-v1.response.synthetic.json": response,
        "nutrition-lookup-v1.synthetic.json": lookup,
    }.items():
        write("examples", filename, model.model_dump(mode="json"))
    catalogue_example = catalogue.CatalogLookup(
        requested_barcode="0123456789012",
        status="found",
        manifest=catalogue.Manifest(
            snapshot_id="synthetic-catalogue",
            source_url="https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz",
            source_sha256="0" * 64,
            source_format="off_jsonl",
            coverage="sample",
            exported_at=date,
            indexed_at=date,
            rows_read=1,
            india_rows=1,
            indexed_products=1,
            unsupported_barcodes=0,
            missing_name=0,
            missing_ingredients=1,
        ),
        product=import_module("app.schemas.products").Product(
            barcode="0123456789012", name="Synthetic oats"
        ),
        warnings=[
            "synthetic_example_not_a_real_catalogue",
            "allergen_safety_not_assessed",
        ],
    )
    write(
        "examples",
        "catalogue-lookup-v1.synthetic.json",
        catalogue_example.model_dump(mode="json"),
    )
    status_example = catalogue_status.CatalogueStatus(
        status="ready",
        manifest=catalogue_example.manifest,
        freshness=catalogue_status.snapshot_freshness(date, now=date),
        artifact=catalogue_status.CatalogueArtifact(
            database_sha256="0" * 64,
            database_bytes=4096,
            source_sha256=catalogue_example.manifest.source_sha256,
            snapshot_id=catalogue_example.manifest.snapshot_id,
        ),
    )
    write(
        "examples",
        "catalogue-status-v1.synthetic.json",
        status_example.model_dump(mode="json"),
    )
    facts = catalogue_facts.FactsLookup(
        requested_barcode=catalogue_example.requested_barcode,
        status="found",
        manifest=catalogue_example.manifest,
        product=catalogue_example.product.model_copy(
            update={"allergen_tags": ["en:milk"]}
        ),
        details=catalogue_facts.project_facts(
            {
                "schema_version": 1004,
                "allergens_tags": ["en:milk"],
                "traces_tags": [],
                "nutrition": {
                    "input_sets": [
                        {
                            "source": "packaging",
                            "per": "100g",
                            "per_quantity": 100,
                            "per_unit": "g",
                            "preparation": "as_sold",
                            "nutrients": {"proteins": {"value": 4, "unit": "g"}},
                        }
                    ]
                },
            },
            catalogue_example.requested_barcode,
        )[0],
        warnings=[
            "synthetic_example_not_a_real_catalogue",
            "allergen_safety_not_assessed",
        ],
    )
    write(
        "examples", "catalogue-facts-v1.synthetic.json", facts.model_dump(mode="json")
    )
    store = claim_knowledge.KnowledgeStore(ROOT / "knowledge")
    claim_request = claims.ClaimsRequest.model_validate(
        {
            **request.model_dump(mode="json"),
            "selected_table_id": request.rows[0].table_id,
            "context": {
                "food_category": "ordinary_general_food",
                "form": "solid",
                "preparation": "as_sold",
            },
            "claims": [
                {
                    "claim_id": "synthetic-low-sugar",
                    "claim": "low_sugar",
                    "region_id": "synthetic-front-region",
                }
            ],
            "rows": [
                {
                    **request.rows[0].model_dump(mode="json"),
                    "row_id": "sugar-line",
                    "nutrient": "sugars",
                    "value": 1.0,
                }
            ],
        }
    )
    claim_response = assess_claims(
        claim_request, store, now=datetime(2026, 10, 6, 18, tzinfo=UTC)
    )
    rule_example = claims.ClaimsRulesResponse(
        status="ready",
        knowledge_version=store.knowledge_version,
        reviewed_on=store.reviewed_on,
        rules=list(store.rules.values()),
        unsupported_claims=list(claim_knowledge.UNSUPPORTED_CLAIMS),
        warnings=["numeric_criteria_only", "not_legal_certification"],
    )
    source_id = "fssai-ac-2022-schedule-i"
    evidence = claims.EvidenceResponse(
        status="found",
        requested_source_id=source_id,
        knowledge_version=store.knowledge_version,
        source=store.sources[source_id],
        warnings=[],
    )
    for filename, model in {
        "claims-check-v1.request.synthetic.json": claim_request,
        "claims-check-v1.response.synthetic.json": claim_response,
        "claims-rules-v1.synthetic.json": rule_example,
        "evidence-v1.synthetic.json": evidence,
        "claims-unavailable-v1.synthetic.json": claims.ClaimsUnavailable(
            warnings=["reviewed_claim_knowledge_unavailable"]
        ),
    }.items():
        write("examples", filename, model.model_dump(mode="json"))
    print(
        f"Exported backend v{version} contracts and eleven validated synthetic examples."
    )


if __name__ == "__main__":
    main()
