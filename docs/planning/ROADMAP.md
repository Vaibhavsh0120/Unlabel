# Implementation roadmap

Checkpoint **7 October 2026**: backend **v0.6.0 Product Discovery** is independently
published with 863 backend tests passed, five emulator-only skips and 23 hosted
checks. Historical v0.5.0/v0.4.0 remain independently published. Frontend
**v0.1.0+2 Connected Label Reader** implements manual lookup, correction, reports,
local saved/history and light-default appearance; final rendered/release gates
remain pending. [Current plan](CONNECTED_RELEASE_PLAN.md) ·
[Review](BACKEND_V0_6_0_REVIEW.md) · [Tracker](FEATURE_TRACKER.md).

Next accepted **backend v0.7.0/frontend v0.2.0** adds optional scanner login/profile
and private sync after login. Guests retain useful local workflows. Complete the
reference-style light/dark screens one at a time, beginning with a cute first-launch
Welcome and Home, and give every visible action a working destination. The local
Welcome completion flag sends returning users directly to Home. Comparison and
reviewed insight destinations require sourced facts and honest missing states.
[Next accepted plan](ACCOUNT_SYNC_SCREEN_PLAN.md).

Keep automatic public product observations separate from private personal sync.
Firebase remains free/no linked billing; no admin/reviewer app role, custom model,
Gemini requirement or universal score. Camera/OCR/native/device validation is a
separate measured gate. The broad phases below describe remaining architecture,
not completion claims.

| Phase | Work | Acceptance |
| --- | --- | --- |
| 0. Foundation | Folders/docs, Flutter starter, light/dark selection, manual APK/unsigned IPA workflow | Layout/theme/text checks, web/APK builds, reviewed workflow and metadata |
| 1. Evidence/feasibility | Small claim/category scope, reviewed sources/rights, native/browser OCR | Real-device geometry; source registry and licensed fixtures |
| 2. Contracts/backend rules | Stable product/report schemas, canonical backend criteria | Missing values unknown; units/provenance and old-client parsing reviewed |
| 3. Online product-to-result | OFF barcode facts, backend rules/templates; OCR for claims/gaps | Source-linked online result; package/provider differences preserved |
| 4. Suitability/translation | Local preferences, English/Hindi explanations | No profile transfer; unknowns preserved; content reviewed |
| 5. Online backend/product data | Existing immutable OFF/claim bundles and implemented automatic public observations, staging and per-field derived view | Old-client compatibility, dedup/review/source provenance/quota and independent analysis; no paid fallback |
| 6. Live overlay | Throttled native highlights; measured browser enhancement | Lifecycle/rotation/crop/stale-frame checks; no network per frame |
| 7. Optional AI | Gemini wording, eligible HF experiment | No billing/card; failure preserves deterministic findings |
| 8. Web hosting/offline | Two Vercel projects, stable API URL, explicit asset caching | Staged compatible deploy; cold/offline/update checks |
| 9. History/comparison/demo | Local deletion, compatible-basis comparison, report/demo | Reproducible evidence dates, physical-device and accessibility checks |

Work lanes: Flutter/platform/report/cache work; backend/contracts/OFF/rules work; shared evidence/translations/release work. Assign one contract/knowledge owner before parallel implementation. No duplicate device rule engine is needed.

Later validation covers salt/sodium, energy units, total/added sugar, nutrition bases, missing versus zero, applicable source dates, allergen uncertainty, offline coverage, stale bundles, AI number/citation changes, camera permissions/lifecycle, large text and same-commit artifact metadata.

Public auth and shared abuse controls precede public cloud AI. No paid model training/store membership is required for the baseline. Full Legal Metrology certification, signed iOS distribution and medical recommendations are outside this foundation.
