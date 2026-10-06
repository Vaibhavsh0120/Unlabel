# Folder structure and root responsibilities

The root is the shared product repository. It coordinates the frontend, backend, knowledge, contracts, documentation and releases. It is not another application.

| Root folder | Use |
| --- | --- |
| frontend | The single Flutter Android/iOS/web app; starter implemented |
| backend | FastAPI v0.2.1 product/nutrition lookup, normalization and optional indexed catalogue; future rules and optional AI |
| knowledge | Canonical reviewed ingredients, rules, sources and translations |
| contracts | Shared API schemas/examples and compatibility policy |
| data | Shared synthetic fixtures; ignored private investigation data |
| design | Future shared semantic tokens/assets; palette undecided |
| ai | Optional dataset/experiment/evaluation/export/hosting research |
| scripts | Current backend contract exporter and reserved evidence maintenance tools |
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

| Path | Responsibility / implementation status |
| --- | --- |
| app/main.py | App composition/lifespan, five versioned routes and redacted validation errors |
| app/api/v1 | Reserved route modules as future endpoints grow |
| app/core | Validated environment/CORS settings and actual-byte request-body limit |
| app/schemas/products.py | Unchanged strict product lookup v1 contract and OFF provenance |
| app/schemas/nutrition.py, nutrition_products.py | Confirmed nutrient rows, basis/unit validation, snapshots and separate origin wrappers |
| app/services/parsing/nutrition.py | Pure unit/basis normalization, missing values, conflicts and source-row references |
| app/services/analysis | Reserved for reviewed FSSAI/evidence evaluation |
| app/services/knowledge | Reserved for public evidence/ingredient lookup |
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
| contracts/schemas, examples | Current v0.2.1 OpenAPI/catalogue/nutrition/error schemas and synthetic examples; historical v0.1.0 and product v1 preserved |
| contracts/versioning | Version/compatibility/release-manifest policy |

Canonical rules are edited once and packaged for the backend. The online-first MVP does not require a Dart rule engine; limited offline content retains its source/date/version instead of making fresh verdicts.

## Design, AI and docs

design/tokens and assets reserve shared future roles/branding. ai/datasets, experiments, evaluation, export and spaces reserve optional AI research; no data/model/training exists. scripts/export_backend_contracts.py regenerates current backend contracts and synthetic examples without overwriting historical OpenAPI/product v1. Future scripts will export/validate reviewed evidence instead of scraping regulations per scan.

docs/architecture covers system/data/API/deployment/folders; planning covers features/UI/roadmap/releases/handoff; research records source/provider/training options; decisions records accepted scope changes. [Documentation index](../README.md) links all files.

Empty future folders use .gitkeep. Reserved folders are not implemented features. The Flutter starter, FastAPI product/nutrition service, Vercel web build and manual mobile workflow execute; health/claim analysis remains future work. Normalization does not fill the regulatory knowledge folders or train a model.

Active catalogue modules are under `backend/app/catalogue/`: `models.py` holds independent export contracts, `importer.py` validates/stages atomic replacements, and `store.py` provides indexed read-only queries. Ignored `backend/storage/runtime/india/` holds the local active SQLite database; ignored dated source directories hold acquisition evidence/projections. `scripts/acquire_india_catalogue.py` acquires/filter-projects the official TSV; `scripts/import_india_catalogue.py` builds the index. No corpus is committed or automatically uploaded to Vercel. [Catalogue guide](CATALOGUE.md).
