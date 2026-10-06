# Unlabel backend v0.2.3

Frontend remains **0.0.0+1**. This version adds a separate rich-facts route to the backend-held India catalogue: direct nutrition, canonical tag availability, provider schema/record date and an attributed official image URL. Existing identity, live OFF nutrition, status and confirmed-input contracts preserve their shapes and origins. FSSAI checks remain disabled until the next independent v0.3.0 slice. [Accepted two-version plan](../docs/superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md) · [20-group feature tracker](../docs/planning/FEATURE_TRACKER.md).

Production API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)** · [Swagger](https://unlabel-api.vercel.app/docs) · [Catalogue status](https://unlabel-api.vercel.app/v1/catalogue). Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app). Both projects automatically deploy `main` pushes. See [deployment settings](../docs/planning/VERCEL_SETUP.md) and the release-specific [v0.2.3 verification record](../docs/planning/BACKEND_V0_2_3_REVIEW.md) for actual local/provider/production evidence.

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
| `GET /v1/health` | Backend readiness/version; external provider connectivity explicitly not checked |
| `GET /v1/meta` | Backend/API/schema/adapter/normalization versions; product lookup, nutrition lookup and normalization enabled |
| `GET /v1/products/{barcode}` | Fixed OFF v3.6 product read; stable typed source-tagged response |
| `GET /v1/products/{barcode}/nutrition` | Separate source-tagged direct-input nutrition tables; strict product lookup v1 remains unchanged |
| `POST /v1/nutrition/normalize` | Normalize user-confirmed structured nutrient rows without calling OFF |
| `GET /v1/catalogue` | Ready/unavailable/not-configured status, manifest, artifact hash/size, source age, refresh date and field limits; 503 if unavailable |
| `GET /v1/catalogue/products/{barcode}` | Separate export-origin indexed identity lookup; 503 when catalogue is inactive/unavailable |
| `GET /v1/catalogue/products/{barcode}/facts` | Exact identity/manifest plus optional rich facts; older identity-only catalogues report facts unavailable |

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

The unchanged product response has name/brands/quantity text, ingredient text, source-tagged allergen/trace tags and optional OFF Nutri-Score grade/NOVA group. Missing strings/grades are null; absent tags do not prove allergen absence. Source metadata contains provider, URL, retrieval time, available modification/schema version, attribution and licenses. This identity route exposes no raw provider internals or image fields; the separate snapshot facts route can expose a validated official image URL descriptor. Product/nutrition responses use `Cache-Control: no-store`; saved-result policy is future client work.

## Snapshot rich facts

Use `/v1/meta.capabilities.catalogue_facts` before requesting `/v1/catalogue/products/{barcode}/facts`. The response keeps the old `product` identity and export `manifest`, and adds a separate `details` model. Exact catalogue keys preserve leading zeros; image disk paths follow OFF's canonical code normalization independently of identity lookup.

`details.categories`, `labels`, `allergens` and `traces` pair `availability: available|missing|invalid` with bounded values. A present empty tag list differs from a missing field, but neither establishes absence of allergens. `provider_schema_version` and `last_modified_at` are optional source values, distinct from export/index/request dates.

`details.nutrition.availability` is `direct_tables`, `missing`, `legacy_unsupported` or `invalid`. Direct packaging/manufacturer tables use the same bounded parser and normalizer as live nutrition, with separate export provenance. Legacy aggregate nutrients are not reclassified as direct label tables. Preserve unknown cells, warnings, preparation, original bases and row/table sources.

`details.image` is null or a validated official selected-front 400-size URL descriptor with language, revision, optional dimensions, attribution and CC-BY-SA-3.0 metadata. URLs are constructed from selected-image metadata; arbitrary URLs, image proxies and bytes are excluded. Show attribution and an image fallback. A valid descriptor does not guarantee the remote image currently exists. OFF's [official image-path implementation](https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/lib/ProductOpener/Products.pm) strips leading zeros, pads short codes and splits the resulting path; catalogue identity still matches the exact requested key.

A missing snapshot record returns dated 404 with its checked manifest; inactive/invalid or older identity-only facts storage returns 503. Older stores keep their previous identity/status routes. Responses are `no-store`; lookup never calls OFF or silently substitutes live facts. Claims and health analysis remain disabled.

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

The POST actual body limit is **32 KiB**, including chunked requests, enforced before JSON parsing/provider work. Oversize returns 413; strict validation failures return 422 with at most 32 redacted errors and an `errors_truncated` flag. Submitted values/unknown field names are removed. Raw numeric JSON tokens that become nonfinite, underflow or lose decimal digits are rejected before float validation. Photos, raw OCR, profiles, allergy preferences, history and provider keys are not accepted. Responses include request/session/revision and normalization time so the client can reject stale results. The backend has no scan persistence or request-content logging.

Use the validated [synthetic request](../contracts/examples/nutrition-normalize-v1.request.synthetic.json) and [response](../contracts/examples/nutrition-normalize-v1.response.synthetic.json) as an integration pair. They are illustrative facts, not a real product, regulatory rule or health verdict.

## Configuration and key handling

Settings load the ignored `.env` at this backend root; environment variables override the file. Do not overwrite a teammate's existing file. `.env.example` contains safe defaults. Current settings:

- `OFF_USER_AGENT`: public application identity, never a user token.
- `OFF_TIMEOUT_SECONDS`: total lookup deadline (default 8; bounded 1–15 seconds).
- `OFF_MAX_RESPONSE_BYTES`: decoded response budget (default 512 KiB; bounded 1 KiB–1 MiB).
- `CORS_ORIGINS`: JSON array of exact HTTP(S) website origins, default `[]`; no wildcard or credentialed CORS.
- `CATALOGUE_DIRECTORY`: read-only index directory, relative to backend or absolute; empty disables catalogue. Local generated index is `storage/runtime/india`; hosted build output is `app/catalogue/data`.
- `CATALOGUE_REQUIRE_RECEIPT`: `false` for an explicitly configured local runtime index; `true` for hosted bundles. Startup verifies the SQLite hash/size, receipt and manifest before enabling catalogue access. Invalid/missing files disable the catalogue while health/live APIs remain available.

OFF reads require no API key. Bounded live reads fetched Nutella's nutrition tables in 0.68 seconds and Coca-Cola's in 0.18 seconds during the 5 October 2026 feasibility check; these samples do not establish general latency, Indian coverage or availability. Gemini is disabled/unimplemented; reserved Gemini fields in `.env` are unused. Secrets must never appear in logs, API output, contracts or Git. CORS permits GET/POST for configured origins and is a browser control, not authentication. Public cloud AI needs a separate access/budget design before activation.

## Modules and constraints

- `app/main.py`: app composition, lifespan-owned HTTP client/store, eight routes and redacted validation failures.
- `app/catalogue/`: bounded identity/facts models, optional facts storage, offline importer, bundle verification, calendar-based freshness and read-only indexed lookup. The catalogue uses separate provenance from live API3.6 responses.
- `build_catalogue.py`: network-free deployment build entrypoint; validates tracked source and generates SQLite plus a receipt in the ignored `app/catalogue/data/` directory.
- `app/schemas/errors.py`: shared strict redacted 422 response, including raw-number middleware rejections.
- `app/core/config.py`: validated non-secret request/CORS settings.
- `app/core/body_limit.py`: actual-byte input limit before parsing.
- `app/providers/products/open_food_facts.py`: fixed official HTTPS origin, selected fields, bounded read/deadline, identity checks and failure mapping.
- `app/providers/products/nutrition.py`: live direct-input wrapper; `app/services/parsing/off_nutrition.py` shares its bounded parser with snapshot facts.
- `app/schemas/products.py`: versioned normalized product/status/provenance models.
- `app/schemas/nutrition.py`, `nutrition_products.py`: strict rows, bases, snapshots and independent source wrappers.
- `app/services/parsing/nutrition.py`: pure deterministic unit/basis conversion; no health/regulatory evaluator.
- `tests/`: synthetic mocked-provider and ASGI contract tests; no corpus copied from OFF.
- `requirements*.txt`, `pyproject.toml`: tested dependency versions and backend metadata/tooling.

HTTPX connection pool is bounded to six connections. There is no automatic retry, durable cache, process-wide global quota guarantee, profile/history storage or image upload. The POST normalizer works independently of OFF connectivity. OFF and user-confirmed facts remain inputs for later reviewed analysis.

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

The network-free builder checks compressed/decoded hashes, byte budgets and expected counts before publishing. SQLite and receipt use two file replacements inside an unpublished build; any failure rejects that build. Startup verifies the database once, then uses indexed read-only transactions. Each build has its own UUID/indexing timestamp/hash; the receipt records integrity, not an OFF cryptographic signature.

`GET /v1/catalogue` and `/v1/meta.catalogue` report source age. Nine calendar months uses the actual export timestamp, never rebuild time; overdue lookups remain available with a warning, and future dates are flagged. Identity/status/facts reads are `no-store`; metadata retains its existing cache policy. A snapshot miss makes no OFF request. Clients may deliberately request the separate live endpoint.

## Manual nine-month refresh

From repository root, acquire into a new existing owned directory:

~~~powershell
New-Item -ItemType Directory -Force backend/storage/runtime/new-source
backend/.venv/Scripts/python.exe scripts/acquire_india_jsonl.py --directory backend/storage/runtime/new-source
~~~

Validate complete transfer/gzip EOF, compressed/decoded hashes, source date, exact India/counts, field rates, representative sparse/rich records and size budgets. Record unresolved export/live-count differences. Update the tracked gzip, `bundle.json`, `acquisition.json`, license notices and current evidence together; do not retain the world dump or image bytes. Setup regenerates the local SQLite; the hosted build generates its own immutable SQLite/receipt without network acquisition. Plain/gzip JSONL imports also remain supported for explicit local inputs and samples; supply the actual source URL/format and use `coverage: sample` for samples.

Run tests/build, update docs, then push. Verify the exact deployed commit, source/hash/date/counts, receipt, status and identity/facts routes before accepting the replacement. Failed builds must not be promoted; rollback uses the previous verified deployment/source/configuration. No request-time bulk import, automatic schedule or packaged-runtime hot swap exists. [Full catalogue workflow](../docs/architecture/CATALOGUE.md).

SQLite serves the immutable snapshot; JSONL/CSV are acquisition inputs. Firestore remains deferred. No backend snapshot makes phones or the website fully offline.

## Validate

~~~powershell
.venv/Scripts/python.exe -m pytest -q
.venv/Scripts/python.exe -m ruff check app tests
.venv/Scripts/python.exe -m ruff format --check app tests
.venv/Scripts/python.exe -m pip check
~~~

See [v0.2.3 review](../docs/planning/BACKEND_V0_2_3_REVIEW.md) for actual checks and remaining gates; earlier reviews remain historical records. Current exports/examples are indexed in [contracts](../contracts/README.md). Update docs before every push. Backend-only releases do not trigger the manual mobile workflow or change Flutter's pubspec.
