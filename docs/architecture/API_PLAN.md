# Frontend/backend API plan

Released production **v0.5.0** has eighteen mounted routes, exported in
`contracts/schemas/backend-v0.5.0.openapi.json`. It was independently reviewed,
pushed, hosted-verified and published after v0.4.0. The fifteen earlier routes
retain their contracts; three additive APIs provide current/historical reports
and a partial reviewed glossary. [Twenty hosted checks](../research/BACKEND_V0_5_0_PRODUCTION.json)
verify this release independently. [Report contract](LABEL_REPORT.md) ·
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
| `POST /v1/reports/check` | Useful report from corrected confirmed observation without mandatory barcode/auth; automatic storage has a separate outcome |
| `GET /v1/products/{barcode}/report` | Read-only sourced historical report; no current-label claim assessment; partial source outage stays useful |
| `GET /v1/ingredients/glossary` | Three reviewed English/Hindi name/function entries and source/hash artifact; unavailable glossary returns typed 503 |

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


Metadata enables product lookup, nutrition lookup and nutrition normalization. Its `catalogue` value uses `CatalogueStatus`; catalogue lookup requires a validated configured index and hosted configuration also requires a verified build receipt. The [v0.4.0 review](../planning/BACKEND_V0_4_0_REVIEW.md) records published community/source/cloud/hosted gates; the [v0.2.3 review](../planning/BACKEND_V0_2_3_REVIEW.md) preserves catalogue history; [catalogue contracts and storage](CATALOGUE.md) explain source origin and manual refresh. All 422 responses use strict redacted ValidationFailure. `claim_checks` requires valid loaded knowledge, with `knowledge_version: claims-2026-10-06.1`; `knowledge_artifact` identifies a verified packaged receipt or is null for direct local canonical loading/unavailable knowledge. Released v0.5.0 enables `nutrition_analysis` and `label_reports` with `report_version: label-report-v1`; `ingredient_explanations` requires a valid loaded three-entry glossary. Glossary version/artifact and claim readiness remain independent. Comparison and AI stay disabled.

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

Raw text interpretation, capture geometry and universal health scoring remain outside this slice. Released v0.5.0 composes existing structured facts into a useful sourced report; [report contract](LABEL_REPORT.md). The independently released v0.3.0 claim/rule/evidence APIs remain intact; [historical accepted plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md).

`ClaimsRequest` extends confirmed normalization with 1–16 unique identified claims, `selected_table_id` and food category/form/preparation context. Numerical scope covers seven fibre/sugar/sodium claims for ordinary general food and matching table context. High/source protein, no added sugar and multigrain remain recognized but unreviewed. One applicable fibre alternative can support a criterion; a contradiction requires every applicable alternative known and failing. Missing/conflicting/unsupported or future-dated evidence yields insufficient information. Results include row/region/rule/source references, knowledge version and numerical-only scope. Statutory fibre energy alternatives use original rows and 4.2 kJ/kcal with version `fssai-schedule-i-note2-v1`; the returned normalization-v1 snapshot retains 4.184. All structured POST routes share checked numeric tokens, the 32 KiB body limit and redacted validation. Claim/rule/evidence reads use `no-store` and no external provider. [Detailed current criteria and synthetic integration pair](../../backend/README.md#reviewed-confirmed-label-claim-checks).

## Current report integration

Use the exported `ReportCheckRequest` and `LabelReport` models described in the
[report guide](LABEL_REPORT.md). Submit a corrected confirmed observation, with
optional barcode, selected table and applicability context. The current report
uses `user_confirmed_label`; the read-only barcode report uses
`catalogue_historical` and does not reassess historical claims as current label
proof. Missing barcode or front/back pairing does not block useful private
analysis, but automatic public candidate eligibility remains stricter.

The current report retains original nutrition, source/row references, declarations,
missing inputs and warnings. Total sugar uses approximate `sugar-cubes-4g-v1`
with the original quantity/serving basis and preparation; zero stays zero and
unknown/conflicting sugar gets no fabricated cube count. Three reviewed glossary
entries supply English/Hindi names and technological functions only. They do not
establish health, allergy or Indian regulatory permission.

Analysis requires no account. The only app identity role is the scanner/client;
automatic anonymous Firebase auth enables factual writes behind the scenes.
There is no admin/reviewer app login, role or dashboard. The backend service
account is a machine credential. Current reports attempt automatic saving after
analysis and retain HTTP 200 with a separate `storage` outcome when token, quota,
reference or storage problems prevent saving. No Share flag is accepted. GET
reports have read-only storage. Photos/raw OCR/profiles/history stay private.
Physically implausible or internally contradictory nutrient quantities retain
the report with correction guidance and `storage: needs_correction`; they do not
enter the shared catalogue until corrected.

## Processing and compatibility

1. Check `/v1/meta` before new online analysis; retain its versions and independent
   report, claim, glossary and source readiness.
2. Validate body size, strict numeric values, origins and correction revision.
   Current reports use submitted confirmed facts; a barcode does not silently
   replace them with provider values.
3. Normalize rows without filling missing cells, guessing density or combining
   incompatible table contexts. Select the confirmed table/context for numerical
   claims; unavailable knowledge or missing required inputs affect that section.
4. Render source-qualified current or historical fields, warnings, missing inputs
   and the separate storage outcome. Correlate request/session/revision on the
   client and discard stale responses.
5. Store saved reports/history locally with their original evidence dates and
   versions; viewing them does not refresh facts or reevaluate criteria.

Python owns reviewed claim evaluation; no second Dart regulatory engine is
required. Raw OFF shapes stay behind the adapter. Preserve leading-zero barcode
strings, provider origin/dates/licenses and unavailable states. A snapshot miss
makes no automatic live OFF request. [OFF adapter](OPEN_FOOD_FACTS.md).

## Recovery and limits

| Condition | Actual report behavior |
| --- | --- |
| Invalid input or unsupported contract | Redacted 422 with stable field/error codes |
| Actual body exceeds 32 KiB | 413 before parsing/provider work |
| Partial label, unsupported rule or missing claim context | Useful HTTP 200 partial report with explicit missing inputs |
| Missing/invalid anonymous token, quota or storage failure | Current report remains HTTP 200; typed independent storage outcome |
| Missing/invalid glossary or claim knowledge | Suppress only the unavailable section; keep usable label facts |
| One historical source unavailable | HTTP 200 when the other source found facts, retaining unavailable provenance |
| Both exact sources definitely missing | Historical report HTTP 404 |
| No useful historical source and a source unavailable | Historical report HTTP 503 |
| Glossary projection unavailable | Glossary endpoint typed HTTP 503 |
| Client network timeout or stale response | Retain local draft/saved data; bounded retry with immutable request IDs |

All report/glossary responses use `no-store`. Anonymous tokens never authorize
claim truth or regulatory trust. Quota admission bounds application operations;
free-tier availability is finite. Never multiply keys to bypass provider quotas.

## Remaining API scope

Bounded discovery and compatible comparison remain future versions in the
[master plan](../planning/MASTER_PLAN.md). Wider ingredient details need reviewed
coverage before new endpoints. Current reports use the three implemented APIs;
a duplicate generic analyze endpoint is unnecessary. No profile/image-upload,
scan-history, per-frame or generic-chat endpoint is required. Camera/OCR,
correction, source views, saved/history and frontend report UI remain client work.
Gemini/custom training are disabled; any later fallback requires a measured
benchmark and no-card/privacy controls before acceptance.
