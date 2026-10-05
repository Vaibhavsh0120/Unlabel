# Shared contracts — reserved

schemas will later hold language-neutral JSON Schema/OpenAPI exports for the frontend/backend boundary. examples will hold synthetic, validated requests and responses. No executable schema or sample verdict has been invented at this planning stage.

The [API plan](../docs/architecture/API_PLAN.md) defines the intended fields, endpoints and failure behavior. Both teammates must agree on schema versions, input provenance, unknown values and result statuses before coding independently.

Backend validation models and Dart client models should follow this boundary. Do not create two independently maintained interpretations of the rules. A contract change requires both consumers and shared fixtures to be updated together.
