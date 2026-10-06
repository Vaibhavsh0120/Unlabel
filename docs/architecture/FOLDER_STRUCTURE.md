# Folder structure and root responsibilities

The root is the shared product repository. It coordinates the frontend, backend, knowledge, contracts, documentation and releases. It is not another application.

| Root folder | Use |
| --- | --- |
| frontend | The single Flutter Android/iOS/web app; starter implemented |
| backend | FastAPI v0.3.0 product/nutrition lookup, normalization, verified catalogue/status/rich facts and reviewed confirmed-label claim subset; optional AI remains future |
| knowledge | Canonical reviewed ingredients, rules, sources and translations |
| contracts | Shared API schemas/examples and compatibility policy |
| data | Tracked public India source/provenance/licenses and synthetic fixtures; ignored private investigation data |
| design | Supplied concept references and reserved shared tokens/assets; palette undecided |
| ai | Optional dataset/experiment/evaluation/export/hosting research |
| scripts | Setup/local launcher, encrypted env recovery, catalogue acquisition/import and contract/dependency maintenance |
| docs | Architecture, planning, source research and decisions |
| .github/workflows | Manual APK/unsigned IPA build and release |

Root README introduces readiness; CONTRIBUTING sets boundaries; .gitignore protects secrets/generated/private data; .editorconfig standardizes text conventions.

## Frontend

| Path | Responsibility |
| --- | --- |
| lib/main.dart | Flutter entry point |
| lib/app | App composition, appearance state and injected build metadata |
| lib/core/models | Future shared scan/coordinate/nutrient/result models |
| lib/core/camera, ocr | Future native/browser capture, OCR and geometry adapters |
| lib/core/analysis, knowledge | Future report models/presentation, evidence/version status and optional local glossary |
| lib/core/network, storage | Future API adapter and device/browser-local preferences/history |
| lib/core/localization, theme, widgets | Future bilingual copy, semantic light/dark roles and shared widgets |
| lib/features/scanner | Capture/correction flow; currently the starter screen only |
| lib/features/analysis | Future findings, evidence and charts |
| lib/features/preferences | Future local dietary/allergy choices |
| lib/features/ingredient_details | Future ingredient explanations and source details |
| lib/features/history, comparison | Future saved scans and compatible-basis comparisons |
| features/*/presentation | Views/view models |
| features/*/data | Feature repositories/adapters |
| android | Generated Android Gradle, manifest and resources |
| ios | Generated Xcode project, orientations and resources |
| web | Generated Flutter web bootstrap/manifest/icons, not React |
| assets/images, icons | Future licensed visual assets |
| assets/knowledge, l10n | Future derived bundles and reviewed bilingual content |
| test/unit, test/widget | Reserved focused tests; starter checks at test/widget_test.dart |
| integration_test | Reserved real-device journeys |
| config | Non-secret backend/environment policy |

frontend/pubspec.yaml defines current app/dependency versions; pubspec.lock is tracked. build and .dart_tool are ignored.

## Backend

Tracked `backend/.env.age` holds encrypted recovery settings; plaintext and private identities stay outside Git. `scripts/setup.py` restores dependencies/env/catalogue; `run_local.py` runs local services and `env.py` handles age. PowerShell wrappers support direct Windows use. `workspace.json` stores shared toolchain/port defaults; `age-recipient.txt` is public. `data/catalogue/` holds the reusable public bundle; `design/references/` retains supplied concepts. [Clone guide](../planning/LOCAL_DEVELOPMENT.md).

