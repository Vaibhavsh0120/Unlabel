# Implementation roadmap

Checkpoint: **7 October 2026**.

Backend **v0.6.0 Product Discovery** and frontend **v0.1.0+2 Connected Label Reader**
are independently pushed, hosted-verified and published. Frontend source commit
`1138c292296ae6c9309d73d430d267ec1a98fa80` passed production asset/browser checks.
Backend **v0.7.0 Private Account Sync** is independently published and hosted-verified:
**931 tests passed, five emulator-only skips**, clean Ruff/Pyright, 18 hosted
synthetic and 13 fresh read-only checks. Frontend **v0.2.0+3** is locally tested;
its separate push, hosted verification and publication remain the active gates.
Guests keep personal data locally; optional password sign-in enables private
account profile/saved/history sync. Public package facts remain separate.

Frontend v0.2.0 provides a cute first-launch Welcome, returning-user Home,
Home/Scan/Compare/Saved navigation with top-right Profile, live camera/gallery,
manual review, live header search and reference-style reports/comparison.
Frontend v0.3.0 adds local OCR, automatic barcode decoding and Ingredient Insights.
Native/device proofs stay separate. Firebase stays free
with no linked billing, admin role, custom model or Gemini requirement.
[Accepted checklist](ACCOUNT_SYNC_SCREEN_PLAN.md) · [Tracker](FEATURE_TRACKER.md).

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
