# Documentation index

Research database checkpoint (8 October 2026): backend **v0.10.0** adds a
separate generated read-only SQLite with **243 observations** (49 manufacturer,
125 retailer and 69 OFF). It preserves dated sources, unknown identities and
formula conflicts. Three additive GETs expose researched product search,
`by-barcode/{barcode}` and `{entry_id}` under `/v1/researched/products`.
The exported API now has 24 paths/25 operations and 29 synthetic examples.
Source normalization does not import the runtime; `scripts/build_research_catalogue.py`,
the backend deployment build and `scripts/setup.py --catalogue-only` do. Runtime
files live in ignored `backend/app/research_catalogue/data/`. Frontend **v0.5.0+6**
adds mixed-source search and qualified ingredient/nutrition/source details.
Local verification and hosted/push status: [backend review](planning/BACKEND_V0_10_0_REVIEW.md) ·
[frontend review](planning/FRONTEND_V0_5_0_REVIEW.md) ·
[product list](research/POPULAR_PRODUCTS_ADDED.md).
The user's next automatic-capture/results redesign is recorded in the
[automatic scan plan](planning/AUTOMATIC_SCAN_PLAN.md).
Earlier release statements below retain their historical scope.


Current work: [frontend v0.4.0+5/backend v0.9.0 implementation plan](planning/FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md).
Backend v0.9.0 and frontend v0.4.0+5 are independently pushed/READY with
26 and 49 hosted checks respectively; all 21 OCR hashes pass. Local evidence is
1058 backend tests (five provider skips), 181 Flutter tests, clean static checks,
release web build and browser workflows. [Backend review](planning/BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](planning/FRONTEND_V0_4_0_REVIEW.md) ·
[Repository audit](research/PROJECT_AUDIT_2026_10_08.md).

Backend **v0.6.0 Product Discovery** and frontend **v0.1.0+2 Connected Label Reader**
are independently pushed, hosted-verified and published. Frontend source commit
`1138c292296ae6c9309d73d430d267ec1a98fa80` passed production asset/browser checks.
Backend **v0.7.0 Private Account Sync** is independently published and hosted-verified:
**931 tests passed, five emulator-only skips**, clean Ruff/Pyright, 18 hosted
synthetic checks and 13 fresh read-only checks. Frontend **v0.2.0+3** is
independently pushed, hosted-verified and published; its native artifact workflow
is a separate gate.
Guests keep personal data locally; optional password sign-in enables private
account profile/saved/history sync. Public package facts remain separate.