| Path | Responsibility / implementation status |
| --- | --- |
| app/main.py | App composition/lifespan, eleven versioned routes, independently verified catalogue/knowledge activation and redacted validation errors |
| app/api/v1/claims.py | Implemented confirmed claim checks, loaded rules and public evidence metadata |
| app/claims | Strict claim models, numerical engine, bounded reviewed knowledge loader and receipt-verified bundle builder |
| app/claims/data | Ignored generated two-file knowledge JSON/receipt; validated before hosted claim activation |
| app/core | Validated environment/CORS settings and actual-byte request-body limit |
| app/schemas/products.py | Unchanged strict product lookup v1 contract and OFF provenance |
| app/schemas/nutrition.py, nutrition_products.py | Confirmed nutrient rows, basis/unit validation, snapshots and separate origin wrappers |
| app/catalogue/models.py, status.py | Export-origin identity/manifest contracts and typed source-age/artifact status |
| app/catalogue/importer.py, store.py | Bounded staged imports and exact indexed read-only lookup |
| app/catalogue/bundle.py | Validate tracked bundle, generate/verify SQLite receipt and reject damaged deployment artifacts |
| build_catalogue.py | Networkless Vercel/local build entrypoint for generated catalogue plus approved claim-knowledge bundle; stdout has both receipts |
| app/catalogue/data | Ignored build-generated immutable SQLite/receipt; included in the hosted function after validation |
| app/services/parsing/nutrition.py | Pure unit/basis normalization, missing values, conflicts and source-row references |
| app/services/analysis | Reserved for broader analysis/report orchestration; current claim evaluator is app/claims/ |
| app/services/knowledge | Reserved for broader ingredient/knowledge lookup; current evidence API uses app/claims/ |
| app/services/personalization | Reserved neutral reason catalog; no private profile store |
| app/providers/products | Fixed-origin OFF product read and narrow direct-input nutrition adapter |
| app/providers/ai, app/prompts | Reserved optional constrained AI; no provider call enabled |
| app/repositories, db | Reserved read-only bundle/derived-store abstraction |
| tests/unit, integration | Product/provider/API and nutrition/bounds/contract regression tests |
| storage/runtime | Ignored local stores/cache, never durable Vercel storage |

backend/.env.example documents implemented settings; ignored backend/.env holds local values. pyproject.toml and requirements files declare the runnable service. backend/vercel.json, .python-version and .vercelignore configure hosted packaging. frontend/vercel.json and tool/vercel-build.sh supply the pinned release web build; Flutter source/version are unchanged.

## Knowledge and shared inputs

| Path | Future content |
| --- | --- |
| knowledge/sources/registry | Publisher/URL/provision/version/effective date/review/reuse rights |
| knowledge/sources/downloads | Ignored permitted local reference files |
| knowledge/ingredients | Canonical names, aliases, purpose and evidence IDs |
| knowledge/rules/claims, nutrition, allergens | Reviewed criteria, applicability and unknown behavior |
| knowledge/translations/en, hi | Reviewed bilingual glossary/result templates |
| data/fixtures/ocr, scans, expected | Synthetic regions/labels and reviewed backend-rule/contract outcomes |
| data/private | Ignored local photos; not user-history storage |
| contracts/schemas, examples | Current v0.3.0 OpenAPI/claim/evidence/status/catalogue/facts/nutrition/error schemas and synthetic examples; historical exports and product/catalogue v1 preserved |
| contracts/versioning | Version/compatibility/release-manifest policy |

Canonical rules are edited once and packaged for the backend. The online-first MVP does not require a Dart rule engine; limited offline content retains its source/date/version instead of making fresh verdicts.

## Design, AI and docs

design/tokens and assets reserve shared future roles/branding. ai/datasets, experiments, evaluation, export and spaces reserve optional AI research; no data/model/training exists. scripts/export_backend_contracts.py regenerates current backend contracts and synthetic examples without overwriting historical OpenAPI/product v1. The combined build now validates/packages the approved claim/evidence JSON; later glossary tools remain planned. No regulation scraping runs per scan.

docs/architecture covers system/data/API/deployment/folders; planning covers features/UI/roadmap/releases/handoff; research records source/provider/training options; decisions records accepted scope changes. [Documentation index](../README.md) links all files.

Empty future folders use .gitkeep. Reserved folders are not implemented features. The Flutter starter, FastAPI product/nutrition service, Vercel web build and manual mobile workflow execute; broader health analysis remains future work. The seven-rule claim scope and three-source registry are populated; ingredient/allergen/glossary folders remain reserved. No model is trained.

`data/catalogue/` is the tracked reusable source/provenance/license bundle. Setup rebuilds ignored local SQLite in `backend/storage/runtime/india/`; explicit acquisition retains only a compact India projection. The separate `backend/build_catalogue.py` hook generates ignored SQLite/receipt in `backend/app/catalogue/data/` for hosted packaging without another export download. Generated artifacts are verified at startup and read only; manual source changes create a new immutable deployment rather than runtime writes. [Catalogue guide](CATALOGUE.md) and [v0.2.3 source/build/hosted gates](../planning/BACKEND_V0_2_3_REVIEW.md).

Canonical `knowledge/rules/claims/reviewed-v1.json` and `knowledge/sources/registry/fssai-claims-v1.json` supply version `claims-2026-10-06.1`. The network-free build copies only these validated files and a receipt, never source PDFs. Current claim/build/deployment gates are in the [v0.3.0 review](../planning/BACKEND_V0_3_0_REVIEW.md).
