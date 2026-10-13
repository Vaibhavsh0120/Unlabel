# Unlabel documentation

Current component versions come from [frontend pubspec](../frontend/pubspec.yaml)
and [backend pyproject](../backend/pyproject.toml). The latest auth/profile and UI
work is reviewed in [frontend evidence](planning/FRONTEND_V0_8_0_REVIEW.md), with
[backend Google compatibility](planning/BACKEND_V0_12_1_REVIEW.md) separate.
This pass also fixes setup/release metadata and stale documentation. Source, native artifacts, hosted deployment
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
| [System](architecture/SYSTEM.md) · [Folders](architecture/FOLDER_STRUCTURE.md) | Actual stack and source map |
| [API](architecture/API_PLAN.md) · [Shared schemas](../contracts/README.md) | Runtime routes and preserved historical exports |
| [Data flow](architecture/DATA_FLOW.md) · [Privacy](SAFETY_PRIVACY.md) | Sources, consent, retention and uncertainty |
| [Catalogue](architecture/CATALOGUE.md) · [Discovery](architecture/PRODUCT_DISCOVERY.md) | Immutable packaged catalogue, indexed search and dated sources |
| [Reports](architecture/LABEL_REPORT.md) · [Comparison](architecture/SOURCED_COMPARISON.md) | Sourced facts, compatible tables and unknowns |
| [Community](architecture/COMMUNITY_CATALOGUE.md) · [Private sync](architecture/PRIVATE_ACCOUNT_SYNC.md) | Separate public observations and optional account libraries |
| [Account and profile](architecture/ACCOUNT_PROFILE.md) | Linked sign-in, password reset, private avatars and optional gender |
| [AI routing](architecture/AI_ROUTING.md) | Bounded optional photo extraction and private proposals |
| [Insights](architecture/INSIGHTS.md) · [UI contract](../DESIGN.md) | Sourced educational articles and reference visual direction |
| [Master plan](planning/MASTER_PLAN.md) · [Remaining work](planning/FRONTEND_BACKEND_NEXT_VERSIONS.md) | Product intent and pending acceptance |

The current reviews separate [frontend auth/profile](planning/FRONTEND_V0_8_0_REVIEW.md)
from [backend provider compatibility](planning/BACKEND_V0_12_1_REVIEW.md). Final hosted/native
acceptance remains pending until its exact-source receipt is recorded. Older versioned reviews,
production JSON receipts, research notes, accepted specs and plans remain dated
historical evidence. Their versions and test totals describe their own source
revisions; they are not instructions to revert current code or repeat old work.
