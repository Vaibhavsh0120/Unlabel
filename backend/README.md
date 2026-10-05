# Unlabel backend v0.1.0

Frontend remains **v0.0.0**. This backend version implements live Open Food Facts barcode lookup and service metadata. No nutrition analysis, FSSAI claim evaluator, AI explanation, comparison or database import exists yet. The [version plan](../docs/superpowers/plans/2026-10-05-backend-versions.md) keeps these as separate deliverables.

Production API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)** · [Swagger](https://unlabel-api.vercel.app/docs). Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app). Both automatically deployed from Git and passed live verification. [Deployment settings](../docs/planning/VERCEL_SETUP.md).

## Run locally

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
| `GET /v1/meta` | Backend version, API/schema/adapter versions and enabled capabilities; only product lookup is enabled |
| `GET /v1/products/{barcode}` | Fixed OFF v3.6 product read; stable typed source-tagged response |

Barcodes are ASCII digit strings of 8, 12, 13 or 14 characters. Preserve leading zeros. GTIN checksum validity is not asserted; other provider-specific code formats are outside this version. Returned identity must match the requested code, permitting leading-zero normalization only.

~~~powershell
Invoke-RestMethod http://127.0.0.1:8000/v1/meta
Invoke-RestMethod http://127.0.0.1:8000/v1/products/3017620422003
~~~

| HTTP | Lookup status | Meaning |
| --- | --- | --- |
| 200 | `found` | Available community facts, which may still be sparse |
| 404 | `not_found` | No provider record; not a food safety verdict |
| 429 | `rate_limited` | Upstream quota response; no automatic retry |
| 503 | `unavailable` | Provider/network/redirect unavailable; defer lookup |
| 502 | `incompatible_response` | Malformed/oversized data or mismatched product identity |
| 422 | FastAPI validation error | Unsupported barcode input; no provider call |

The product has name/brands/quantity text, ingredient text, source-tagged allergen/trace tags and optional OFF Nutri-Score grade/NOVA group. Missing strings/grades are null; absent tags do not prove allergen absence. No invented 0–100 score, nutrient amounts or compliance result is returned. Source metadata applies to every product field in this version and contains provider, URL, retrieval time, available modification/schema version, attribution and licenses. No raw provider internals or remote product images are exposed. Product responses use `Cache-Control: no-store`; local saved-report policy is future client work.

## Configuration and key handling

Settings load the ignored `.env` at this backend root; environment variables override the file. Do not overwrite a teammate's existing file. `.env.example` contains safe defaults. Current settings:

- `OFF_USER_AGENT`: public application identity, never a user token.
- `OFF_TIMEOUT_SECONDS`: total lookup deadline (default 8; bounded 1–15 seconds).
- `OFF_MAX_RESPONSE_BYTES`: decoded response budget (default 512 KiB; bounded 1 KiB–1 MiB).
- `CORS_ORIGINS`: JSON array of exact HTTP(S) website origins, default `[]`; no wildcard or credentialed CORS.

OFF reads require no API key. Gemini is disabled/unimplemented; the empty reserved Gemini fields in `.env` are not used by v0.1.0. Secrets must never appear in logs, API output, contracts or Git. CORS is a browser control, not authentication; native API access is not protected by it. Public cloud AI will need a separate access/budget design before activation.

## Modules and constraints

- `app/main.py`: app composition, lifespan-owned HTTP client and three small routes.
- `app/core/config.py`: validated non-secret request/CORS settings.
- `app/providers/products/open_food_facts.py`: fixed official HTTPS origin, selected fields, bounded read/deadline, identity checks and failure mapping.
- `app/schemas/products.py`: versioned normalized product/status/provenance models.
- `tests/`: synthetic mocked-provider and ASGI contract tests; no corpus copied from OFF.
- `requirements*.txt`, `pyproject.toml`: tested dependency versions and backend metadata/tooling.

HTTPX connection pool is bounded to six connections. There is no automatic retry, durable cache, process-wide global quota guarantee, profile/history storage or image upload. OFF records remain community data; confirmed package facts and reviewed criteria are later analysis inputs.

The [India snapshot/storage proposal](../docs/research/INDIA_SNAPSHOT.md) is a future data milestone: official bulk export, India market filter, compact read-only index, manual six-month refresh and measured storage budget. No dataset was downloaded. Vercel uses root `backend`, framework FastAPI, Python 3.12 and the tracked entrypoint/config. Local `.env` stays ignored; hosted settings live in the backend project's environment.

## Validate

~~~powershell
.venv/Scripts/python.exe -m pytest -q
.venv/Scripts/python.exe -m ruff check app tests
.venv/Scripts/python.exe -m ruff format --check app tests
.venv/Scripts/python.exe -m pip check
~~~

See [v0.1.0 review](../docs/planning/BACKEND_V0_1_0_REVIEW.md) for the actual results and remaining gates. Update docs before every push. Backend-only releases do not trigger the manual mobile workflow or change Flutter's pubspec.
