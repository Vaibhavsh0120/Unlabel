# Frontend/backend API plan

This is a proposed contract; the FastAPI backend and machine-readable schemas are not implemented. Later definitions belong in `contracts/schemas/`, examples/parity fixtures in `contracts/examples/`, and compatibility policy in `contracts/versioning/`.

## Proposed endpoints

| Endpoint | Purpose | Output |
| --- | --- | --- |
| `GET /v1/health` | Minimal service readiness; no scan/profile | Ready/degraded status without secrets |
| `GET /v1/meta` | Client compatibility and available capability handshake | Contract, knowledge/rule/policy versions, evaluator scope and enabled capabilities |
| `POST /v1/analyze` | Expanded online evaluation of a user-confirmed paired label | Normalized product, findings, evidence and neutral suitability facts |
| `GET /v1/ingredients/{ingredient_id}` | Explain a matched canonical ingredient | Reviewed bilingual content and references |
| `GET /v1/evidence/{source_id}` | Show provenance | Public source metadata, provision locator, permitted excerpt/link and review state |
| `GET /v1/products/{barcode}` | Optional community enrichment | Source-tagged data or an explicit unavailable/not-found result |

Routes, access scopes and limits are implemented later. Metadata must not expose provider secrets. Public Gemini capability remains disabled until proper individual authentication for an eligible adult beta is in place. Validate token issuer, audience, signature, expiry and access allowlist; CORS is not authentication. A private development token may protect local tooling/LAN experiments, but must never be embedded in a distributed app or reused as public authentication.

No profile, image upload, scan-history, per-frame or generic chat endpoints are required. Charts and product comparison use existing normalized reports locally.

## Proposed input

| Field/group | Meaning |
| --- | --- |
| `schema_version`, `client_request_id` | Contract and duplicate-request correlation |
| `capture_session_id`, `input_revision` | Random session identifier and exact correction revision; no user/device identity |
| `paired_package_confirmed` | Front/back belong to the same package |
| `front_regions`, `back_regions` | Stable region IDs, confirmed public text and side |
| `completeness` | Ingredient/nutrition/allergen/claim panels captured, partial or unreadable |
| `confirmed_fields` | Reviewed ingredients, claims, declarations and nutrient rows linked to region IDs |
| nutrient row | Decimal value or null, unit, basis amount/unit, as-sold/as-prepared state when declared |
| `output_language` | English or Hindi |
| `public_product_identity` | Optional visible product name/barcode/category |
| requested capability/version context | Needed expanded checks and the client's supported contract/knowledge versions |

Original OCR and corrections retain provenance locally; submit only the public fields needed for analysis. Images/coordinates remain local. Region IDs map findings to local OCR boxes. Do not invent OCR confidence when the adapter supplies none.

Corrections are user-confirmed label evidence, not independently verified truth. Conflicting fields require correction. No names, contact details, preference/allergy profiles, location, personal history or provider keys belong in a request.

## Proposed report shared by offline and online evaluators

| Field/group | Meaning |
| --- | --- |
| `schema_version`, `analysis_id`, `client_request_id`, `input_revision` | Contract/correlation and exact input revision |
| `analysis_status` | complete, partial or needs_correction; pipeline completion is not certainty for every claim |
| `evaluator_origin`, `evaluated_capabilities` | Offline subset or expanded backend; explicit scope |
| `knowledge_version`, `rule_set_version`, `analyzed_at` | Reproducibility/freshness |
| `normalized_product`, `ingredient_matches` | Confirmed values, canonical IDs, field references and unresolved information |
| `findings` | Stable rule/finding IDs, applicability, outcome, input references, rule version and source IDs |
| `neutral_suitability_facts`, `suitability_policy_version` | Declared/may-contain/unknown evidence and reviewed reason catalog; no personal profile |
| `nutrient_visualization_data` | Known values with units/bases; explicit unknowns |
| `evidence` | Publisher, URL, provision/page, effective/review dates and review status |
| `explanation_origin`, `warnings` | Reviewed template/optional validated AI/cache, incomplete data and fallback reason |

Claim outcomes are **supported**, **contradicted** or **insufficient_information**. Applicability and source-review state are separate. A nonapplicable category rule cannot produce a contradiction. Unsupported offline checks return unknown information with a scope reason.

Unknown nutrients are null plus a reason, never zero. Preserve total/added sugar, sodium/salt and serving/100 g/100 mL distinctions. The client selects neutral reasons using local preferences while retaining all warnings.

## Processing and compatibility

1. Check `/v1/meta` before requesting expanded capabilities; keep its result versioned and treat it as a snapshot.
2. Validate size, contract, pairing, text/field types and correction revision.
3. Normalize available fields and match canonical identifiers without filling missing values.
4. Select reviewed applicable rules; compute findings/neutral facts with input and source provenance.
5. Retrieve approved public evidence and render reviewed English/Hindi templates.
6. If explicitly allowed, request an optional public-product Gemini rewrite; validate immutable numbers, outcomes and permitted references, otherwise retain templates.
7. Return the report without persisting a user scan/profile; reject stale responses on the client.

Offline evaluation needs no handshake. Both evaluators use the canonical declarative definitions and parity fixtures, with explicit supported rule IDs; there is no separate Dart threshold catalog. Display each report's scope/version. Do not silently combine incompatible reports or relabel a saved report as fresh.

## Recovery and limits

| Condition | Behavior |
| --- | --- |
| Invalid input/unsupported contract | 400 or validation 422 with stable field/error codes |
| Missing/invalid required individual auth | 401/403; no provider configuration disclosed |
| Oversized input | 413 before provider work |
| Partial label/unsupported rule | 200 partial report with explicit unknowns and capture/scope guidance |
| Ambiguous critical field | 200 needs_correction; no assumed outcome |
| Incompatible knowledge/policy | Compatibility warning; suppress affected merged findings/reasons |
| Backend not ready/rate limited | 503/429 with bounded retry guidance; supported local evaluation continues |
| Gemini quota/timeout/invalid output | Successful deterministic report with template fallback |
| Product lookup unavailable | Optional enrichment unavailable; confirmed label analysis continues |
| Network timeout/stale response | Keep local scan, run supported subset, discard stale result and offer bounded retry |

Bound request sizes, concurrency, timeouts and retries. Never multiply API keys to bypass project quotas. Optional public explanation caches must include label/language/evidence/rule/policy/provider versions. Vercel memory and `/tmp` caches/counters are disposable and cannot enforce durable shared budgets; cache misses must remain safe and functional.
