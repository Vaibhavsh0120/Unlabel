# Documentation map

Scanner/backend documents describe planned behavior. The Flutter starter and manual release workflow are implemented. Research was checked on 5 October 2026; provider/source eligibility must be reviewed before use.

| Document | Read it for |
| --- | --- |
| [System](architecture/SYSTEM.md) | Stack, module boundaries, operating modes and alternatives |
| [Folder structure](architecture/FOLDER_STRUCTURE.md) | Exact reserved tree and file ownership |
| [Data flow](architecture/DATA_FLOW.md) | Full scan workflow, origins, transfers and retention |
| [API plan](architecture/API_PLAN.md) | Proposed frontend/backend contracts and errors |
| [Open Food Facts](architecture/OPEN_FOOD_FACTS.md) | Selected barcode provider, normalization, provenance, caching and fallback |
| [Deployment plan](architecture/DEPLOYMENT_PLAN.md) | Two future Vercel projects and stateless bundles |
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
