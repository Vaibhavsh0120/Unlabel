# Frontend/backend API plan

Updated **13 October 2026** for the canonical [backend](../../backend/pyproject.toml)
and [frontend](../../frontend/pubspec.yaml) versions. Current OpenAPI is
[backend-v0.12.1.openapi.json](../../contracts/schemas/backend-v0.12.1.openapi.json):
**27 paths / 28 operations**, with existing wire shapes preserved. Historical
exports remain immutable. Current auth/profile and Google compatibility await
final exact-source hosted/native verification. Authenticated extraction/staging
and physical-device accuracy remain separate. [Contracts](../../contracts/README.md) ·
[Backend review](../planning/BACKEND_V0_12_1_REVIEW.md) ·
[Frontend review](../planning/FRONTEND_V0_8_0_REVIEW.md).

## Historical research checkpoint — backend v0.10.0

Research database checkpoint (8 October 2026): backend **v0.10.0** adds a
separate generated read-only SQLite with **243 observations** (49 manufacturer,
125 retailer and 69 OFF). It preserves dated sources, unknown identities and
formula conflicts. Three additive GETs expose researched product search,
`by-barcode/{barcode}` and `{entry_id}` under `/v1/researched/products`.
The historical v0.10.0 export has 24 paths/25 operations and 29 synthetic examples.
Source normalization does not import the runtime; `scripts/build_research_catalogue.py`,
the backend deployment build and `scripts/setup.py --catalogue-only` do. Runtime
files live in ignored `backend/app/research_catalogue/data/`. Frontend **v0.5.0+6**
adds mixed-source search and qualified ingredient/nutrition/source details.
Local verification and hosted/push status: [backend review](../planning/BACKEND_V0_10_0_REVIEW.md) ·
[frontend review](../planning/FRONTEND_V0_5_0_REVIEW.md) ·
[product list](../research/POPULAR_PRODUCTS_ADDED.md).
The subsequent automatic-capture/results implementation is recorded in the
[automatic scan plan](../planning/AUTOMATIC_SCAN_PLAN.md).
Earlier release statements below retain their historical scope.


## Historical comparison/glossary checkpoint — 8 October 2026

Frontend v0.3.0+4 is independently published
and hosted-verified; backend v0.8.0 is pushed and hosted-verified at exact
implementation `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` with 25 checks.
Its source-release publication is not established by that receipt.
Work at that checkpoint was backend v0.9.0 Reviewed Ingredient Functions and frontend
v0.4.0+5 Sourced Comparison and Ingredient Detail. Independent review, tests,
push and hosted evidence remain in the corresponding historical component reviews.
Guests keep personal records local; optional password accounts use private
UID-specific sync, separately from public package facts. Capture/local OCR
are implemented; physical-device accuracy, live barcode decoding, highlights,
notifications and personal suitability remain separate future gates.

Historical export: `contracts/schemas/backend-v0.9.0.openapi.json`, 21 paths /
22 operations and 29 synthetic examples. Existing private sync and comparison
paths stay compatible; glossary entry enums/counts expand to six. Historical
versioned OpenAPI is preserved. [Contracts](../../contracts/README.md).

## Implemented endpoints and nutrition contract

| Endpoint | Actual behavior |
| --- | --- |
| `GET /v1/account/sync` | Password-authenticated caller-owned private snapshot; 384 KiB data, 50 saved/100 history, no UID/email/photo/OCR fields |
| `POST /v1/account/sync` | Strict CAS revision and immutable UUID retry; changed cloud state returns conflict; empty snapshots retain revision |
| `GET /v1/health` | Ready/version; provider connectivity explicitly not checked |
| `GET /v1/meta` | API/contract/product-adapter/nutrition-adapter/normalization versions and capabilities |
| `GET /v1/products/{barcode}` | Unchanged typed OFF identity/ingredient/tag/computed-grade lookup |
| `GET /v1/products/{barcode}/nutrition` | Separate OFF direct-input nutrition lookup with community origin and table source metadata |
| `POST /v1/nutrition/normalize` | Structured user-confirmed nutrient normalization, independent of OFF connectivity |
| `GET /v1/catalogue/search` | Bounded Unicode name/brand identity candidates with exact barcode keys, refinement/miss/unavailable states and query/snapshot/options-bound cursor; no OFF request |
| `GET /v1/catalogue` | Typed status/manifest, source-age policy, receipt artifact summary and excluded-field limits; 503 when not ready |
| `GET /v1/catalogue/products/{barcode}` | Optional exact indexed lookup with separate export manifest, no OFF call; 503 when inactive |
| `GET /v1/catalogue/products/{barcode}/facts` | Separate strict rich-facts model: direct nutrition, tag availability, record date and official image URL; exact snapshot origin |
| `POST /v1/claims/check` | Strict identified claims plus one selected confirmed nutrition table and applicability context; reviewed numerical outcomes |
| `GET /v1/claims/rules` | Seven reviewed fibre/sugar/sodium rules, four recognized unsupported claims and knowledge readiness/version |
| `GET /v1/evidence/{source_id}` | Public metadata for three reviewed sources; unknown ID 404, unavailable knowledge 503, no PDF request |
| `POST /v1/reports/check` | Useful report from corrected confirmed observation without mandatory barcode/auth; automatic storage has a separate outcome |
| `GET /v1/products/{barcode}/report` | Read-only sourced historical report; no current-label claim assessment; partial source outage stays useful |
| `GET /v1/ingredients/glossary` | Six reviewed English/Hindi name/function entries and independent source/hash artifact; unavailable glossary returns typed 503 |
| `POST /v1/reports/compare` | Read-only comparison of exact selected source tables on compatible bases; no universal healthier verdict |
| `GET /v1/researched/products/search` | Bounded search across the independent 243-observation research catalogue |
| `GET /v1/researched/products/by-barcode/{barcode}` | Exact known-barcode research observations, without fabricated identities |
| `GET /v1/researched/products/{entry_id}` | Qualified source facts, original pack/date/unknowns and separately validated image descriptors |
| `POST /v1/ai/extract` | Consented scanner-authenticated photo extraction, bounded unverified facts and independent private staging outcome |
| `GET /v1/ai/active` | Machine-authenticated global credential selection/status; no scanner key access |
| `POST /v1/ai/control/activate` | Machine-authenticated CAS selection of a configured server credential |

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


