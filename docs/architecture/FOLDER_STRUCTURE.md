# Folder structure and root responsibilities

The root is the shared product repository. It coordinates the frontend, future backend, knowledge, contracts, documentation and releases. It is not another application.

| Root folder | Use |
| --- | --- |
| frontend | The single Flutter Android/iOS/web app; starter implemented |
| backend | Future FastAPI API, expanded rules and optional providers |
| knowledge | Canonical reviewed ingredients, rules, sources and translations |
| contracts | Shared API schemas/examples and compatibility policy |
| data | Shared synthetic fixtures; ignored private investigation data |
| design | Future shared semantic tokens/assets; palette undecided |
| ai | Optional dataset/experiment/evaluation/export/hosting research |
| scripts | Future knowledge validation/export/parity tools |
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
| lib/core/analysis, knowledge | Future supported offline rules and glossary/version/coverage lookup |
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

| Path | Future responsibility |
| --- | --- |
| app/api/v1 | Thin versioned HTTP routes |
| app/core, schemas | Configuration/bounds/errors and validated contract models |
| app/services/parsing | Extract/normalize fields, units, bases and provenance |
| app/services/analysis | Expanded online rules from canonical definitions |
| app/services/knowledge | Public evidence/ingredient lookup |
| app/services/personalization | Neutral reason catalog; no private profile store |
| app/providers/ai, products | Optional constrained AI and source-tagged product lookup |
| app/prompts | Reviewed evidence-constrained AI instructions |
| app/repositories, db | Read-only bundles; optional local derived-store abstraction |
| tests/unit, integration | Future rules/parity/contracts/provider-failure checks |
| storage/runtime | Ignored local stores/cache, never durable Vercel storage |

backend/.env.example is inert. No backend executable or dependencies exist yet.

## Knowledge and shared inputs

| Path | Future content |
| --- | --- |
| knowledge/sources/registry | Publisher/URL/provision/version/effective date/review/reuse rights |
| knowledge/sources/downloads | Ignored permitted local reference files |
| knowledge/ingredients | Canonical names, aliases, purpose and evidence IDs |
| knowledge/rules/claims, nutrition, allergens | Reviewed criteria, applicability and unknown behavior |
| knowledge/translations/en, hi | Reviewed bilingual glossary/result templates |
| data/fixtures/ocr, scans, expected | Synthetic regions/labels and reviewed expected/parity outcomes |
| data/private | Ignored local photos; not user-history storage |
| contracts/schemas, examples | Reserved machine definitions and validated examples |
| contracts/versioning | Version/compatibility/release-manifest policy |

Canonical rules are edited once. Client/server exports are derived and versioned; thresholds must not be independently maintained in Dart/Python.

## Design, AI and docs

design/tokens and assets reserve shared future roles/branding. ai/datasets, experiments, evaluation, export and spaces reserve optional AI research; no data/model/training exists. scripts will export/validate evidence instead of scraping regulations per scan.

docs/architecture covers system/data/API/deployment/folders; planning covers features/UI/roadmap/releases/handoff; research records source/provider/training options; decisions records accepted scope changes. [Documentation index](../README.md) links all files.

Empty future folders use .gitkeep. Reserved folders are not implemented features. Only the Flutter starter and manual release workflow execute now.
