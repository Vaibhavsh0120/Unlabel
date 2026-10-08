# Implementation roadmap

Current review checkpoint (8 October 2026): backend **v0.9.0** is pushed and
READY with **26 hosted checks**; frontend **v0.4.0+5** passes **181 tests**,
analysis, release web build and synthetic browser workflow checks. Its
independent push/deployment verification is the remaining release gate.
[Backend review](BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](FRONTEND_V0_4_0_REVIEW.md).

Checkpoint: **8 October 2026**.

Backend v0.8.0 was pushed from `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` and hosted-verified with 25 checks at READY deployment `dpl_651iY8R8Dj6wNEdVC71Kw3ZW4oig`; its source-release publication is not established by that receipt.
Frontend v0.3.0+4 is independently published and hosted-verified with 168
Flutter tests and 49 hosted checks. Current implementation slices are **backend v0.9.0 Reviewed Ingredient Functions** and **frontend v0.4.0+5 Sourced Comparison and Ingredient Detail**. Each receives independent tests, review, documentation, push and exact-source hosted checks. See [the implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md).

Guests retain device-local personal records; optional password accounts have
separate private sync. Preserve Scan/navbar and the existing botanical brand.
Automatic live barcode decoding, highlights, notifications, personal suitability
and physical-device OCR acceptance remain future gates. No Gemini or billing.
[Tracker](FEATURE_TRACKER.md) records per-feature implementation evidence.

| Phase | Work | Acceptance |
| --- | --- | --- |
| 0. Foundation | Folders/docs, Flutter starter, light/dark selection, manual APK/unsigned IPA workflow | Layout/theme/text checks, web/APK builds, reviewed workflow and metadata |
| 1. Evidence/feasibility | Small claim/category scope, reviewed sources/rights, native/browser OCR | Real-device geometry; source registry and licensed fixtures |
| 2. Contracts/backend rules | Stable product/report schemas, canonical backend criteria | Missing values unknown; units/provenance and old-client parsing reviewed |
| 3. Online product-to-result | OFF barcode facts, backend rules/templates; OCR for claims/gaps | Source-linked online result; package/provider differences preserved |
| 4. Suitability/translation | Local dietary preferences and English/Hindi explanations; optional private account display name/library sync is separate | Dietary/health preferences are not part of current private sync; unknowns preserved; content reviewed |
| 5. Online backend/product data | Existing immutable OFF/claim bundles and implemented automatic public observations, staging and per-field derived view | Old-client compatibility, dedup/review/source provenance/quota and independent analysis; no paid fallback |
| 6. Live overlay | Throttled native highlights; measured browser enhancement | Lifecycle/rotation/crop/stale-frame checks; no network per frame |
| 7. Optional AI | Gemini wording, eligible HF experiment | No billing/card; failure preserves deterministic findings |
| 8. Web hosting/offline | Two Vercel projects, stable API URL, explicit asset caching | Staged compatible deploy; cold/offline/update checks |
| 9. History/comparison/demo | Local deletion, compatible-basis comparison, report/demo | Reproducible evidence dates, physical-device and accessibility checks |

Work lanes: Flutter/platform/report/cache work; backend/contracts/OFF/rules work; shared evidence/translations/release work. Assign one contract/knowledge owner before parallel implementation. No duplicate device rule engine is needed.

Later validation covers salt/sodium, energy units, total/added sugar, nutrition bases, missing versus zero, applicable source dates, allergen uncertainty, offline coverage, stale bundles, AI number/citation changes, camera permissions/lifecycle, large text and same-commit artifact metadata.

Public auth and shared abuse controls precede public cloud AI. No paid model training/store membership is required for the baseline. Full Legal Metrology certification, signed iOS distribution and medical recommendations are outside this foundation.
