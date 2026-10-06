# Shared API contracts

Backend v0.2.1 exports the following from `app.main.create_app().openapi()` and the named Pydantic models. Backend models/routes are the source of truth; regenerate current exports after a contract change. Preserve historical OpenAPI files.

| File | Model or purpose |
| --- | --- |
| `schemas/backend-v0.2.1.openapi.json` | Six current routes and strict nutrition contracts |
| `schemas/product-lookup-v1.schema.json` | Unchanged `app.schemas.products.ProductLookup` |
| `schemas/nutrition-lookup-v1.schema.json` | `app.schemas.nutrition_products.NutritionLookup` |
| `schemas/nutrition-normalize-request-v1.schema.json` | `app.schemas.nutrition.NormalizeRequest` |
| `schemas/nutrition-normalize-response-v1.schema.json` | `app.schemas.nutrition_products.NormalizeResponse` |
| `schemas/catalogue-lookup-v1.schema.json` | Optional indexed product with independent export Manifest |
| `schemas/catalogue-manifest-v1.schema.json` | Source hash/date/format, exact market selection, counts, coverage and licenses |
| `schemas/validation-failure-v1.schema.json` | Actual bounded redacted 422 responses |
| `schemas/backend-v0.2.0.openapi.json` | Historical nutrition release; do not replace |
| `schemas/backend-v0.1.0.openapi.json` | Historical product-lookup release; do not replace |

`examples/product-lookup-v1.synthetic.json` is a validated synthetic lookup response for client development. It is not a real product or a food-quality verdict. Product fields retain Open Food Facts provenance, unknown values and explicit lookup failure states.

`examples/nutrition-normalize-v1.request.synthetic.json` and `examples/nutrition-normalize-v1.response.synthetic.json` form a confirmed-input integration pair. `examples/nutrition-lookup-v1.synthetic.json` demonstrates separate OFF origin/table source metadata. All examples are synthetic, not provider exports or approved nutritional policies.

The [backend guide](../backend/README.md) documents six implemented routes; the [API plan](../docs/architecture/API_PLAN.md) separates normalization from future analysis endpoints. Nutrition facts use kcal/g canonical units, preserve original rows, keep table bases/preparation/source distinct, and return null plus reasons for unknown values. A complete normalization result does not mean every nutrient is reported, healthy, allergy-safe or legally compliant.

The v0.1 strict ProductLookup response has no added nutrition fields. Add separate nutrition client models instead of depending on raw OFF data or changing the old response parser. Metadata enables `nutrition_lookup` and `nutrition_normalization`, while `nutrition_analysis`, claims, comparison, glossary and AI remain disabled. Both teammates must agree on future schema changes and fixture expectations before coding independently.

Backend validation models and Dart client models should follow this boundary. Do not create two independently maintained interpretations of the rules. A contract change requires both consumers and shared fixtures to be updated together.

Regenerate current exports from the repository root with the backend environment:

~~~powershell
backend/.venv/Scripts/python.exe scripts/export_backend_contracts.py
~~~

On macOS/Linux use `backend/.venv/bin/python`. The exporter validates synthetic models and preserves historical OpenAPI/product v1 files; regression tests verify the unchanged product schema and synthetic examples. OpenAPI/model agreement is also checked during release validation. A JSON Schema alone cannot express every strict numeric, unique-row-ID or semantic basis/unit rule enforced by the backend.

Catalogue lookup keeps export provenance separate from live OFF API3.6 Source. Exact leading-zero variants are distinct keys. The optional capability is false without a valid configured index; samples/independently unverified coverage stay explicit. No nutrition aggregates or private scans are added to the catalogue.