Metadata enables product lookup, nutrition lookup and nutrition normalization. Its `catalogue` value uses `CatalogueStatus`; catalogue lookup requires a validated configured index and hosted configuration also requires a verified build receipt. The [v0.4.0 review](../planning/BACKEND_V0_4_0_REVIEW.md) records published community/source/cloud/hosted gates; the [v0.2.3 review](../planning/BACKEND_V0_2_3_REVIEW.md) preserves catalogue history; [catalogue contracts and storage](CATALOGUE.md) explain source origin and manual refresh. All 422 responses use strict redacted ValidationFailure. `claim_checks` requires valid loaded knowledge, with `knowledge_version: claims-2026-10-06.1`; `knowledge_artifact` identifies a verified packaged receipt or is null for direct local canonical loading/unavailable knowledge. Released v0.5.0 enables `nutrition_analysis` and `label_reports` with `report_version: label-report-v1`; `ingredient_explanations` requires a valid loaded six-entry glossary. Glossary version/artifact and claim readiness remain independent. Backend comparison is enabled independently of catalogue/glossary/cloud readiness
with `sourced-nutrient-comparison-v1`; the client consumes exact source/table
references. Optional AI readiness is independent and exposed only when `AI_ENABLED` and its required runtime/configuration are available. [AI admission/privacy](AI_ROUTING.md).

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
Authorization but is not authentication. Public writes accept verified anonymous,
password or Google scanner tokens; private library sync requires password/Google
authentication. The separate owner-only profile-media document grants no direct
access to backend collections or additional API payload fields.
Public observations save automatically without a Share flag. Optional consented extraction uses the separate authenticated AI route and does not alter these confirmed/public admission rules.
[Storage lifecycle](COMMUNITY_CATALOGUE.md).


Use the [export/example index](../../contracts/README.md) for actual schema files and validated synthetic requests/responses. The facts route keeps `product` and `manifest` separate from `details`. Tags use availability plus values; nutrition distinguishes `direct_tables`, `missing`, `legacy_unsupported` and `invalid`. Only direct packaging/manufacturer tables are normalized; legacy aggregate nutrients remain unavailable. Dates and official selected-front image descriptors are optional. Image URL metadata includes language/revision/400-size and attribution/license; a descriptor does not guarantee present image availability. No photo bytes or arbitrary URL proxy is served.

Raw text interpretation and capture geometry remain outside the preserved confirmed normalization/claim slice; optional extraction handles bounded unverified fields separately. Universal health scoring remains outside the product. Released v0.5.0 composes existing structured facts into a useful sourced report; [report contract](LABEL_REPORT.md). The independently released v0.3.0 claim/rule/evidence APIs remain intact; [historical accepted plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md).

`ClaimsRequest` extends confirmed normalization with 1–16 unique identified claims, `selected_table_id` and food category/form/preparation context. Numerical scope covers seven fibre/sugar/sodium claims for ordinary general food and matching table context. High/source protein, no added sugar and multigrain remain recognized but unreviewed. One applicable fibre alternative can support a criterion; a contradiction requires every applicable alternative known and failing. Missing/conflicting/unsupported or future-dated evidence yields insufficient information. Results include row/region/rule/source references, knowledge version and numerical-only scope. Statutory fibre energy alternatives use original rows and 4.2 kJ/kcal with version `fssai-schedule-i-note2-v1`; the returned normalization-v1 snapshot retains 4.184. Public structured POST routes share checked numeric tokens, the 32 KiB body limit and redacted validation. Private account sync has its own 512 KiB actual request-body cap and 384 KiB serialized data cap. Claim/rule/evidence reads use `no-store` and no external provider. [Detailed current criteria and synthetic integration pair](../../backend/README.md#reviewed-confirmed-label-claim-checks).

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
unknown/conflicting sugar gets no fabricated cube count. Six reviewed glossary
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
| Public structured report/claim body exceeds 32 KiB | 413 before parsing/provider work; private sync and consented AI extraction have separate caps |
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

## Current scope and remaining gates

Captured barcode reading, local OCR, consented optional cloud extraction,
source-linked ingredient detail and exact-source comparison are implemented.
Ordinary report/product/account requests exclude photos; `/v1/ai/extract` is the
explicitly consented exception. Photo/raw OCR content is never account sync or
public package evidence. Machine extraction is not a generic chat/analysis route.

Reports preserve independent storage outcomes; no duplicate generic analyze
endpoint is needed. Private snapshots remain on `/v1/account/sync`. The latest
Insights collection is bundled client content with local bookmarks, requiring no
new backend route. Broader ingredients, continuous live decoding/highlights,
notifications and personal suitability remain tracked in the
[feature tracker](../planning/FEATURE_TRACKER.md). Native accuracy, response time,
authenticated hosted generation/staging and current frontend hosted proof are
separate validation gates. No custom training or Firebase billing is introduced.
