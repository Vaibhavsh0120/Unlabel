# Shared API contracts

Backend v0.1.0 exports `schemas/backend-v0.1.0.openapi.json` from `app.main.create_app().openapi()` and `schemas/product-lookup-v1.schema.json` from `app.schemas.products.ProductLookup.model_json_schema()`. The backend models/routes are the source of truth; regenerate exports after a contract change.

`examples/product-lookup-v1.synthetic.json` is a validated synthetic lookup response for client development. It is not a real product or a food-quality verdict. Product fields retain Open Food Facts provenance, unknown values and explicit lookup failure states.

The [backend guide](../backend/README.md) documents the three implemented routes; the [API plan](../docs/architecture/API_PLAN.md) separates them from future analysis endpoints. Both teammates must agree on schema versions, input provenance, unknown values and result statuses before coding independently.

Backend validation models and Dart client models should follow this boundary. Do not create two independently maintained interpretations of the rules. A contract change requires both consumers and shared fixtures to be updated together.
