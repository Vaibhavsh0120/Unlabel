# Unlabel backend: v0.12.0

Latest hosted recheck: the unchanged backend at frontend v0.6.1 source
`48b6f3e4632afb6565ac4261dc923f8b61e5cbdf` is READY at
`dpl_2ZYY8isvWLkWdBkbeW7c2wco4fkU`, with all **389 checks** passing again.
[Current receipt](../docs/research/BACKEND_V0_12_0_FRONTEND061_PRODUCTION.json).
The preceding deployment identity below remains historical evidence.

The private unverified AI fact staging, ingredient/declaration/claim search terms
and separate researched-product image descriptors are pushed and deployed.
The preceding production was READY at `dpl_7XRdiDVSWKH9pEnLv4Nik699tEtf`, from repository source
`6403517b11ea150cd43fdf37469911a5aaafa926`; its backend code is unchanged from
implementation commit `39e600e13cf38f57b34a1e1727dfa4a10d9f24e7`.
All **389 hosted checks** passed, including source equality for all 243 research
observations and 120 image descriptors. Authenticated AI generation and private
staging writes are outside this read-only audit.
[Review](../docs/planning/BACKEND_V0_12_0_REVIEW.md) ·
[Production receipt](../docs/research/BACKEND_V0_12_0_PRODUCTION.json).

The preceding v0.11.0 source `578a9afebae8f77fe98344233cdc9155e82bb37a` is pushed,
with READY deployment `dpl_GYRcK2j22N2gY24Hsxk5pi8UH8rA` and 389 read-only public/API
checks. Authenticated hosted AI generation/failover remains unexercised.
[Production receipt](../docs/research/BACKEND_V0_11_0_PRODUCTION.json).

Automatic extraction checkpoint (8 October 2026): backend **v0.11.0** adds
bounded Gemini/OpenAI photo reading with exactly one globally active credential,
sticky failure replacement and scanner authentication. **1,303 tests pass**, with
five explicit provider/emulator skips. Keys are server-only; AI facts remain
unverified and photos stay outside database/account sync. Public hosted verification
passes; authenticated hosted extraction remains separate. These tests describe v0.11.0, not later working-tree edits.
[Backend review](../docs/planning/BACKEND_V0_11_0_REVIEW.md) ·
[Automatic scan plan](../docs/planning/AUTOMATIC_SCAN_PLAN.md).

The selected storage remains a verified read-only SQLite public catalogue plus
Firestore mutable observations/accounts/AI selection and bounded private machine
proposals. New sourced data is
validated and rebuilt into SQLite; no existing dataset is deleted or migrated.

Research database checkpoint (8 October 2026): backend **v0.10.0** adds a
separate generated read-only SQLite with **243 observations** (49 manufacturer,
125 retailer and 69 OFF). It preserves dated sources, unknown identities and
formula conflicts. Three additive GETs expose researched product search,
`by-barcode/{barcode}` and `{entry_id}` under `/v1/researched/products`.
The exported API now has 24 paths/25 operations and 29 synthetic examples.
Source normalization does not import the runtime; `scripts/build_research_catalogue.py`,
the backend deployment build and `scripts/setup.py --catalogue-only` do. Runtime
files live in ignored `backend/app/research_catalogue/data/`. Frontend **v0.5.0+6**
adds mixed-source search and qualified ingredient/nutrition/source details.
Local verification and hosted/push status: [backend review](../docs/planning/BACKEND_V0_10_0_REVIEW.md) ·
[frontend review](../docs/planning/FRONTEND_V0_5_0_REVIEW.md) ·
[product list](../docs/research/POPULAR_PRODUCTS_ADDED.md).
The user's next automatic-capture/results redesign is recorded in the
[automatic scan plan](../docs/planning/AUTOMATIC_SCAN_PLAN.md).
Earlier release statements below retain their historical scope.


v0.9.0 expands the reviewed English/Hindi ingredient glossary to six entries,
preserving the historical projection and adding strict own-source, alias, INS
and content validation. Evidence models returned to callers are independent
copies. Coverage remains partial and describes technological functions only.
[Current review](../docs/planning/BACKEND_V0_9_0_REVIEW.md) ·
[Reviewed ingredient sources](../docs/research/INGREDIENT_GLOSSARY_V0_9_0.md).

Earlier v0.8.0 added the read-only `POST /v1/reports/compare` contract to the independently
published v0.7.0 backend. The working source exports **21 paths / 22 operations**
and **29 validated synthetic examples**. It compares a selected nutrition table
from each of two confirmed labels or exact historical source references, retaining
original rows, source dates, unknowns and disagreements. It provides signed
nutrient differences, without a winner, health score or safety verdict.
[v0.8.0 review](../docs/planning/BACKEND_V0_8_0_REVIEW.md) ·
[Comparison contract](../docs/architecture/SOURCED_COMPARISON.md).

Historical v0.8.0 local validation passed **975 tests with five emulator-only skips**; Ruff was clean
and application Pyright reports zero errors/warnings. Subsequent body-limit wording,
chunked-limit assertions and type narrowing passed the 25 affected comparison
tests with clean Ruff/Pyright. Its exact implementation `1a2fd25` is pushed and
hosted-verified with 25 checks; source-release publication is not established by
the receipt. v0.9.0 receives its own current validation and deployment checks.
Earlier deployment receipts below establish their recorded releases only.

