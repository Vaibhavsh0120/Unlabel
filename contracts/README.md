# Shared API contracts

Backend **v0.3.0** exports current schemas from `app.main.create_app().openapi()` and named Pydantic models. Backend routes/models are the source of truth; regenerate exports after changes. Preserve historical OpenAPI and strict earlier response shapes. Flutter stays **0.0.0+1** with client integration pending.

| File | Model or purpose |
| --- | --- |
| `schemas/backend-v0.3.0.openapi.json` | Eleven current routes, including separate confirmed-label claim checks, loaded rules and public evidence metadata. |
| `schemas/claims-check-request-v1.schema.json` | Confirmed rows, identified claims, selected table and explicit applicability context. |
| `schemas/claims-check-response-v1.schema.json` | Numerical assessments, input/rule/source references, normalization snapshot and statutory energy-conversion metadata. |
| `schemas/claims-rules-v1.schema.json` | Seven reviewed numerical rules, four recognized unsupported claims and knowledge readiness/version. |
| `schemas/claims-unavailable-v1.schema.json` | Typed 503 response when reviewed knowledge is unavailable. |
| `schemas/evidence-v1.schema.json` | Public source metadata, review qualifications and found/not-found/unavailable states. |
| `schemas/catalogue-facts-v1.schema.json` | `FactsLookup`: exact identity/manifest, availability-aware tags, direct nutrition, record dates and official image descriptor. |
| `schemas/catalogue-status-v1.schema.json` | Ready/unavailable status, source age, optional receipt artifact summary and field limits. |
| `schemas/product-lookup-v1.schema.json` | Unchanged live `ProductLookup` v1. |
| `schemas/nutrition-lookup-v1.schema.json` | Source-tagged live `NutritionLookup`. |
| `schemas/nutrition-normalize-request-v1.schema.json` | Strict confirmed-input `NormalizeRequest`. |
| `schemas/nutrition-normalize-response-v1.schema.json` | Independent confirmed-origin `NormalizeResponse`. |
| `schemas/catalogue-lookup-v1.schema.json` | Preserved exact indexed identity with export manifest. |
| `schemas/catalogue-manifest-v1.schema.json` | Source hash/date/format, market selection, counts, coverage and licenses. |
| `schemas/validation-failure-v1.schema.json` | Bounded redacted 422 response. |
| `schemas/backend-v0.2.3.openapi.json` | Historical independently released rich-facts API. |
| `schemas/backend-v0.2.2.openapi.json` | Historical hosted identity/status release. |
| `schemas/backend-v0.2.1.openapi.json` | Historical local catalogue release. |
| `schemas/backend-v0.2.0.openapi.json` | Historical nutrition release. |
| `schemas/backend-v0.1.0.openapi.json` | Historical product release. |

The exporter validates and writes **eleven owned synthetic examples**. `catalogue-facts-v1.synthetic.json` demonstrates separate `details`; product, catalogue/status and live nutrition examples preserve independent origins. The normalization request/response pair demonstrates confirmed rows. The claims request/response pair demonstrates synthetic identified claims, matching context, selected table, numerical outcomes and statutory conversion metadata. Separate claims-rules, claims-unavailable and evidence examples cover read/503 states. These are not real scans, health policies or complete regulatory verdicts.

Check `/v1/meta` API/schema/capabilities. `catalogue_facts` requires a validated facts-enabled store; an older identity-only index keeps its routes without enabling facts. `claim_checks` requires valid loaded reviewed knowledge; `knowledge_version` identifies `claims-2026-10-06.1`, and `knowledge_artifact` summarizes a verified package receipt or is null for direct local source loading/unavailable knowledge. Add separate client models instead of modifying the strict v1 identity parser. Broad `nutrition_analysis`, glossary, comparison and AI remain disabled. [Backend guide](../backend/README.md) · [API plan](../docs/architecture/API_PLAN.md).

Facts nutrition uses direct packaging/manufacturer inputs only, preserving kcal/g units, rows, sources, bases, preparation, conflicts and unknown reasons. `legacy_unsupported`, `missing` and `invalid` remain explicit. Tags distinguish present empty arrays from missing/invalid fields; none establishes allergy safety. Optional dates identify record modification separately from export age. Official image descriptors include language/revision/400-size and attribution/license; no arbitrary URL or bundled image bytes. Exact lookup keys preserve leading zeros while OFF image disk paths use their canonical normalization.

Snapshot found/missing/unavailable states stay separate from live OFF states and normalized `complete|partial|needs_correction`. A complete normalization does not mean every nutrient is known or that a food is healthy/compliant. Snapshot misses make no OFF request; coverage remains `unverified`. Source-age metadata describes maintenance policy, not current-package verification. Local status may have `artifact: null`; a hosted verified receipt supplies its integrity summary.

Claims use `assessment_basis: user_confirmed_label` and `scope: numeric_criterion_only`. Seven fibre/sugar/sodium claims have reviewed criteria; high/source protein, no added sugar and multigrain remain insufficient. Selected-table context and input references are explicit. Any applicable fibre alternative may pass; unknown alternatives prevent a false contradiction. Statutory energy uses original rows and 4.2 kJ/kcal with version `fssai-schedule-i-note2-v1`; the unchanged normalization snapshot retains 4.184. Missing/conflicting/future-dated or unsupported evidence cannot become a confident assessment. A supported numerical criterion is not an allergy-safe, health or complete compliance verdict.

Regenerate from root with the backend environment:

~~~powershell
backend/.venv/Scripts/python.exe scripts/export_backend_contracts.py
~~~

On macOS/Linux use `backend/.venv/bin/python`. The exporter validates synthetic models and preserves historical exports. JSON Schema alone cannot encode every strict numeric, unique-ID, source/image-identity or semantic unit/basis rule enforced by the backend. Shared fixtures and regression tests verify those boundaries. No private scans, profile, credentials or raw provider internals belong in contracts.
