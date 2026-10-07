# Frontend/backend API plan

Released backend **v0.4.0** has fifteen mounted routes, exported in
`contracts/schemas/backend-v0.4.0.openapi.json`; production v0.4.0 is independently
hosted-verified and released. Four additive community endpoints implement automatic
observations, semantic deduplication, private staging/receipts and sourced fields.
Flutter integration and the v0.5.0 report remain pending.
[Master plan](../planning/MASTER_PLAN.md) · [Actual backend](../../backend/README.md).

## Implemented endpoints and nutrition contract

| Endpoint | Actual behavior |
| --- | --- |
| `GET /v1/health` | Ready/version; provider connectivity explicitly not checked |
| `GET /v1/meta` | API/contract/product-adapter/nutrition-adapter/normalization versions and capabilities |
| `GET /v1/products/{barcode}` | Unchanged typed OFF identity/ingredient/tag/computed-grade lookup |
| `GET /v1/products/{barcode}/nutrition` | Separate OFF direct-input nutrition lookup with community origin and table source metadata |
| `POST /v1/nutrition/normalize` | Structured user-confirmed nutrient normalization, independent of OFF connectivity |
| `GET /v1/catalogue` | Typed status/manifest, source-age policy, receipt artifact summary and excluded-field limits; 503 when not ready |
| `GET /v1/catalogue/products/{barcode}` | Optional exact indexed lookup with separate export manifest, no OFF call; 503 when inactive |
| `GET /v1/catalogue/products/{barcode}/facts` | Separate strict rich-facts model: direct nutrition, tag availability, record date and official image URL; exact snapshot origin |
| `POST /v1/claims/check` | Strict identified claims plus one selected confirmed nutrition table and applicability context; reviewed numerical outcomes |
| `GET /v1/claims/rules` | Seven reviewed fibre/sugar/sodium rules, four recognized unsupported claims and knowledge readiness/version |
| `GET /v1/evidence/{source_id}` | Public metadata for three reviewed sources; unknown ID 404, unavailable knowledge 503, no PDF request |

Four additive v0.4.0 endpoints are mounted: POST `/v1/community/contributions`,
owned GET `/v1/community/contributions/{submission_id}`, public exact GET
`/v1/community/products/{barcode}` and GET `/v1/products/{barcode}/resolved`.
Intake accepts automatic provisional/confirmed observations without a Share flag.
Private staged facts expire after seven days. Eligible exact confirmed front/back
facts may be qualified unreviewed candidates; conflicts/identity mismatch await
review. Server hashes/normalization and semantic dedup preserve originals.

Resolved typed fields retain source/date/completeness/alternatives and unknown
revision conflicts. OFF-only results remain usable when storage is disabled or
unavailable. Metadata reports community readiness with connectivity `not_checked`;
`resolved_product_lookup` is true when community or OFF catalogue facts are ready.
No generic packet imputation or current-label confirmation is invented.
[Community contract](COMMUNITY_CATALOGUE.md).


Metadata enables product lookup, nutrition lookup and nutrition normalization. Its `catalogue` value uses the new `CatalogueStatus` model; catalogue lookup is enabled only for a validated configured index. Hosted configuration also requires a verified build receipt. The [v0.4.0 review](../planning/BACKEND_V0_4_0_REVIEW.md) records current local/source/cloud/hosted gates; the [v0.2.3 review](../planning/BACKEND_V0_2_3_REVIEW.md) preserves catalogue source/deployment history; [catalogue contracts and storage](CATALOGUE.md) explain source origin and manual refresh. All 422 responses use the shared strict redacted ValidationFailure contract. `claim_checks` is enabled only for valid loaded knowledge, with `knowledge_version: claims-2026-10-06.1`; `knowledge_artifact` identifies a verified packaged two-file receipt or is null for direct local canonical loading/unavailable knowledge. `nutrition_analysis`, ingredient explanations, comparison and AI remain disabled.

