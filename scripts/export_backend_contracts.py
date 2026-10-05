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
    print(
        f"Exported backend v{version} contracts and three validated synthetic examples."
    )


if __name__ == "__main__":
    main()