Frontend **v0.3.0+4 Visual Label Reader** is independently published and hosted-verified:
**168 Flutter tests**, clean analysis/build, local synthetic browser OCR and light
Welcome/Profile captures at 390/1440/1728px. Exact implementation
`3f9a8172c284c74e25c0c83a270c1e8cabc26bdb` has READY deployment
`dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, 49 hosted checks and all 21 OCR hashes and
[source release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0).
Hosted Welcome enters Home; Search focuses the actual input and returns ten of
57 matches. [Production receipt](research/FRONTEND_V0_3_0_PRODUCTION.json).
Later docs-only closure commits preserve that implementation identity. Backend **v0.8.0
Sourced Nutrient Comparison** is pushed and hosted-verified with 25 checks; source-release publication is not established.
the frontend remains compatible with published v0.7.0. App-only startup, unchanged
Scan/navbar design, actual Profile controls and future-only features are recorded
in the [current frontend review](planning/FRONTEND_V0_3_0_REVIEW.md) and
[next frontend/backend versions](planning/FRONTEND_BACKEND_NEXT_VERSIONS.md).

[Current account/screen plan](planning/ACCOUNT_SYNC_SCREEN_PLAN.md) ·
[Private sync architecture](architecture/PRIVATE_ACCOUNT_SYNC.md) ·
[Backend v0.7.0 review](planning/BACKEND_V0_7_0_REVIEW.md) ·
[Frontend v0.2.0 review](planning/FRONTEND_V0_2_0_REVIEW.md) ·
[Frontend v0.2.0 production proof](research/FRONTEND_V0_2_0_PRODUCTION.json) ·
[Frontend v0.1.0 production proof](research/FRONTEND_V0_1_0_PRODUCTION.json).
Native camera/OCR, installability and launcher switching remain separate gates.

| Document | Read it for |
| --- | --- |
| [Connected release history](planning/CONNECTED_RELEASE_PLAN.md) | Published backend v0.6.0 and frontend v0.1.0+2 component gates |
| [Accepted account and screen releases](planning/ACCOUNT_SYNC_SCREEN_PLAN.md) | Account/screen boundaries, honest Profile controls and independently verified current component gates |
| [Frontend v0.4.0 review](planning/FRONTEND_V0_4_0_REVIEW.md) | Exact-source comparison, bilingual ingredient evidence, camera recovery, local/rendered/hosted proof and device gates |
| [Frontend v0.4.0 production proof](research/FRONTEND_V0_4_0_PRODUCTION.json) | Exact implementation/READY deployment, 49 hosted checks and all 21 OCR hashes |
| [Frontend v0.4.0 hosted browser proof](research/FRONTEND_V0_4_0_BROWSER.json) | Ten directly observed production guest/search/report/save/navigation checks |
| [Backend v0.9.0 review](planning/BACKEND_V0_9_0_REVIEW.md) | Six reviewed ingredient functions, matching/integrity hardening, 1058 tests and 26 hosted checks |
| [Backend v0.9.0 production proof](research/BACKEND_V0_9_0_PRODUCTION.json) | Exact independent implementation/READY deployment, 26 read-only hosted checks and source hashes |
| [Frontend v0.3.0 review](planning/FRONTEND_V0_3_0_REVIEW.md) | Published local OCR, reference Welcome/Profile, search/navigation, bounded caches and remaining device gates |
| [Frontend v0.3.0 production proof](research/FRONTEND_V0_3_0_PRODUCTION.json) | Exact implementation/READY deployment, 49 hosted checks, all 21 OCR hashes and backend v0.7.0 compatibility |
| [Frontend v0.3.0 rendered checks](research/ui-v0.3.0/README.md) | Actual 390/1440/1728px light captures, app startup widget capture and Flutter DOM-measurement limits |
| [Frontend/backend version roadmap](planning/FRONTEND_BACKEND_NEXT_VERSIONS.md) | Independently completed v0.4.0/v0.9.0 scope and remaining feature/device ownership |
| [Interface contract](../DESIGN.md) | Reference visual direction, real components, evidence and accessibility boundaries |
| [Product Discovery](architecture/PRODUCT_DISCOVERY.md) | Bounded indexed Unicode search, candidate identity and cursor rules |
| [Backend v0.8.0 review](planning/BACKEND_V0_8_0_REVIEW.md) | Historical sourced comparison implementation and local checks; its separate production receipt records 25 hosted checks |
| [Sourced nutrient comparison](architecture/SOURCED_COMPARISON.md) | Strict selected-table provenance, compatible bases, signed differences and unknowns |
| [Backend v0.6.0 review](planning/BACKEND_V0_6_0_REVIEW.md) | Completed 863-test local validation, 23 hosted checks and publication |
| [Backend v0.6.0 production proof](research/BACKEND_V0_6_0_PRODUCTION.json) | Exact deployed implementation and actual catalogue/knowledge build receipts |
| [Master architecture plan](planning/MASTER_PLAN.md) | Complete scan-to-report flow, automatic confirmed-public-fact enrichment, per-field source resolution, local OCR and benchmark-gated AI |
| [Clone, restore, run](planning/LOCAL_DEVELOPMENT.md) | Setup/local-run commands, encrypted settings and committed catalogue recovery |
| [Recovery review](planning/RECOVERABLE_WORKSPACE_REVIEW.md) | Clean-copy, encryption and local process validation |
| [System](architecture/SYSTEM.md) | Stack, module boundaries, operating modes and alternatives |
| [Folder structure](architecture/FOLDER_STRUCTURE.md) | Implemented modules, reserved folders and file ownership |
| [Data flow](architecture/DATA_FLOW.md) | Full scan workflow, origins, transfers and retention |
| [API plan](architecture/API_PLAN.md) | Twenty API paths including private sync; preserved public product/claim/community/report/discovery contracts |
| [Ingredient glossary source check](research/INGREDIENT_GLOSSARY_V0_5_0.md) | Three official indexed name/function sources, direct-fetch limitations and English/Hindi project text boundaries |
| [Useful Label Report](architecture/LABEL_REPORT.md) | Released v0.5.0 current/historical reports, independent autosave, partial ingredient glossary and approximate sugar cubes |
| [Accepted v0.5.0 design](superpowers/specs/2026-10-07-useful-label-report-design.md) | Confirmed-label/historical report, partial glossary and independent save boundaries |
| [Accepted v0.5.0 plan](superpowers/plans/2026-10-07-backend-v0.5.0.md) | Report implementation and separate local/review/hosted release gates |
| [Backend v0.5.0 review](planning/BACKEND_V0_5_0_REVIEW.md) | Completed local/review evidence, twenty hosted checks and published source tag |
| [Backend v0.5.0 release scope](planning/BACKEND_V0_5_0_RELEASE.md) | Published Useful Label Report goals, partial coverage and preserved boundaries |
| [Community catalogue](architecture/COMMUNITY_CATALOGUE.md) | Implemented automatic product-fact saving, unverified candidate staging, review, source resolution and no-card quotas |
| [Accepted v0.4.0 design](superpowers/specs/2026-10-07-community-catalogue-design.md) | Confirmed package contributions and storage/privacy/source boundaries |
| [Accepted v0.4.0 plan](superpowers/plans/2026-10-07-backend-v0.4.0.md) | Implementation ownership and separate local/emulator/hosted release gates |
| [Backend v0.4.0 production proof](research/BACKEND_V0_4_0_PRODUCTION.json) | Sixteen hosted checks, matching unchanged OFF/claim receipts and synthetic cleanup |
| [Backend v0.4.0 review](planning/BACKEND_V0_4_0_REVIEW.md) | Implemented source/APIs, configured Firebase and separate local/live/hosted gates |
| [Backend v0.4.0 release notes](planning/BACKEND_V0_4_0_RELEASE.md) | Published Community Product Catalogue scope and preserved boundaries |
| [Open Food Facts](architecture/OPEN_FOOD_FACTS.md) | Selected barcode provider, normalization, provenance, caching and fallback |
| [Backend version plan](superpowers/plans/2026-10-05-backend-versions.md) | Reference screens mapped to staged backend releases |
| [Feature tracker](planning/FEATURE_TRACKER.md) | Original 20 concept groups, additional community scope and pending client work |
| [Backend v0.3.0 review](planning/BACKEND_V0_3_0_REVIEW.md) | Historical independently published reviewed-claim/code/build/hosted evidence |
| [Backend v0.3.0 release notes](planning/BACKEND_V0_3_0_RELEASE.md) | Separate confirmed-label numerical claim release and preserved boundaries |
| [Reviewed knowledge](../knowledge/README.md) | Actual seven-rule scope, three sources, hashes and packaging |
| [Fresh FSSAI source check](research/FSSAI_CLAIMS_V0_3_0_SOURCE_CHECK.json) | Bounded fresh PDF byte/hash verification against the registry |
| [Backend v0.2.3 review](planning/BACKEND_V0_2_3_REVIEW.md) | Historical rich-facts source/build/hosted evidence |
| [Backend v0.2.3 release notes](planning/BACKEND_V0_2_3_RELEASE.md) | Rich snapshot facts contract and separate backend release |
| [Accepted two-version plan](superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md) | Independently released rich facts, then reviewed confirmed-label claims |
| [Backend v0.2.2 review](planning/BACKEND_V0_2_2_REVIEW.md) | Historical CSV-source and deployment proof |
| [Backend v0.2.2 release notes](planning/BACKEND_V0_2_2_RELEASE.md) | Historical hosted identity catalogue and source-age contract |
| [Backend v0.2.2 build plan](superpowers/plans/2026-10-06-backend-v0.2.2.md) | Bounded implementation scope and completion gates |
| [Current catalogue coverage](research/CATALOGUE_V0_2_3_COVERAGE.json) | Full JSONL acquisition, strict indexed-field counts and local receipt |
| [Indian food coverage strategy](research/INDIAN_FOOD_COVERAGE.md) | Barcode/back/front paths, source selection and rights, language limits, measured gaps and proposed acquisition sequence |
| [Historical CSV coverage](research/CATALOGUE_V0_2_2_COVERAGE.json) | Earlier fields and bounded live/export count gap |
| [Historical v0.2.3 production evidence](research/BACKEND_V0_2_3_PRODUCTION.json) | Exact implementation SHA/deployments, actual build receipt and 20 public HTTP checks |
| [Historical v0.2.2 production evidence](research/BACKEND_V0_2_2_PRODUCTION.json) | Earlier implementation SHA/deployments and hosted receipt |
| [Backend v0.2.1 review](planning/BACKEND_V0_2_1_REVIEW.md) | Historical source checks, actual export/import metrics and then-pending hosted gate |
| [Backend v0.2.1 release notes](planning/BACKEND_V0_2_1_RELEASE.md) | Catalogue tooling and independent backend version |
| [Repository review](planning/PROJECT_REVIEW_V0_2_0.md) | Requested baseline files/docs review and resolved drift |
| [Catalogue storage](architecture/CATALOGUE.md) | CSV/JSONL inputs, SQLite serving, Firestore tradeoffs and bounded refresh |
| [India acquisition feasibility](research/INDIA_EXPORT_FEASIBILITY.md) | Actual source access, full acquisition and data gaps |
| [Backend v0.2.0 validation](planning/BACKEND_V0_2_0_REVIEW.md) | Historical normalization checks and v0.2.0 live verification |
| [Backend v0.2.0 release notes](planning/BACKEND_V0_2_0_RELEASE.md) | Product/nutrition contracts and the next separate data milestone |
| [Backend v0.1.0 review](planning/BACKEND_V0_1_0_REVIEW.md) | Historical product-lookup release evidence |
| [Backend v0.1.0 release notes](planning/BACKEND_V0_1_0_RELEASE.md) | Historical product-lookup deliverables |
| [OFF v3.6 nutrition research](research/OFF_NUTRITION_V3_6.md) | Verified upstream nutrition structure and narrow adapter scope |
| [Vercel setup and URLs](planning/VERCEL_SETUP.md) | Actual project roots/builds, free domains, environment and Git deployments |
| [India snapshot](research/INDIA_SNAPSHOT.md) | Actual local index, nine-month refresh and storage budgets |
| [Deployment plan](architecture/DEPLOYMENT_PLAN.md) | Two Vercel projects, generated bundles and separate Spark community storage |
| [Features](planning/FEATURES.md) | End-to-end behavior of each requested feature |
| [Roadmap](planning/ROADMAP.md) | Future implementation order and acceptance gates |
| [Teammate handoff](planning/TEAM_HANDOFF.md) | What is finished now and how to divide later work |
| [Free stack](research/FREE_STACK.md) | ₹0/no-card options, Gemini usage and alternatives |
| [Backend options](research/BACKEND_OPTIONS.md) | FastAPI versus Rust |
| [AI/training](research/AI_TRAINING.md) | Why training is optional; Hugging Face eligibility |
| [UI requirements](planning/UI_REQUIREMENTS.md) | Layout, orientation, appearance and accessibility |
| [Release/versioning](planning/RELEASE_VERSIONING.md) | Manual artifacts and client/API compatibility |
| [Evidence strategy](research/EVIDENCE_STRATEGY.md) | FSSAI, source review, retrieval, licensing and selected Open Food Facts product data |
| [Safety and privacy](SAFETY_PRIVACY.md) | Uncertainty, allergies, source integrity and data boundaries |
| [Foundation decision](decisions/001-foundation.md) | Recorded choices and reasons |
| [Updated scope](decisions/002-platforms-offline-release.md) | Shared Flutter targets, offline scope and release authorization |
| [Product-data decision](decisions/003-open-food-facts.md) | User-selected Open Food Facts provider and read-only boundaries |