`CatalogueStatus` reports `ready`, `not_configured` or `unavailable`, with nullable manifest/freshness/artifact and explicit field limits for the loaded store. Freshness is `within_refresh_window`, `refresh_due` or `source_date_in_future`; it uses nine calendar months from `exported_at`, not the build timestamp. Unconfigured/unavailable status returns 503 and claims no verified manifest. A ready but overdue catalogue remains readable with warnings. Existing `CatalogLookup` keys are unchanged; warnings remain within its 100-item bound. A 404 snapshot miss makes no upstream request. Catalogue status/identity/facts responses are `no-store`. The additive `catalogue_facts` capability is true only for a validated facts-enabled store. Older identity-only stores keep their old routes and return facts unavailable for a found identity.

`NormalizeRequest` contains schema `1`, UUID request/session IDs, bounded strict integer revision, actual boolean `confirmed: true`, completeness `complete`/`partial`, and 1–64 unique-ID nutrient rows. A row contains table ID, supported nutrient, finite nonnegative numeric value or null, compatible unit, basis and as-sold/as-prepared state. Quantity bases require positive amount plus `g`/`mL`; serving bases require both amount/unit or neither. Strings, booleans and nonfinite/precision-losing numeric tokens do not become nutrient values. All models forbid extra fields; no image/OCR/profile/secret fields are accepted.

The response echoes request/session/revision and normalization time, identifies `assessment_basis: user_confirmed_label`, and returns a `NutritionSnapshot`. OFF lookup identifies `assessment_basis: open_food_facts_community_data`, provider/date/licenses and each accepted packaging/manufacturer table. OFF estimates/computed sets/qualified values are excluded. At most 16 upstream tables and 64 accepted rows are processed; whole tables exceeding the row budget are omitted with warnings. Origins and separate tables are never merged.

A snapshot retains original rows, source-row IDs, preparation, original/normalized bases, canonical cells, conversion descriptions and warnings. Cells use kcal for energy and g for the other ten supported nutrient types. The adapter distinguishes available/total carbohydrates, total/added sugars and sodium/salt. Known mass/volume bases scale to per 100 g/per 100 mL within the same unit; no density or unknown portion size is inferred. Unknown serving size stays per serving. Missing cells remain null with a reason; zero remains zero.

`complete` means submitted rows normalized successfully with a complete submission declaration, not that every nutrient is known. Explicit unknowns/incomplete capture/unmeasured serving yield `partial`; contradictory duplicates or inconsistent table contexts yield `needs_correction`, preserving inputs. Comparable OFF tables with differing known values produce `provider_tables_disagree` and `needs_correction`, retaining both values without an invented rounding tolerance. These statuses are data-processing results, not food-quality, allergy or regulatory verdicts.

The actual body limit is 32 KiB before JSON parsing, including chunked transfers
(413). Validation failures have at most 32 redacted entries and `errors_truncated`.
Normalization/claims persist no scan/profile and log no content. Separate
community intake persists bounded public assertions and private staging/receipts;
images/raw OCR/profiles/history remain excluded. Exact-origin GET/POST CORS permits
Authorization but is not authentication. Writes use verified anonymous tokens
without a Share flag. No AI is enabled. [Storage lifecycle](COMMUNITY_CATALOGUE.md).


Use the [export/example index](../../contracts/README.md) for actual schema files and validated synthetic requests/responses. The facts route keeps `product` and `manifest` separate from `details`. Tags use availability plus values; nutrition distinguishes `direct_tables`, `missing`, `legacy_unsupported` and `invalid`. Only direct packaging/manufacturer tables are normalized; legacy aggregate nutrients remain unavailable. Dates and official selected-front image descriptors are optional. Image URL metadata includes language/revision/400-size and attribution/license; a descriptor does not guarantee present image availability. No photo bytes or arbitrary URL proxy is served.

