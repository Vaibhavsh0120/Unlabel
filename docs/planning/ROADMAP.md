# Implementation roadmap

Phase 0 includes the Flutter v0.0.0 starter and manual unsigned release automation. Backend work now follows the [small version plan](../superpowers/plans/2026-10-05-backend-versions.md): v0.1.0 implements service metadata/OFF product lookup and hosting setup, while nutrition, claim checks, glossary, comparison and the India snapshot remain separate milestones. Frontend feature work belongs to the teammate. The phase table below remains the wider product roadmap; [hosting URLs and status](VERCEL_SETUP.md) distinguish today's setup from later offline/analysis features.

| Phase | Work | Acceptance |
| --- | --- | --- |
| 0. Foundation | Folders/docs, Flutter starter, light/dark selection, manual APK/unsigned IPA workflow | Layout/theme/text checks, web/APK builds, reviewed workflow and metadata |
| 1. Evidence/feasibility | Small claim/category scope, reviewed sources/rights, native/browser OCR | Real-device geometry; source registry and licensed fixtures |
| 2. Contracts/backend rules | Stable product/report schemas, canonical backend criteria | Missing values unknown; units/provenance and old-client parsing reviewed |
| 3. Online product-to-result | OFF barcode facts, backend rules/templates; OCR for claims/gaps | Source-linked online result; package/provider differences preserved |
| 4. Suitability/translation | Local preferences, English/Hindi explanations | No profile transfer; unknowns preserved; content reviewed |
| 5. Online backend/product data | Stateless FastAPI, read-only bundles, version/meta endpoints, selected Open Food Facts barcode adapter | Contract/old-client compatibility; OFF missing/conflicting/rate-limited cases, attribution and offline fallback; protected AI default |
| 6. Live overlay | Throttled native highlights; measured browser enhancement | Lifecycle/rotation/crop/stale-frame checks; no network per frame |
| 7. Optional AI | Gemini wording, eligible HF experiment | No billing/card; failure preserves deterministic findings |
| 8. Web hosting/offline | Two Vercel projects, stable API URL, explicit asset caching | Staged compatible deploy; cold/offline/update checks |
| 9. History/comparison/demo | Local deletion, compatible-basis comparison, report/demo | Reproducible evidence dates, physical-device and accessibility checks |

Work lanes: Flutter/platform/report/cache work; backend/contracts/OFF/rules work; shared evidence/translations/release work. Assign one contract/knowledge owner before parallel implementation. No duplicate device rule engine is needed.

Later validation covers salt/sodium, energy units, total/added sugar, nutrition bases, missing versus zero, applicable source dates, allergen uncertainty, offline coverage, stale bundles, AI number/citation changes, camera permissions/lifecycle, large text and same-commit artifact metadata.

Public auth and shared abuse controls precede public cloud AI. No paid model training/store membership is required for the baseline. Full Legal Metrology certification, signed iOS distribution and medical recommendations are outside this foundation.