## Published v0.7.0 evidence

v0.7.0 implementation source `9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0`
is independently published and hosted on READY deployment
`dpl_5TNPc4yuis3tdLJ114jacroGvbvh`, after the independently published
v0.6.0 Product Discovery. **20 paths / 21 operations** preserve all public
contracts and add optional password-authenticated private profile/saved/history
sync. Guests keep personal records locally; public package observations remain
automatic and separate.

Fresh closure validation on 7 October passed **931 tests with five emulator-only
skips** in 25.47 seconds, with clean Ruff and root-configured Pyright reporting
zero errors/warnings. Separate local-API/live-Firebase checks and the
[hosted production receipt](../docs/research/BACKEND_V0_7_0_PRODUCTION.json)
each record **18 synthetic checks**. The hosted checks used two password identities
and one anonymous identity to test ownership, anonymous rejection,
CAS/retry/conflict, versioned clearing and no-store behavior. Test identities were
deleted and private report snapshots cleared; empty revision-protection documents
and bounded counters remain. Email/password Auth was enabled without adding
billing. Local `.env` changes were encrypted into `.env.age`. Backend v0.7.0 is
published at [the verified source tag](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.7.0).
Documentation closure commit `ec70568` also reached READY without API source changes. A later documentation-only
closure commit does not replace the original implementation SHA; any new deployment
needs its own exact-commit verification.
[Published v0.7.0 review](../docs/planning/BACKEND_V0_7_0_REVIEW.md) ·
[Private sync contract](../docs/architecture/PRIVATE_ACCOUNT_SYNC.md).

