# Documentation map

Frontend remains v0.0.0. Backend v0.2.1 implements health/meta, live OFF product/nutrition lookup, confirmed nutrition-row normalization and optional local indexed catalogue lookup. Scanner, claims, scoring and AI documents describe later behavior; the backend README and current OpenAPI describe today's API. Source research was checked on 5–6 October 2026; provider/source eligibility must be reviewed before use.

| Document | Read it for |
| --- | --- |
| [Clone, restore, run](planning/LOCAL_DEVELOPMENT.md) | Setup/local-run commands, encrypted settings and committed catalogue recovery |
| [Recovery review](planning/RECOVERABLE_WORKSPACE_REVIEW.md) | Clean-copy, encryption and local process validation |
| [System](architecture/SYSTEM.md) | Stack, module boundaries, operating modes and alternatives |
| [Folder structure](architecture/FOLDER_STRUCTURE.md) | Exact reserved tree and file ownership |
| [Data flow](architecture/DATA_FLOW.md) | Full scan workflow, origins, transfers and retention |
| [API plan](architecture/API_PLAN.md) | Six current routes, confirmed-input contract, and later analysis proposals |
| [Open Food Facts](architecture/OPEN_FOOD_FACTS.md) | Selected barcode provider, normalization, provenance, caching and fallback |
| [Backend version plan](superpowers/plans/2026-10-05-backend-versions.md) | Reference screens mapped to staged backend releases |
| [Backend v0.2.1 review](planning/BACKEND_V0_2_1_REVIEW.md) | Current source checks, actual export/import metrics and hosted-data gate |
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
| [Deployment plan](architecture/DEPLOYMENT_PLAN.md) | Two Vercel projects, stateless runtime and future evidence bundles |
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
