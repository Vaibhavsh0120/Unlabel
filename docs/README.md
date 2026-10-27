# Unlabel documentation

Current update: **frontend 0.11.0+15 / backend 0.15.0**, covering the free native/WASM
scanner, compact reference product page, Safari camera cleanup, guest toast and
independently optional sources. Local, hosted, native and device evidence remain
separate. [Frontend review](planning/FRONTEND_V0_11_0_REVIEW.md) ·
[Backend review](planning/BACKEND_V0_15_0_REVIEW.md) ·
[Optional sources](architecture/OPTIONAL_SOURCES.md).


Current component versions come from [frontend pubspec](../frontend/pubspec.yaml)
and [backend pyproject](../backend/pyproject.toml). The preceding auth/profile and UI
work is recorded in the [frontend update](planning/FRONTEND_V0_9_0_REVIEW.md) and
[backend deletion release](planning/BACKEND_V0_13_0_REVIEW.md), with
the [preceding frontend source scope](planning/FRONTEND_V0_8_0_REVIEW.md) and
[backend Google compatibility](planning/BACKEND_V0_12_1_REVIEW.md) separate.
Source, native artifacts, hosted deployment
and physical-device checks have separate receipts.

| Start here | Purpose |
| --- | --- |
| [Clone, restore, run](planning/LOCAL_DEVELOPMENT.md) | Reproducible component setup and owned-process cleanup |
| [Release/versioning](planning/RELEASE_VERSIONING.md) | Canonical versions, native builds and LiveContainer source |
| [Release ledger](planning/CONTROLLED_RELEASES.md) | Independent component tags and immutable source identities |
| [Maintenance audit](planning/MAINTENANCE_2026_10_12.md) | Findings, scope and validation gates |
| [Feature tracker](planning/FEATURE_TRACKER.md) | Implemented functionality and remaining device/product gates |
| [Team handoff](planning/TEAM_HANDOFF.md) | Working commands and module ownership |
| [Deployment settings](planning/VERCEL_SETUP.md) | Independent Git-connected web/API projects |

| Architecture | Contract |
| --- | --- |
| [System](architecture/SYSTEM.md) Â· [Folders](architecture/FOLDER_STRUCTURE.md) | Actual stack and source map |
| [API](architecture/API_PLAN.md) Â· [Shared schemas](../contracts/README.md) | Runtime routes and preserved historical exports |
| [Data flow](architecture/DATA_FLOW.md) Â· [Privacy](SAFETY_PRIVACY.md) | Sources, consent, retention and uncertainty |
| [Catalogue](architecture/CATALOGUE.md) Â· [Discovery](architecture/PRODUCT_DISCOVERY.md) | Immutable packaged catalogue, indexed search and dated sources |
| [Product Info](architecture/PRODUCT_INFO.md) Â· [Reports](architecture/LABEL_REPORT.md) Â· [Comparison](architecture/SOURCED_COMPARISON.md) | Sourced facts, compatible tables and unknowns |
| [Community](architecture/COMMUNITY_CATALOGUE.md) Â· [Private sync](architecture/PRIVATE_ACCOUNT_SYNC.md) | Separate public observations and optional account libraries |
| [Account and profile](architecture/ACCOUNT_PROFILE.md) | Linked sign-in, password reset, private avatars and optional gender |
| [AI routing](architecture/AI_ROUTING.md) | Bounded photo extraction, private proposals and automatic unverified observations |
| [Insights](architecture/INSIGHTS.md) Â· [UI contract](../DESIGN.md) | Sourced educational articles and reference visual direction |
| [Master plan](planning/MASTER_PLAN.md) Â· [Remaining work](planning/FRONTEND_BACKEND_NEXT_VERSIONS.md) | Product intent and pending acceptance |

The user authorized completion and push from main on 13 October. Current source,
Git-triggered deployment and native publication remain separate evidence. The
[preceding backend provider review](planning/BACKEND_V0_12_1_REVIEW.md) and earlier source
reviews retain their own hosted/native evidence. Older versioned reviews,
production JSON receipts, research notes, accepted specs and plans remain dated
historical evidence. Their versions and test totals describe their own source
revisions; they are not instructions to revert current code or repeat old work.