Raw text interpretation, capture geometry, a full analysis report and health scoring remain outside this slice. v0.3.0 adds separate confirmed-label claim/rule/evidence APIs after the independently pushed and verified v0.2.3 release; [accepted plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md).

`ClaimsRequest` extends confirmed normalization with 1–16 unique identified claims, `selected_table_id` and food category/form/preparation context. Numerical scope covers seven fibre/sugar/sodium claims for ordinary general food and matching table context. High/source protein, no added sugar and multigrain remain recognized but unreviewed. One applicable fibre alternative can support a criterion; a contradiction requires every applicable alternative known and failing. Missing/conflicting/unsupported or future-dated evidence yields insufficient information. Results include row/region/rule/source references, knowledge version and numerical-only scope. Statutory fibre energy alternatives use original rows and 4.2 kJ/kcal with version `fssai-schedule-i-note2-v1`; the returned normalization-v1 snapshot retains 4.184. All three structured POST routes share checked numeric tokens, the 32 KiB body limit and redacted validation. Claim/rule/evidence reads use `no-store` and no external provider. [Detailed current criteria and synthetic integration pair](../../backend/README.md#reviewed-confirmed-label-claim-checks).

## Future endpoints

| Endpoint | Purpose | Output |
| --- | --- | --- |
| `POST /v1/analyze` | Backend evaluation of source-tagged OFF facts and/or confirmed package fields | Normalized product, assessed criteria, findings, evidence and neutral suitability facts |
| `GET /v1/ingredients/{ingredient_id}` | Explain a matched canonical ingredient | Reviewed bilingual content and references |

These routes, their access scopes and additional limits are implemented later. Metadata must not expose provider secrets. Public Gemini capability remains disabled until proper individual authentication for an eligible adult beta is in place. Validate token issuer, audience, signature, expiry and access allowlist; CORS is not authentication. A private development token may protect local tooling/LAN experiments, but must never be embedded in a distributed app or reused as public authentication.

No profile, image upload, scan-history, per-frame or generic chat endpoints are required. Client comparison charts can use existing normalized reports locally. A later backend comparison endpoint remains planned.

The implemented OFF endpoints are optional enrichment, not prerequisites for confirmed-value normalization or every future scan. Preserve barcode strings/leading zeros and any allowed upstream identity normalization. Keep source URL, retrieval time, available provider revision, adapter/schema version and attribution. Separate `found`, `not_found`, `rate_limited`, `unavailable` and `incompatible_response` from nutrition processing/future claim outcomes. Never treat a missing record/field as zero or absent allergen. Raw OFF response shapes stay behind the adapter. See [Open Food Facts](OPEN_FOOD_FACTS.md).

## Proposed input

| Field/group | Meaning |
| --- | --- |
| `schema_version`, `client_request_id` | Contract and duplicate-request correlation |
| `capture_session_id`, `input_revision` | Random session identifier and exact correction revision; no user/device identity |
| `paired_package_confirmed`, assessment basis | Confirmed front/back belong to the same package when captured; distinguish record-only from package-confirmed analysis |
| `front_regions`, `back_regions` | Stable region IDs, confirmed public text and side |
| `completeness` | Ingredient/nutrition/allergen/claim panels captured, partial or unreadable |
| `confirmed_fields` | Reviewed ingredients, claims, declarations and nutrient rows linked to region IDs |
| nutrient row | Decimal value or null, unit, basis amount/unit, as-sold/as-prepared state when declared |
| `output_language` | English or Hindi |
| `public_product_identity` | Optional visible product name/barcode/category |
| requested capability/version context | Requested criteria and the client's supported contract/knowledge versions |

Original OCR and corrections retain provenance locally; submit only the public fields needed for analysis. Images/coordinates remain local. Region IDs map findings to local OCR boxes. Do not invent OCR confidence when the adapter supplies none.

Corrections are user-confirmed label evidence, not independently verified truth. Conflicting fields require correction. No names, contact details, preference/allergy profiles, location, personal history or provider keys belong in a request.

## Proposed backend report and saved representation

| Field/group | Meaning |
| --- | --- |
| `schema_version`, `analysis_id`, `client_request_id`, `input_revision` | Contract/correlation and exact input revision |
| `analysis_status` | complete, partial or needs_correction; pipeline completion is not certainty for every claim |
| `evaluator_origin`, `evaluated_capabilities`, assessment basis | Backend evaluator, explicit reviewed criteria and OFF-record/package-confirmed origin |
| `knowledge_version`, `rule_set_version`, `analyzed_at` | Reproducibility/freshness |
| `normalized_product`, `ingredient_matches` | Confirmed values, canonical IDs, field references and unresolved information |
| `findings` | Stable rule/finding IDs, applicability, outcome, input references, rule version and source IDs |
| `neutral_suitability_facts`, `suitability_policy_version` | Declared/may-contain/unknown evidence and reviewed reason catalog; no personal profile |
| `nutrient_visualization_data` | Known values with units/bases; explicit unknowns |
| `evidence` | Publisher, URL, provision/page, effective/review dates and review status |
| `explanation_origin`, `warnings` | Reviewed template/optional validated AI/cache, incomplete data and fallback reason |

Claim outcomes are **supported**, **contradicted** or **insufficient_information**. Applicability and source-review state are separate. A nonapplicable category rule cannot produce a contradiction. Record-only findings describe available OFF facts; claims missing from the record/package remain unknown. No report guarantees complete legal compliance.

Unknown nutrients are null plus a reason, never zero. Preserve total/added sugar, sodium/salt and serving/100 g/100 mL distinctions. The client selects neutral reasons using local preferences while retaining all warnings.

## Processing and compatibility

1. Check `/v1/meta` before new online analysis; keep its result versioned and treat it as a snapshot.
2. Validate size, contract, assessment basis, field origins and correction revision. If a barcode is supplied, resolve the bounded OFF read through the backend adapter; package-confirmed corrections take priority over community facts.
3. Normalize available fields and match canonical identifiers without filling missing values.
4. Select reviewed applicable rules; compute findings/neutral facts with input and source provenance.
5. Retrieve approved public evidence and render reviewed English/Hindi templates.
6. If explicitly allowed, request an optional public-product Gemini rewrite; validate immutable numbers, outcomes and permitted references, otherwise retain templates.
7. Return the report without persisting a user scan/profile; reject stale responses on the client.

Python is the main rule evaluator; no Dart rule engine is required. Saved reports can be viewed offline without a handshake, retaining their original input/evidence dates and criteria/version. Fresh lookup and analysis need the backend. Do not combine incompatible reports or relabel saved findings as fresh checks.

## Recovery and limits

| Condition | Behavior |
| --- | --- |
| Invalid input/unsupported contract | 400 or validation 422 with stable field/error codes |
| Missing/invalid required individual auth | 401/403; no provider configuration disclosed |
| Oversized input | 413 before provider work |
| Partial label/unsupported rule | 200 partial report with explicit unknowns and capture/scope guidance |
| Ambiguous critical field | 200 needs_correction; no assumed outcome |
| Incompatible knowledge/policy | Compatibility warning; suppress affected merged findings/reasons |
| Backend not ready/rate limited | 503/429 with bounded retry guidance; keep drafts and saved reports; defer new analysis |
| Gemini quota/timeout/invalid output | Successful deterministic report with template fallback |
| Product lookup unavailable | Optional enrichment unavailable; confirmed label analysis continues |
| Network timeout/stale response | Keep local draft/saved data, discard stale result, defer fresh analysis and offer bounded retry |

Bound request sizes, concurrency, timeouts and retries. Never multiply API keys to bypass project quotas. Optional public explanation caches must include label/language/evidence/rule/policy/provider versions. Vercel memory and `/tmp` caches/counters are disposable and cannot enforce durable shared budgets; cache misses must remain safe and functional.
