# Unlabel backend versions implementation plan

> **For agentic workers:** Implement one version at a time with source review, meaningful tests and recorded validation before publishing. Do not implement the whole roadmap in one sitting.

**Goal:** Give the Flutter teammate a stable online-first backend, starting with a usable barcode product-data API.

**Architecture:** One stateless FastAPI backend. Open Food Facts (OFF) provides product data/computed insights; Python owns reviewed FSSAI/evidence checks. Client history/preferences remain local. Provider schemas stay behind versioned Unlabel models.

**Tech stack:** Python 3.12+, FastAPI, Pydantic Settings, HTTPX, pytest and Ruff. Local `.env`; no API key needed for public OFF reads. Gemini disabled initially.

**Spec:** [Product workflow](../../architecture/OPEN_FOOD_FACTS.md), [API boundaries](../../architecture/API_PLAN.md), and the five user-supplied reference images on 5 October 2026.

## Global constraints

- Backend implementation only; shared contracts/docs may change. The user subsequently authorized Vercel backend/web settings, public domains and a Flutter web build script. Do not edit Flutter feature source/version or rebuild APK/IPA.
- ₹0/no card; no paid account, trained model or cloud user database. Configure only the user's existing Hobby projects for this hosting setup.
- Each backend version has its own source commit/tag/release. Flutter stays at its independent version.
- Missing values remain unknown; package-confirmed fields take priority over community data.
- Reference image numbers/text are illustrative, not a dataset, formula or approved policy. No invented 85/100 score, medical guarantee or blanket legal certification.
- Plaintext secrets stay in ignored `backend/.env`; authenticated age ciphertext/public recipient are tracked for recovery. Private identities stay outside Git. Tracked `.env.example` contains safe settings only.

## Screens mapped to backend work

| Reference | Backend responsibility | Client responsibility / boundary |
| --- | --- | --- |
| Home | Product lookup; later reviewed insight content | Navigation, saved products, recent history/preferences local |
| Scan label | Later confirmed-text/region-ID intake and analysis | Camera, OCR, geometry, correction and live overlay stay client-side |
| Analysis | Product facts, compatible nutrition bases, criterion findings and evidence | Render charts/saved reports; no invented overall score |
| Comparison | Later compare compatible bases with missing-data reasons | Pick products/render; avoid a universal healthier winner |
| Ingredient insights | Later reviewed aliases/explanations/allergen facts and claims | Local preference matching; provider tags do not prove allergy safety |

## Version roadmap

| Version | Deliverable | Gate |
| --- | --- | --- |
| **v0.1.0 — complete** | Runnable API; `/v1/health`, `/v1/meta`, `/v1/products/{barcode}`; OFF identity/ingredients/allergen tags/computed grades; provenance/failure states; verified Vercel hosting | Found/sparse/missing records, input and identity validation, malformed/oversized responses, timeout/rate limit, CORS, version/schema tests |
| **v0.2.0 — complete** | Separate OFF nutrition lookup and confirmed structured nutrition-row normalization; preserved original rows/bases/sources; no health/claim analysis | Verified live upstream nutrition, strict units/numbers, 100 g/100 mL/serving, zero vs missing, total/added sugar and sodium/salt separation, 32 KiB intake/64-row/16-upstream-table bounds; [review](../../planning/BACKEND_V0_2_0_REVIEW.md) |
| **v0.2.1 — local tooling/data complete** | Official CSV acquired, India identity projection and 11.44 MiB SQLite index; optional separate catalogue route | 21,138 supported records, explicit unknowns/count gap; [review](../../planning/BACKEND_V0_2_1_REVIEW.md) |
| **v0.2.2 — hosted catalogue implementation** | Networkless tracked-gzip build, verified SQLite/receipt, typed catalogue status and source-age warnings | Actual hosted file/hash/read verification recorded in [review](../../planning/BACKEND_V0_2_2_REVIEW.md); nine-calendar-month immutable deployment replacement/rollback; coverage remains unverified and misses make no OFF call |
| v0.2.3 — richer source acquisition | Validate/acquire selected direct nutrition, canonical allergen and per-record provenance fields from suitable licensed bulk source | Measure source fields/size/count gaps before implementation; preserve missing-data and origin boundaries; no live API bulk pagination or false complete-market claim |
| v0.3.0 | Small reviewed FSSAI claim-check scope and evidence endpoints | Current authoritative provisions, effective dates/category exceptions; supported/contradicted/insufficient-information fixtures |
| v0.4.0 | Ingredient glossary/INS aliases and reviewed English/Hindi explanation templates | Reuse rights, allergen uncertainty and translation preserving facts/units |
| v0.5.0 | Product comparison and neutral suitability facts | Compatible bases/categories; missing data; no profiles sent to backend; evidence-based reasons |
| v0.6.0 | Optional Gemini wording | User-supplied backend-only key, eligible free quota, public facts only, immutable numbers/verdicts/references, template fallback |
| v0.7.0 | Hosting hardening and optional reviewed insight feed | Vercel staging, HTTPS/old-client compatibility, request/abuse bounds, source review and measured provider availability |