API: [unlabel-api.vercel.app](https://unlabel-api.vercel.app) ·
[Swagger](https://unlabel-api.vercel.app/docs). Firebase remains free with no
card/linked billing. Frontend v0.2.0+3 is independently published; its source and
hosted evidence are recorded in the
[Frontend release review](../docs/planning/FRONTEND_V0_2_0_REVIEW.md).
Frontend v0.3.0+4 screen, local OCR and performance work has its own release gates.
Profile remains at the top right of the existing four-tab app shell. Backend-only
work does not rebuild APK/IPA artifacts.

## Run locally

Recommended from root: `./scripts/setup.ps1 -Scope backend`, then `./scripts/run-local.ps1 -Scope backend`. Python equivalents: `python scripts/setup.py --scope backend`, then `python scripts/run_local.py --scope backend`. Setup regenerates the catalogue from committed data and offers encrypted env restoration. The runner supplies local catalogue/CORS settings without rewriting `.env`. [Clone guide](../docs/planning/LOCAL_DEVELOPMENT.md). Manual installation follows.

Python 3.12+; commands from `backend/`:

~~~powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
Copy-Item .env.example .env  # only if .env does not already exist
.venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
~~~

On macOS/Linux use `.venv/bin/python` instead. Use runtime-only `requirements.txt` when tests/tooling are unnecessary. Swagger is at `http://127.0.0.1:8000/docs`; OpenAPI is `/openapi.json`. A device's localhost is that device, not the laptop; later private-LAN testing needs a deliberate reachable host binding and firewall setup.

## Current endpoints

| Endpoint | Behavior |
| --- | --- |
| `GET /v1/account/sync` | Verified password account owns its private snapshot; anonymous clients rejected; no caller UID |
| `POST /v1/account/sync` | Bounded profile/saved/history CAS replacement and UUID retries; conflicts explicit; versioned empty clearing |
| `GET /v1/health` | Backend readiness/version; external provider connectivity explicitly not checked |
| `GET /v1/meta` | Backend/API/schema/adapter/normalization versions; product lookup, nutrition lookup and normalization enabled |
| `GET /v1/products/{barcode}` | Fixed OFF v3.6 product read; stable typed source-tagged response |
| `GET /v1/products/{barcode}/nutrition` | Separate source-tagged direct-input nutrition tables; strict product lookup v1 remains unchanged |
| `POST /v1/nutrition/normalize` | Normalize user-confirmed structured nutrient rows without calling OFF |
| `GET /v1/catalogue` | Ready/unavailable/not-configured status, manifest, artifact hash/size, source age, refresh date and field limits; 503 if unavailable |
| `GET /v1/catalogue/search` | Bounded name/brand/quantity-word candidates; exact last-word prefix, dated source, pagination and broad-query refinement; no OFF request |
| `GET /v1/catalogue/products/{barcode}` | Separate export-origin indexed identity lookup; 503 when catalogue is inactive/unavailable |
| `GET /v1/catalogue/products/{barcode}/facts` | Exact identity/manifest plus optional rich facts; older identity-only catalogues report facts unavailable |
| `POST /v1/claims/check` | Check identified claims against one selected user-confirmed nutrition table and explicit applicability context |
| `GET /v1/claims/rules` | Seven reviewed numerical rules, four recognized unsupported claim types, knowledge version and statutory energy conversion |
| `GET /v1/evidence/{source_id}` | Public reviewed source metadata; found, not-found or unavailable without fetching a PDF |
| `POST /v1/reports/check` | Useful current report from confirmed structured facts; automatic public saving has a separate outcome |
| `POST /v1/reports/compare` | Read-only exact-reference comparison of two selected compatible tables; unknown/conflict states retained |
| `GET /v1/products/{barcode}/report` | Read-only sourced historical report, without current-label claim confirmation |
| `GET /v1/ingredients/glossary` | Six reviewed English/Hindi ingredient names/functions and source metadata |

Four additive routes are mounted in v0.4.0:

| Endpoint | Behavior |
| --- | --- |
| `POST /v1/community/contributions` | Authenticated automatic provisional/confirmed intake and private receipt |
| `GET /v1/community/contributions/{submission_id}` | Authenticated caller-owned receipt |
| `GET /v1/community/products/{barcode}` | Public exact candidate/approved facts |
| `GET /v1/products/{barcode}/resolved` | Typed sourced fields, originals, conflicts and unknowns |

Safe defaults disable community storage. Resolved lookup still returns available
OFF snapshot facts with community marked unavailable. Neither source available
returns 503. Historical hosted verification is recorded in the separate
version-specific release reviews; future deployments require their own checks.
[Community lifecycle](../docs/architecture/COMMUNITY_CATALOGUE.md).

Barcodes are ASCII digit strings of 8, 12, 13 or 14 characters. Preserve leading zeros. GTIN checksum validity is not asserted; other provider-specific code formats are outside this version. Live OFF lookup identity must match the requested code, permitting leading-zero normalization only. Catalogue lookups use exact keys; leading-zero variants remain distinct.

~~~powershell
Invoke-RestMethod http://127.0.0.1:8000/v1/meta
Invoke-RestMethod http://127.0.0.1:8000/v1/products/3017620422003
Invoke-RestMethod http://127.0.0.1:8000/v1/products/3017620422003/nutrition
~~~

| HTTP | Lookup status | Meaning |
| --- | --- | --- |
| 200 | `found` | Available community facts, which may still be sparse |
| 404 | `not_found` | No provider record; not a food safety verdict |
| 429 | `rate_limited` | Upstream quota response; no automatic retry |
| 503 | `unavailable` | Provider/network/redirect unavailable; defer lookup |
| 502 | `incompatible_response` | Malformed/oversized data or mismatched product identity |
| 422 | FastAPI validation error | Unsupported barcode input; no provider call |

The unchanged product response has name/brands/quantity text, ingredient text, source-tagged allergen/trace tags and optional OFF Nutri-Score grade/NOVA group. Missing strings/grades are null; absent tags do not prove allergen absence. Source metadata contains provider, URL, retrieval time, available modification/schema version, attribution and licenses. This identity route exposes no raw provider internals or image fields; the separate snapshot facts route can expose a validated official image URL descriptor. Product/nutrition responses use `Cache-Control: no-store`; guest saved results stay on the client; optional password accounts use the separate private sync contract.

## Snapshot rich facts

Use `/v1/meta.capabilities.catalogue_facts` before requesting `/v1/catalogue/products/{barcode}/facts`. The response keeps the old `product` identity and export `manifest`, and adds a separate `details` model. Exact catalogue keys preserve leading zeros; image disk paths follow OFF's canonical code normalization independently of identity lookup.

`details.categories`, `labels`, `allergens` and `traces` pair `availability: available|missing|invalid` with bounded values. A present empty tag list differs from a missing field, but neither establishes absence of allergens. `provider_schema_version` and `last_modified_at` are optional source values, distinct from export/index/request dates.

`details.nutrition.availability` is `direct_tables`, `missing`, `legacy_unsupported` or `invalid`. Direct packaging/manufacturer tables use the same bounded parser and normalizer as live nutrition, with separate export provenance. Legacy aggregate nutrients are not reclassified as direct label tables. Preserve unknown cells, warnings, preparation, original bases and row/table sources.

`details.image` is null or a validated official selected-front 400-size URL descriptor with language, revision, optional dimensions, attribution and CC-BY-SA-3.0 metadata. URLs are constructed from selected-image metadata; arbitrary URLs, image proxies and bytes are excluded. Show attribution and an image fallback. A valid descriptor does not guarantee the remote image currently exists. OFF's [official image-path implementation](https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/lib/ProductOpener/Products.pm) strips leading zeros, pads short codes and splits the resulting path; catalogue identity still matches the exact requested key.

A missing snapshot record returns dated 404 with its checked manifest; inactive/invalid or older identity-only facts storage returns 503. Older stores keep their previous identity/status routes. Responses are `no-store`; lookup never calls OFF or silently substitutes live facts. The separate claims API accepts confirmed rows; it does not turn community tags or snapshot nutrition into an automatic current-package verdict. Health scoring remains unimplemented.

## Nutrition facts and confirmed input

Nutrition lookup uses OFF v3.6 `nutrition.input_sets`, accepting only `packaging` or `manufacturer` sources with a supported declared basis/preparation. It excludes computed sets, estimated sources, qualified values such as `<`, and entries without a direct `value`. Invalid/unsupported entries produce warnings or unknowns. The adapter accepts at most 16 input tables and 64 rows; a table that would exceed the row budget is omitted as a whole with `nutrition_row_budget_exceeded`. These limits deliberately do not promise every field from a product record. See [verified upstream research](../docs/research/OFF_NUTRITION_V3_6.md).

The lookup wrapper identifies `assessment_basis: open_food_facts_community_data`, OFF source/date/licenses, and each accepted table's packaging/manufacturer source. Confirmed input uses a different wrapper, `assessment_basis: user_confirmed_label`; confirmation is a user action, not independent verification. These responses do not merge origins.

The POST request requires:

- `schema_version: "1"`, UUID `client_request_id`/`capture_session_id`, strict integer `input_revision`, and real boolean `confirmed: true`.
- `completeness: complete` or `partial`, plus 1–64 nutrient rows with unique bounded ASCII `row_id` values and bounded `table_id` values.
- Each row's `nutrient`, finite nonnegative numeric `value` or null, `unit`, `basis`, and `preparation: as_sold` or `as_prepared`.
- A quantity basis has positive amount and `g`/`mL` unit. A serving has both amount/unit or both null. Unknown serving size stays per serving.

Canonical cells support energy, fat, saturated fat, available carbohydrates, total carbohydrates, total sugars, added sugars, fibre, protein, sodium and salt. Energy uses kcal (`kJ / 4.184`); other nutrients use g (`mg / 1000`, `ug / 1,000,000`). Known mass/volume bases scale within their own unit to per 100 g/per 100 mL. The response retains original rows, source row IDs, table preparation, original/normalized bases, conversion text and warnings. No density, serving size, added sugar or salt/sodium relationship is inferred.

`snapshot.status` is `complete`, `partial` or `needs_correction`. **Complete means the submitted rows normalized successfully with a complete submission declaration; it does not mean all nutrients are known.** Unreported cells are null with `not_reported`; explicit unknowns remain distinct from zero. Conflicting duplicates and inconsistent contexts for one table ID require correction, retaining the original inputs without choosing a winner. Comparable OFF tables that disagree produce `provider_tables_disagree` and `needs_correction`, preserving both tables/numbers. No rounding tolerance is assumed. Numeric conversion overflow/underflow returns unknown correction cells. Separate tables are preserved.

The POST actual body limit is **32 KiB**, including chunked requests, enforced before JSON parsing/provider work. Oversize returns 413; strict validation failures return 422 with at most 32 redacted errors and an `errors_truncated` flag. Submitted values/unknown field names are removed. Raw numeric JSON tokens that become nonfinite, underflow or lose decimal digits are rejected before float validation. Photos, raw OCR, profiles, allergy preferences, history and provider keys are not accepted. Responses include request/session/revision and normalization time so the client can reject stale results. Current normalization/claim routes persist no scan and log no content. The separate community intake automatically saves structured public observations and stages unverified candidates; it accepts no raw OCR or photos.

Use the validated [synthetic request](../contracts/examples/nutrition-normalize-v1.request.synthetic.json) and [response](../contracts/examples/nutrition-normalize-v1.response.synthetic.json) as an integration pair. They are illustrative facts, not a real product, regulatory rule or health verdict.

## Reviewed confirmed-label claim checks

Check `/v1/meta.capabilities.claim_checks` before submitting to `/v1/claims/check`. A valid loaded knowledge store reports `knowledge_version: claims-2026-10-06.1`; invalid or missing knowledge disables only claim/rule/evidence access. A verified package also exposes the two-file hash/length receipt in `knowledge_artifact`; direct local canonical-source loading has a null artifact. Health, live OFF reads and catalogue operations retain their independent readiness.

`ClaimsRequest` extends the strict confirmed normalization request. Supply 1–16 unique identified claims (`claim_id`, recognized `claim`, required nullable `region_id`), `selected_table_id` and `context` with food category, solid/liquid form and preparation. The selected table must exist and match the confirmed context for an applicable assessment. UUID request/session IDs, correction revision, `confirmed: true`, completeness and 1–64 nutrient rows remain required. Photos, raw OCR, personal profiles and arbitrary claim text are excluded. Normalization, claim checks and community intake use the same **32 KiB** actual body, strict numeric-token and redacted-422 handling.

| Reviewed claim | Selected numerical criterion |
| --- | --- |
| `source_of_fibre` | At least 3 g/100 g for solids, 1.5 g/100 mL for liquids, or 1.5 g/100 kcal |
| `high_fibre` | At least 6 g/100 g for solids, 3 g/100 mL for liquids, or 3 g/100 kcal |
| `low_sugar` | Total sugars at most 5 g/100 g for solids or 2.5 g/100 mL for liquids |
| `sugar_free` | Total sugars at most 0.5 g/100 g or 100 mL for the matching form |
| `low_sodium` | Sodium at most 0.12 g/100 g or 100 mL for the matching form |
| `very_low_sodium` | Sodium at most 0.04 g/100 g or 100 mL for the matching form |
| `sodium_free` | Sodium at most 0.005 g/100 g or 100 mL for the matching form |

The source is the reviewed 2022 Schedule I amendment plus principal 2018 requirements, cross-checked against the compendium. [Reviewed source register and hashes](../knowledge/README.md). Scope is `numeric_criterion_only` for confirmed ordinary general foods. Unknown/special categories, unknown form/preparation, conflicting tables/rows, unsupported bases and missing values cannot establish applicability or a contradiction. For fibre alternatives, one applicable pass supports the numerical claim; contradiction requires every applicable alternative to be known and fail. An unknown remaining alternative keeps the result `insufficient_information`.

`high_protein`, `source_of_protein`, `no_added_sugar` and `multigrain` are recognized but unreviewed and always return `insufficient_information`, with explicit reasons/missing inputs. Total sugar alone cannot establish manufacturing non-addition. A claim assessment is `supported`, `contradicted` or `insufficient_information`; it includes applicability, selected criteria, input row/region IDs, rule/source IDs and bounded explanatory wording. It is neither a health score nor complete legal certification.

All claim criteria compare exact rational values constructed from the original numeric decimal strings and unit/basis factors, so a non-terminating per-100 conversion does not shift an exact threshold. For fibre energy alternatives, statutory Schedule I Note 2 uses **1 kcal = 4.2 kJ**. The engine calculates this from original selected confirmed rows with exact rational arithmetic, scales only known compatible quantities and exposes `energy_conversion.version: fssai-schedule-i-note2-v1`. The existing normalization-v1 snapshot keeps its scientific **4.184 kJ/kcal** conversion unchanged. Conflicting regulatory energy values remain unknown rather than choosing a row; bounded output conversion rejects values outside its representable limits. Clients should retain both the snapshot and the claim-specific conversion metadata.

`GET /v1/claims/rules` returns the actual loaded rules and unsupported list. `/v1/evidence/{source_id}` returns one of the three reviewed metadata records with URL, PDF hash/size/pages, known publication/effective dates, verification date/status and qualifications. Unknown valid IDs return 404; malformed IDs return redacted 422. Missing/invalid knowledge returns typed 503 responses; known future publication/effective dates, non-current/future review status or unsupported applicability suppress affected assessments. Review status is maintained explicitly; no automatic statutory expiry is inferred from age. These endpoints make no OFF, Gemini or FSSAI request and persist no scan. Claim/rule/evidence responses use `no-store`.

Use the validated [claims request](../contracts/examples/claims-check-v1.request.synthetic.json), [claims response](../contracts/examples/claims-check-v1.response.synthetic.json), [rules](../contracts/examples/claims-rules-v1.synthetic.json) and [evidence](../contracts/examples/evidence-v1.synthetic.json) fixtures for client integration. They contain synthetic rows, not a real scan. Historical frontend v0.3.0+4 used local OCR and editable suggestions. Local v0.6.0 removes mandatory entry and automatically reads barcode/front/back photos; separate explicit acceptance remains necessary for confirmed structured report submission. Native camera/recognition acceptance remains separate from browser and source checks. Optional photo transfer uses consent; photos/raw OCR stay outside database/account storage. Continuous live-feed decoding remains future work.

## Sourced nutrient comparison

`POST /v1/reports/compare` accepts two discriminated inputs: current confirmed
structured label facts, an exact OFF snapshot ID/hash/barcode, or an active public
community revision ID/factual hash/barcode. Each side explicitly selects a table.
Reference misses, rotated hashes, unavailable stores and correction requirements
return typed side states; sources are never silently replaced. Current confirmed
inputs work without authentication, catalogue, reviewed glossary or cloud storage.
The route does not save observations or personal records and uses `no-store`.

Compatible tables require a known measured basis in the same mass/volume unit and
the same preparation. Original values are converted with exact rational arithmetic
to 100 g or 100 mL; energy uses 4.184 kJ/kcal, with its own comparison version.
Differences are `b - a`. Unknown nutrients stay unknown, explicit zero stays zero,
and conflicting or incompatible evidence cannot produce a difference. Available
carbohydrate/total carbohydrate and sodium/salt remain distinct. There is no density,
serving-size or ingredient-based inference, score, recommendation or allergy verdict.

The actual request body is bounded to **64 KiB**, with strict/redacted validation
and no photo, raw OCR or private-sync payload. See the
[full contract and outcomes](../docs/architecture/SOURCED_COMPARISON.md),
[synthetic request](../contracts/examples/comparison-v1.request.synthetic.json)
and [synthetic response](../contracts/examples/comparison-v1.response.synthetic.json).

## Community facts and source resolution

`ContributionRequest` accepts provisional/confirmed observations, optional exact
barcode, independent package identity/label sections and nutrient rows. Confirmed
records need `confirmed: true`; public candidate eligibility additionally needs
front/back/same-product confirmation and valid normalization. No Share flag exists.
Provisional/unmatched records remain private, expire after seven days and can be
cleaned by the operator. Known conflicts await review; eligible compatible facts
can appear as `submitter_confirmed_not_moderator_reviewed`.

The server computes observation/factual hashes. Immutable retries preserve receipts;
semantic duplicates reuse active facts without new public revisions or trust votes.
Provider references are verified against the exact available OFF snapshot for new
records. Identical retries remain valid when that snapshot rotates or is unavailable.
Copied OFF facts cannot become CC0 package transcription.

Resolved `fields` retain selected values or unknown/conflict, units/basis/preparation,
source IDs, evidence state, completeness, source dates and alternatives. Whole source
groups remain intact. Unknown cross-source nutrition revision is unselected; no
averaging, first-arrival winner, generic composition imputation or current-packet
confirmation is invented. OFF-only results remain useful during a community outage.

Firebase **Unlabel**, project `unlabel-india-catalogue`, first Standard database
**`unlabel`** in Mumbai has free-tier enabled and no linked billing. Anonymous and
email/password Auth, deny-all direct client rules and dedicated backend access are
configured. Public observations exclude photos, raw OCR, profiles and private
history. The separately released v0.7.0 private account contract accepts only
bounded display name/saved/history snapshots; photos/raw OCR and health preferences
remain excluded. Backend releases are checked, pushed, hosted-verified and
published independently.

Examples: [confirmed intake](../contracts/examples/community-contribution-v1.request.synthetic.json),
[provisional intake](../contracts/examples/community-provisional-v1.request.synthetic.json),
[receipt](../contracts/examples/community-contribution-v1.receipt.synthetic.json),
[public lookup](../contracts/examples/community-lookup-v1.synthetic.json),
[resolved fields](../contracts/examples/resolved-product-v1.synthetic.json).
[Storage/security/operator guide](../docs/architecture/COMMUNITY_CATALOGUE.md).

## Useful Label Report: released v0.5.0

Three additive routes are mounted: POST `/v1/reports/check`, GET
`/v1/products/{barcode}/report` and GET `/v1/ingredients/glossary`.
Current input is a confirmed `observation` with optional barcode, selected table
and claim context. Analysis itself needs no authentication. Automatic community
saving has an independent typed `storage` outcome, so missing auth, quota or
provider failure keeps the useful report available. Historical barcode reports
are read-only and never establish current-label claim confirmation.
Impossible or internally contradictory nutrient quantities retain the useful
HTTP 200 report with `storage: needs_correction` and cause no automatic write:
more than 100 g per 100 g, added sugar above total sugar, or saturated fat above
total fat must be corrected first.

Report sections retain original nutrition, ingredient/contains/may-contain text,
completeness, source/evidence, numerical claim findings, missing inputs and versions.
Sugar cubes use the declared approximate **4 g/cube** assumption and original
basis/preparation; quantity or packet size is never an inferred serving.
The reviewed glossary covers only lecithin INS 322(i), citric acid INS 330 and
xanthan gum INS 415 names/functions in English/Hindi, with source/hash metadata.
No health/allergy/Indian-permission verdict, full ingredient coverage, universal
score or Gemini dependency is introduced. Report metadata enables `label_reports`
and `nutrition_analysis`, with `report_version: label-report-v1`; ingredient
explanations require a valid loaded glossary. A glossary failure affects that
section instead of discarding usable nutrition. Validated examples cover a
[barcode-less current request](../contracts/examples/report-check-v1.request.synthetic.json),
[current report](../contracts/examples/label-report-v1.current.synthetic.json),
[historical report](../contracts/examples/label-report-v1.historical.synthetic.json)
and [glossary](../contracts/examples/ingredient-glossary-v1.synthetic.json).
[Detailed report contract](../docs/architecture/LABEL_REPORT.md).

## Configuration and key handling

Settings load the ignored `.env` at this backend root; environment variables override the file. Do not overwrite a teammate's existing file. `.env.example` contains safe defaults. Current settings:

- `OFF_USER_AGENT`: public application identity, never a user token.
- `OFF_TIMEOUT_SECONDS`: total lookup deadline (default 8; bounded 1–15 seconds).
- `OFF_MAX_RESPONSE_BYTES`: decoded response budget (default 512 KiB; bounded 1 KiB–1 MiB).
- `CORS_ORIGINS`: JSON array of exact HTTP(S) website origins, default `[]`; no wildcard or credentialed CORS.
- `CATALOGUE_DIRECTORY`: read-only index directory, relative to backend or absolute; empty disables catalogue. Local generated index is `storage/runtime/india`; hosted build output is `app/catalogue/data`.
- `CATALOGUE_REQUIRE_RECEIPT`: `false` for an explicitly configured local runtime index; `true` for hosted bundles. Startup verifies the SQLite hash/size, receipt and manifest before enabling catalogue access. Invalid/missing files disable the catalogue while health/live APIs remain available.
- `COMMUNITY_ENABLED`: default `false`; enables authenticated observation storage when explicit credentials are available.
- `COMMUNITY_PROJECT_ID`: exact Firebase project; configured project is `unlabel-india-catalogue`.
- `COMMUNITY_DATABASE_ID`: literal `unlabel`.
- `COMMUNITY_SERVICE_ACCOUNT_JSON`: backend-only `SecretStr`, bounded to 32 KiB; no ambient credential fallback.
- `COMMUNITY_ACTOR_SECRET`: backend-only `SecretStr`, 32–1024 characters; keyed ownership hashes, never public.
- `CLAIMS_KNOWLEDGE_DIRECTORY`: optional source/bundle directory, relative to backend or absolute. Local default uses `app/claims/data` when it exists, otherwise canonical root `knowledge/`. An existing invalid packaged bundle never falls back to source. With `VERCEL=1`, the default selects the packaged path and every selected directory requires a verified knowledge receipt, including an explicit override; no source fallback is permitted.

OFF reads require no API key. Bounded live reads fetched Nutella's nutrition tables in 0.68 seconds and Coca-Cola's in 0.18 seconds during the 5 October 2026 feasibility check; these samples do not establish general latency, Indian coverage or availability. Optional Gemini/OpenAI photo reading now uses server-only settings, scanner authentication, explicit consent and shared bounded admission. See [AI routing](../docs/architecture/AI_ROUTING.md) for keys and global selection. Secrets must never appear in logs, API output, contracts or Git. CORS permits GET/POST for configured origins and is a browser control, not authentication.

## Modules and constraints

- `app/main.py`: app composition, lifespan-owned HTTP/Firebase runtime, catalogue/knowledge/glossary stores, 27 API paths/28 operations and redacted validation failures.
- `app/ai/`: scanner photo validation, one global provider selection, bounded adapters/admission and v0.12 private structured proposal staging.
- `app/research_catalogue/`: immutable mixed-source observations, derived search v3, source-qualified details and separate validated product-image descriptors.
- `app/reports/` and `app/api/v1/reports.py`: current/historical reports, independent automatic-save outcomes, original-basis approximate sugar cubes and bounded reviewed six-entry glossary.
- `app/accounts/` and `app/api/v1/accounts.py`: strict private snapshots, verified password ownership, CAS/idempotent mutations, separate free-tier admission and 512 KiB body/384 KiB data caps.
- `app/community/` and `app/api/v1/community.py`: strict observations, normalization/hashes, typed sourced resolution, verified anonymous auth, transactional Firestore and four routes.
- `app/comparison/` and `app/api/v1/comparison.py`: selected-table source resolution, original-row exact arithmetic and independent read-only comparison contract.
- `app/api/v1/claims.py`, `app/claims/`: strict confirmed-label API, exact rational numerical engine, bounded reviewed knowledge loader and receipt-verified packaging.
- `app/catalogue/`: bounded identity/facts models, optional facts storage, offline importer, bundle verification, calendar-based freshness and read-only indexed lookup. The catalogue uses separate provenance from live API3.6 responses.
- `build_catalogue.py`: network-free deployment build entrypoint; validates tracked catalogue source and the two reviewed JSON projections, then generates SQLite/receipt in `app/catalogue/data/` and approved knowledge JSON/receipt in `app/claims/data/`. Both directories are ignored generated outputs. Successful stdout is one JSON object with `catalogue` and `claims_knowledge` receipts.
- `app/schemas/errors.py`: shared strict redacted 422 response, including raw-number middleware rejections.
- `app/core/config.py`: validated public request/CORS settings plus explicit secret Firebase credentials and actor hashing key.
- `app/core/body_limit.py`: actual-byte input limit before parsing.
- `app/providers/products/open_food_facts.py`: fixed official HTTPS origin, selected fields, bounded read/deadline, identity checks and failure mapping.
- `app/providers/products/nutrition.py`: live direct-input wrapper; `app/services/parsing/off_nutrition.py` shares its bounded parser with snapshot facts.
- `app/schemas/products.py`: versioned normalized product/status/provenance models.
- `app/schemas/nutrition.py`, `nutrition_products.py`: strict rows, bases, snapshots and independent source wrappers.
- `app/services/parsing/nutrition.py`: pure deterministic unit/basis conversion; no health/regulatory evaluator.
- `tests/`: synthetic mocked-provider and ASGI contract tests; no corpus copied from OFF.
- `requirements*.txt`, `pyproject.toml`: tested dependency versions and backend metadata/tooling.

HTTPX connection pool is bounded to six connections. OFF reads have no automatic
retry or durable cache. Confirmed normalization, claims and useful current reports
work independently of OFF connectivity and require no account. Released community
transactions and admission counters protect automatic public observation storage;
v0.7.0 adds separate password-owned private profile/saved/history snapshots.
Guests retain personal records locally. Only the optional authenticated
`/v1/ai/extract` route accepts bounded photos with consent; they are not retained
in database/account storage. Current
claim checks still require confirmed package rows and explicit context; historical
reports preserve their source/date and do not establish current-label confirmation.

Vercel uses root `backend`, framework FastAPI, Python 3.12 and the tracked entrypoint/config. The project allows build access to files outside its root, and `pyproject.toml` runs `python build_catalogue.py` after dependency installation. The generated owned bundle is included in the Python function. Local `.env*`, tests, environments and `storage/runtime` are excluded; hosted settings live in the project's environment. See [Vercel's build-hook documentation](https://vercel.com/docs/frameworks/backend/fastapi#build-command).

## India catalogue and measured-source gate

v0.2.3 acquired the complete official JSONL through validated gzip EOF: **13,084,464,175 compressed bytes**, **83,007,975,584 decoded bytes**, **4,795,607 source records** and **24,695 exact India rows**. There are **24,641 supported unique barcodes**, **54 unsupported codes** and **0 duplicates**. The candidate gzip is **2,098,225 bytes**, decoding to **15,084,130 bytes**. Source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. [Hashes and raw-field evidence](../docs/planning/BACKEND_V0_2_3_REVIEW.md).

All **24,641 indexed fact records** pass strict validation. **4,657** have direct tables (**4,519** with reported nutrient values); **15,486** are legacy-unsupported, **4,050** missing and **448** invalid. **18,682** have official image descriptors; all supported records have a validated modification date. Local SQLite is **62,472,192 bytes (59.58 MiB)** with a verified receipt. [Dated field/build report](../docs/research/CATALOGUE_V0_2_3_COVERAGE.json). Local suite **402 passed**; independent code/security/dead-code review found no actionable issues, with **103** reviewer tests passing. Hosted v0.2.3 source/count/date/hash and facts/identity reads passed; the actual build receipt matches the public 62,472,192-byte artifact. [Dated production proof](../docs/research/BACKEND_V0_2_3_PRODUCTION.json). Source-only tag `v0.2.3` points to tested implementation `56064d7fd13d585c949eb2d31a53eb3884a5d520`. Actual private-key restoration was not rerun in this continuation. Descriptors do not establish remote image availability. Coverage remains `unverified`; India-tagged OFF records are not every product sold in India. The preceding CSV measurements remain in the [v0.2.2 review](../docs/planning/BACKEND_V0_2_2_REVIEW.md).

Build and exercise the hosted bundle locally from `backend/`:

~~~powershell
.venv/Scripts/python.exe build_catalogue.py
$env:CATALOGUE_DIRECTORY = "app/catalogue/data"
$env:CATALOGUE_REQUIRE_RECEIPT = "true"
.venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
~~~

The network-free builder checks compressed/decoded catalogue hashes, byte budgets and expected counts before publishing. It also validates exactly `rules/claims/reviewed-v1.json` and `sources/registry/fssai-claims-v1.json`, packages those files with a hash/length receipt and verifies the result. `--knowledge-directory` and `--knowledge-output-directory` can select explicit build paths; catalogue options remain `--source-directory` and `--output-directory`. Generated files are replaced inside an unpublished build; any failure rejects that build. Startup verifies each bundle before enabling its capability. Each catalogue build has its own UUID/indexing timestamp/hash; receipts identify trusted source/build artifacts, not OFF or FSSAI cryptographic signatures.

`GET /v1/catalogue` and `/v1/meta.catalogue` report source age. Nine calendar months uses the actual export timestamp, never rebuild time; overdue lookups remain available with a warning, and future dates are flagged. Identity/status/facts reads are `no-store`; metadata retains its existing cache policy. A snapshot miss makes no OFF request. Clients may deliberately request the separate live endpoint.

## Manual nine-month refresh

From repository root, acquire into a new existing owned directory:

~~~powershell
New-Item -ItemType Directory -Force backend/storage/runtime/new-source
backend/.venv/Scripts/python.exe scripts/acquire_india_jsonl.py --directory backend/storage/runtime/new-source
~~~

Validate complete transfer/gzip EOF, compressed/decoded hashes, source date, exact India/counts, field rates, representative sparse/rich records and size budgets. Record unresolved export/live-count differences. Update the tracked gzip, `bundle.json`, `acquisition.json`, license notices and current evidence together; do not retain the world dump or image bytes. Setup regenerates the local SQLite; the hosted build generates its own immutable SQLite/receipt without network acquisition. Plain/gzip JSONL imports also remain supported for explicit local inputs and samples; supply the actual source URL/format and use `coverage: sample` for samples.

Run tests/build, update docs, then push. Verify the exact deployed commit, source/hash/date/counts, receipt, status and identity/facts routes before accepting the replacement. Failed builds must not be promoted; rollback uses the previous verified deployment/source/configuration. No request-time bulk import, automatic schedule or packaged-runtime hot swap exists. [Full catalogue workflow](../docs/architecture/CATALOGUE.md).

SQLite serves the immutable OFF snapshot; JSONL/CSV are acquisition inputs.
Automatic public-fact observations use the separate configured Firestore database;
the OFF snapshot remains read-only.
Backend-held data does not make phones or the website fully offline.

## Validate

~~~powershell
.venv/Scripts/python.exe -m pytest -q
.venv/Scripts/python.exe -m ruff check app tests
.venv/Scripts/python.exe -m ruff format --check app tests
.venv/Scripts/python.exe -m pip check
~~~

Optional static type checking from repository root uses the checked-in [pyrightconfig.json](../pyrightconfig.json):

~~~powershell
npm exec --yes --package=pyright@1.1.414 -- pyright --project pyrightconfig.json --pythonpath backend/.venv/Scripts/python.exe
~~~

This uses the backend Python environment and checks backend application/build/test code plus maintained Python scripts in basic mode. Node/npm is needed only to run this optional development check; no npm project dependency or runtime service is introduced. Use `backend/.venv/bin/python` on Unix. The flags follow [Pyright's official CLI documentation](https://github.com/microsoft/pyright/blob/main/docs/command-line.md); configuration follows its [configuration guide](https://github.com/microsoft/pyright/blob/main/docs/configuration.md), checked through Context7 for this update.

See [current v0.9.0 review](../docs/planning/BACKEND_V0_9_0_REVIEW.md),
[published v0.7.0 review](../docs/planning/BACKEND_V0_7_0_REVIEW.md),
[comparison contract](../docs/architecture/SOURCED_COMPARISON.md),
[private sync contract](../docs/architecture/PRIVATE_ACCOUNT_SYNC.md),
[historical v0.5.0 review](../docs/planning/BACKEND_V0_5_0_REVIEW.md) and
[published v0.4.0 verification](../docs/planning/BACKEND_V0_4_0_REVIEW.md).
Historical v0.5.0 exports describe eighteen routes and four added report/glossary
schemas and 22 validated synthetic examples; historical v0.4.0 exports are preserved.
Independent local/review/hosted gates passed; v0.5.0 is separately published.
Review Markdown/scripts, affected tests/contracts and
demonstrably dead code before any future push. Backend-only releases preserve
Flutter and historical mobile artifacts.
