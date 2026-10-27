# Folder structure and root responsibilities

Updated **15 October 2026** against the canonical component manifests.
The root coordinates component source, knowledge, contracts, documentation and
releases. Empty foundation scaffolding is removed; the map below describes
retained source, with future capabilities recorded in plans instead of empty
implementation directories.

| Root path | Responsibility |
| --- | --- |
| `frontend/` | One Flutter Android/iOS/web client |
| `backend/` | Shared FastAPI API, immutable catalogue builds and backend tests |
| `knowledge/` | Canonical reviewed claim rules and source metadata; ignored permitted local reference downloads |
| `contracts/` | Current exported schemas/synthetic examples, preserved historical OpenAPI and compatibility/release policy |
| `data/` | Tracked public catalogue source/provenance/licenses; ignored private development inputs |
| `design/` | Supplied interface references and their provenance |
| `ai/` | Optional training research documentation; no trained model or dataset |
| `scripts/` | Setup, local launch, encrypted settings, source acquisition/import, contracts and release maintenance |
| `docs/` | Current architecture/plans, historical reviews and dated evidence |
| `.github/workflows/` | Push/PR checks and automatic frontend version releases; native artifacts separate from hosted deployment |

Root README introduces current status; CONTRIBUTING sets boundaries and DESIGN
records the Flutter reference adaptation. `.gitignore` protects generated,
private and secret files. [Documentation index](../README.md).

The `scripts/` root keeps setup, run and encrypted-environment entry points.
One level below, `dev/` contains local-run helpers, `release/` contains validation
and publication, `data/` contains catalogue tools, `ai/` contains operator provider
setup, and `config/` contains public configuration. `tests/` holds script tests;
`tools/` documents ignored downloaded executables such as Caddy. Generated logs,
local TLS keys and other temporary output stay under ignored `output/`.

## Frontend source

| Path under `frontend/` | Actual responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app/` | App composition, appearance, theme, web bridge, public Firebase/build configuration |
| `lib/core/accounts/` | Password auth, isolated UID local store, private snapshot API, CAS/retry/conflict handling |
| `lib/core/capture/` | Camera/gallery lifecycle, captured barcode decode, native/browser OCR, local parsing, geometry and optional cloud fallback |
| `lib/core/models/` | Validated label drafts, extracted facts, sourced reports/comparison, research records and typed failures |
| `lib/core/network/` | Bounded requests, metadata handshake, scanner auth and short-lived public read caches |
| `lib/core/storage/`, `interaction/`, `widgets/` | Local library/appearance storage, shared feedback, brand and search skeleton |
| `lib/features/account/` | Device-local dietary/allergen choices and Profile/sign-in/private-sync presentation |
| `lib/features/scanner/domain/` | Twenty reviewed Insight articles and shared daily/bookmark controller |
| `lib/features/scanner/presentation/` | Home, scan, search, reports/research, comparison, ingredient/source detail, Saved/history, Insights and navigation |
| `android/`, `ios/` | Maintained native projects, bridges, permissions, launch/icon resources and platform metadata |
| `web/` | Web bootstrap/appearance/icons plus pinned same-origin OCR worker/Wasm/language assets and licenses |
| `assets/icons/`, `assets/artwork/` | Licensed Solar icons, authored food symbols and decorative artwork; original provenance retained |
| `assets/brand/` | App icon masters/manifest, fonts and license/source records |
| `test/` | Core, lifecycle, extraction, network/storage and responsive widget tests; OCR bridge tests |
| `tool/` | Synthetic preview/render helpers and Vercel release web build |
| `config/` | Public backend/environment policy documentation |

`pubspec.yaml` declares the app/dependencies; `pubspec.lock` is tracked. Generated
SDKs, `.dart_tool`, builds and transient platform state stay ignored. Conditional
`local_ocr_stub.dart` and `web_appearance_stub.dart` are portability adapters,
not unused scaffolding. Comparison/history/ingredient detail are implemented in
scanner presentation; no duplicate reserved feature module is required.

## Backend source

| Path under `backend/` | Actual responsibility |
| --- | --- |
| `app/main.py` | Composition/lifespan, **30 paths / 32 operations**, capability isolation and redacted failures |
| `app/core/` | Validated settings/CORS, actual-byte request limits and numeric token validation |
| `app/api/v1/` | Account, claim, community, report/glossary and comparison routes |
| `app/accounts/` | Password-owned private snapshots, CAS mutations, quotas and explicit clear |
| `app/ai/` | Scanner photo extraction, server-only credentials, global selection/cooldowns, quotas, private proposals and separate immutable machine observations |
| `app/live_products/` | Optional bounded session-only NutriGraph adapter; no permanent catalogue writes |
| `app/catalogue/` | Strict bulk-source identity/facts contracts, staged imports, read-only lookup/search and verified bundle |
| `app/research_catalogue/` | Separate immutable research search/details, strict observation provenance and validated URL descriptors |
| `app/claims/` | Seven numerical rules, read-only catalogue comparisons, source knowledge loader and receipt-verified two-file bundle |
| `app/community/` | Observations, normalized hashes/dedup, auth, transactions and compatible-field resolution |
| `app/comparison/` | Exact-source table selection, compatible nutrient comparisons and limitations |
| `app/reports/` | Current/historical sourced reports, original-basis sugar cubes and six-entry glossary; v1 glossary retained historically |
| `app/providers/products/`, `app/services/parsing/` | Fixed-origin OFF reads, direct nutrition adapter and pure unit/basis normalization |
| `app/schemas/` | Strict product/nutrition/error contracts |
| `build_catalogue.py` | Network-free bulk/research SQLite and approved claim-knowledge build; emits three receipts |
| `tests/unit/`, `tests/integration/` | Provider/parser/source, API/contract, storage/auth, AI and process-boundary checks |
| `storage/runtime/` | Ignored rebuildable local databases; no durable hosted user storage |

Builds generate ignored `app/catalogue/data/`, `app/claims/data/` and
`app/research_catalogue/data/`. SQLite/receipts are not tracked source. Hosted
startup verifies each artifact independently. `pyproject.toml`/requirements lock
files declare the Python runtime/dependencies; Vercel packaging is component-local.

## Shared source and local recovery

`data/catalogue/` retains the original **24,641** supported OFF codes and the
separate **243** immutable popular-product observations. No catalogue/research
record is removed by scaffold cleanup. Images are attributed URL descriptors;
generated decorative artwork is never product evidence. [Catalogue](CATALOGUE.md).

`knowledge/rules/claims/reviewed-v1.json` and
`knowledge/sources/registry/fssai-claims-v1.json` are the only canonical claim
inputs. Current ingredient functions live in the separate backend glossary.
Historical contracts/review receipts and source/license records remain retained.

`backend/.env.age` and the public age recipient support encrypted recovery.
Plaintext settings and private identities remain ignored. Restore with
`python scripts/setup.py`; launch with `python scripts/run_local.py`. Setup
rebuilds generated databases without another global export. The purposeful empty
locations `data/private/`, `backend/storage/runtime/` and
`knowledge/sources/downloads/` remain for ignored owned inputs/outputs.
[Clone/run guide](../planning/LOCAL_DEVELOPMENT.md).

The previous v0.3/v0.4 frontend and v0.9 backend maps were historical checkpoints.
Their source/release identities remain in component reviews; removed empty
foundation directories did not implement the capabilities described by those plans.