Versions after v0.2.2 are plans. Richer source acquisition may split further if feasibility or tests justify it. The frontend remains v0.0.0+1, and backend releases do not rebuild mobile assets.

## v0.1.0 tasks

- [x] Define settings/version and typed product/status/provenance models in `backend/app/core/` and `backend/app/schemas/`.
- [x] Write failing provider tests under `backend/tests/unit/`: preserve leading-zero barcode, normalize found/sparse facts, refuse unrelated identity, map timeout/429/missing/malformed/oversized data, no fabricated nutrient/health verdicts.
- [x] Implement `OpenFoodFactsProvider.lookup(barcode: str) -> ProductLookup` under `backend/app/providers/products/`; fixed official HTTPS origin/API v3.6, selected fields, custom User-Agent, bounded response/total deadline, redirects disabled and no automatic retries.
- [x] Implement `create_app(settings, transport)` in `backend/app/main.py` with lifespan-owned HTTP client, injectable mocked transport, exact-origin CORS and three versioned GET routes.
- [x] Test API input/status mappings, metadata disabled capabilities, independent health readiness, CORS and OpenAPI schema.
- [x] Export validated contracts/examples for the Flutter teammate; document environment/run commands and limitations.
- [x] Run pytest, Ruff, dependency consistency, schema checks and local HTTP smoke. Perform only a small public OFF smoke if reachable; record failure honestly.
- [x] Review diff/source and key hygiene, push and verify user-authorized automatic Vercel deployments. No mobile action.
- [x] Prepare [Backend v0.1.0 release notes](../../planning/BACKEND_V0_1_0_RELEASE.md) with checks/limits. Tag/publication follows the final documentation commit; the GitHub release records publication state.

## Review focus

- Provider timeout/rate limit must return a stable retryable state, not a 500/raw provider exception.
- Missing/empty ingredients/allergen tags cannot become allergy-free or zero-nutrient findings.
- Returned barcode identity must match requested code, allowing only documented leading-zero normalization.
- Provider strings are untrusted data; do not expose arbitrary URLs/schema or execute embedded content.
- Health/meta must work without a successful external call and must report future analysis/AI capabilities disabled.

## v0.2.0 handoff

Current code adds `GET /v1/products/{barcode}/nutrition` and `POST /v1/nutrition/normalize`, preserving the strict ProductLookup v1 response. The [API plan](../../architecture/API_PLAN.md), [backend guide](../../../backend/README.md), and [shared contract index](../../../contracts/README.md) describe actual input/output models and capability flags. The release-specific review records local checks, public provider feasibility and deployment verification without assuming successful publication from a build alone.

OFF v3.6 `nutrition.input_sets` is verified with bounded live Nutella/Coca-Cola reads. Only eligible direct values from packaging/manufacturer tables enter normalization; provider computed sets, estimates and qualified modifiers are excluded. Source/preparation/bases remain visible. A normalization result is a data transformation, not a health score, allergy judgment or FSSAI verdict. Bulk India download/replacement stays outside this release.
