# Unlabel backend v0.2.2

Frontend remains **v0.0.0**. This version packages the committed India identity source into a verified read-only SQLite bundle for Vercel, and adds catalogue status/source-age metadata. Live OFF product/nutrition and confirmed-input contracts retain their separate origins. FSSAI checks, ingredient explanations, comparison and AI remain separate [versions](../docs/superpowers/plans/2026-10-05-backend-versions.md).

Production API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)** · [Swagger](https://unlabel-api.vercel.app/docs) · [Catalogue status](https://unlabel-api.vercel.app/v1/catalogue). Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app). Both projects automatically deploy `main` pushes. See [deployment settings](../docs/planning/VERCEL_SETUP.md) and the release-specific [v0.2.2 verification record](../docs/planning/BACKEND_V0_2_2_REVIEW.md) for actual local/provider/production evidence.

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

The unchanged product response has name/brands/quantity text, ingredient text, source-tagged allergen/trace tags and optional OFF Nutri-Score grade/NOVA group. Missing strings/grades are null; absent tags do not prove allergen absence. Source metadata contains provider, URL, retrieval time, available modification/schema version, attribution and licenses. No raw provider internals or remote images are exposed. Product/nutrition responses use `Cache-Control: no-store`; saved-result policy is future client work.

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

- `app/main.py`: app composition, lifespan-owned HTTP client/store, seven routes and redacted validation failures.
- `app/catalogue/`: bounded models, offline importer, bundle verification, calendar-based freshness and read-only indexed lookup. The catalogue uses separate provenance from live API3.6 responses.
- `build_catalogue.py`: network-free deployment build entrypoint; validates tracked source and generates SQLite plus a receipt in the ignored `app/catalogue/data/` directory.
- `app/schemas/errors.py`: shared strict redacted 422 response, including raw-number middleware rejections.
- `app/core/config.py`: validated non-secret request/CORS settings.
- `app/core/body_limit.py`: actual-byte input limit before parsing.
- `app/providers/products/open_food_facts.py`: fixed official HTTPS origin, selected fields, bounded read/deadline, identity checks and failure mapping.
- `app/providers/products/nutrition.py`: narrow direct-input nutrition adapter and table/row budgets.
- `app/schemas/products.py`: versioned normalized product/status/provenance models.
- `app/schemas/nutrition.py`, `nutrition_products.py`: strict rows, bases, snapshots and independent source wrappers.
- `app/services/parsing/nutrition.py`: pure deterministic unit/basis conversion; no health/regulatory evaluator.
- `tests/`: synthetic mocked-provider and ASGI contract tests; no corpus copied from OFF.
- `requirements*.txt`, `pyproject.toml`: tested dependency versions and backend metadata/tooling.

HTTPX connection pool is bounded to six connections. There is no automatic retry, durable cache, process-wide global quota guarantee, profile/history storage or image upload. The POST normalizer works independently of OFF connectivity. OFF and user-confirmed facts remain inputs for later reviewed analysis.

Vercel uses root `backend`, framework FastAPI, Python 3.12 and the tracked entrypoint/config. The project allows build access to files outside its root, and `pyproject.toml` runs `python build_catalogue.py` after dependency installation. The generated owned bundle is included in the Python function. Local `.env*`, tests, environments and `storage/runtime` are excluded; hosted settings live in the project's environment. See [Vercel's build-hook documentation](https://vercel.com/docs/frameworks/backend/fastapi#build-command).

## India catalogue — measured source and deployment bundle

The official nightly CSV stream was acquired on 6 October: **1,275,171,186 compressed bytes**, **4,535,553 source rows**, **21,188 exact India-tagged rows**. Its source export timestamp is **2026-10-05T12:19:34Z**. No world file was retained. The committed gzip is 840,099 bytes and decodes to 6,588,910 bytes; SQLite is **11,993,088 bytes (11.44 MiB)**, indexing 21,138 supported barcode records and counting 50 unsupported codes. There were no duplicate supported barcodes. Missing names: 3,442; missing ingredient text: 15,780. A bounded live count on 6 October returned **24,715**, compared with the earlier 24,706 observation. The source/count difference remains unexplained, so coverage is `unverified`. [Dated coverage evidence](../docs/research/CATALOGUE_V0_2_2_COVERAGE.json). Rice flour `8904083506393` is indexed; live-found chocolate `7622202842450` is absent from this snapshot.

For this version, local bundle verification took 31.2 ms; 100 local read-only lookups had a 0.341 ms median and 0.550 ms maximum. These are local observations, not mobile/network/serverless performance guarantees. The catalogue excludes nutrition tables, images and record-level modification dates. Canonical allergen tags were absent from this source; legacy bare allergen fields are not converted into full canonical tags. Existing live nutrition remains the source for direct package/manufacturer tables.

Build and exercise the hosted bundle locally from `backend/`:

~~~powershell
.venv/Scripts/python.exe build_catalogue.py
$env:CATALOGUE_DIRECTORY = "app/catalogue/data"
$env:CATALOGUE_REQUIRE_RECEIPT = "true"
.venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
~~~

The builder checks compressed/decoded hashes, byte budgets and expected counts before publishing. The database and receipt are two file replacements inside the unpublished build; a failed build must not be deployed. Startup verifies the entire SQLite once, then lookups use indexed read-only connections. Builds produce their own UUID/indexing timestamp and SQLite hash; unchanged source/content does not promise byte-identical databases. The receipt is an integrity record, not a cryptographic OFF signature.

`GET /v1/catalogue` and `/v1/meta.catalogue` report source age. Nine calendar months from this export is **2027-07-05T12:19:34Z**. At that time the state becomes `refresh_due`; overdue lookups stay available with a warning. A future source date is flagged, not silently fresh. Age follows export time, never rebuild time. `/v1/catalogue` and its product route return `no-store`; `/v1/meta` retains its existing cache header. Lookup never calls OFF or silently falls back to live data. The client can explicitly request the separate live endpoint after a snapshot 404.

## Manual nine-month refresh

From repo root, using a new existing source directory and an existing index directory:

~~~powershell
New-Item -ItemType Directory -Force backend/storage/runtime/new-source
New-Item -ItemType Directory -Force backend/storage/runtime/india
backend/.venv/Scripts/python.exe scripts/acquire_india_catalogue.py --directory backend/storage/runtime/new-source
backend/.venv/Scripts/python.exe scripts/import_india_catalogue.py --input backend/storage/runtime/new-source/india-products.jsonl --directory backend/storage/runtime/india --source-url https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz --source-format off_csv_projection --coverage unverified --exported-at <source-Last-Modified-in-ISO-format>
~~~

Replace the final placeholder with the recorded source timestamp, including timezone; indexing time is not export time. Acquisition prints source/hash/count evidence. Import prints the manifest and artifact size. Set local `.env` to `CATALOGUE_DIRECTORY=storage/runtime/india` after validation and restart. The importer accepts supplied plain/gzip JSONL too; pass its actual source URL/format and use `sample` for small samples. No automatic schedule or full-market guarantee is added.

For production, validate the candidate and update the committed gzip, bundle metadata, acquisition provenance and licenses together. Run tests/build, update docs, then push; Vercel generates a new immutable bundle. Verify status, source/hash/counts and lookup before accepting the replacement. A failed build keeps the previous deployment; rollback selects a previously verified deployment/source. No bulk fetch or database write occurs in an API request. [Full refresh checklist](../docs/architecture/CATALOGUE.md).

SQLite is selected for serving; CSV/JSONL are acquisition inputs. Firestore is deferred. Richer bulk nutrition/per-record provenance is a separate v0.2.3 milestone; full India-market coverage remains unproven.

## Validate

~~~powershell
.venv/Scripts/python.exe -m pytest -q
.venv/Scripts/python.exe -m ruff check app tests
.venv/Scripts/python.exe -m ruff format --check app tests
.venv/Scripts/python.exe -m pip check
~~~

See [v0.2.2 review](../docs/planning/BACKEND_V0_2_2_REVIEW.md) for actual checks and remaining gates; earlier reviews remain historical records. Current exports/examples are indexed in [contracts](../contracts/README.md). Update docs before every push. Backend-only releases do not trigger the manual mobile workflow or change Flutter's pubspec.
