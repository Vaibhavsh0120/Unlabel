# Unlabel workspace instructions

## Active checkpoint and maintenance

- Work directly on main only; do not create a branch or worktree. Preserve teammate
  edits, licensed sources, historical tags and published assets. Update docs before push.
- The maintenance/UI repairs ship as a frontend patch after the user's later
  release instruction; backend runtime stays unchanged. Canonical versions are
  frontend/pubspec.yaml and backend/pyproject.toml; scripts/workspace.json pins
  Flutter. Do not reintroduce repeated Dart/runtime/workflow version literals.
- Current UI/release proof belongs to docs/planning/FRONTEND_V0_7_1_REVIEW.md.
  Keep the desktop shell stationary for History/Sources; readers have no whole-shell
  desktop transition. New illustrations stay exclusive to their section.
- Source identities are in docs/planning/CONTROLLED_RELEASES.md and
  contracts/versioning/releases.json. Frontend feature implementation 8b5f9064 and
  backend implementation 39e600e remain distinct from later maintenance/docs commits.
  Local tests, pushed source, hosted proof, publication, native build and device
  acceptance remain separate. Historical versioned reviews/receipts are dated evidence.
- Follow docs/planning/MASTER_PLAN.md, FEATURE_TRACKER.md and the architecture
  contracts. Maintenance findings/gates: docs/planning/MAINTENANCE_2026_10_12.md.
- Preserve Home/Scan/Compare/Saved navbar order and Profile header shortcut.
  Insights has twenty sourced articles, four unique stable daily picks shared with
  Home, full reader/topic/all browsing and protected device-local bookmarks.
  Swipe/dots/keyboard remain manual. Preference/allergen symbols remain distinct.
- Retain 24,641 bulk records, 243 immutable research observations, search v3 and
  120 separate sourced image descriptors. No source/SQLite migration or deletion.
- Native frontend tags include build number; historical mobile/backend tags stay
  intact. Only the dedicated ios-source/apps.json feed is mutable after verified
  publication. Feed delivery does not establish physical LiveContainer execution.
  scripts/validate_workspace.py is tracked. Source checks run in maintenance-ci;
  manual-release builds native artifacts. Backend work does not rebuild APK/IPA.

## Product, setup and evidence boundaries

- Inspect current source/contracts and preserve teammate edits. Update docs before every push. Keep the project free with no billing/card requirement.
- Restore with `python scripts/setup.py`; run with `python scripts/run_local.py`. `--scope backend` selects backend-only work. See docs/planning/LOCAL_DEVELOPMENT.md.
- Never commit plaintext `.env`, private identities, real scans or credentials. Track authenticated `backend/.env.age` and its public recipient; refresh ciphertext with `python scripts/env.py encrypt` after changing local settings. Private key paste belongs in the hidden local terminal prompt.
- Track reusable acquired source bundles, provenance, licenses and hashes. SQLite, SDKs, environments and builds are generated. Rich OFF facts accept direct packaging/manufacturer nutrition only; legacy aggregates stay unavailable. Images are validated official URL descriptors, never bundled bytes. Coverage is unverified. Replace snapshots manually every nine calendar months after validation. Vercel builds the tracked source into a verified read-only bundle; see docs/planning/BACKEND_V0_6_0_REVIEW.md for current discovery/release gates and BACKEND_V0_5_0_REVIEW.md for unchanged report proof and BACKEND_V0_4_0_REVIEW.md for unchanged cloud/storage proof, BACKEND_V0_3_0_REVIEW.md for unchanged claim-source proof and BACKEND_V0_2_3_REVIEW.md for the unchanged measured catalogue source. Earlier reviews remain historical evidence.
- Preserve original OFF/community/current-package observations and reviewed FSSAI evidence. A derived resolved view may complement compatible known product fields with per-field source/date references; retain disagreements and never average incompatible tables. Missing is unknown, not zero or an allergy-safe/compliance verdict; generic-food composition never fills branded-packet gaps.
- Firebase Unlabel (`unlabel-india-catalogue`) has its first Standard database `unlabel` in Mumbai, free tier enabled and no linked billing. Anonymous and email/password Auth, deny-all client rules and least-privilege backend credentials are configured; live synthetic checks are separate from hosted API proof. Keep Spark/no card; prohibit paid Storage/Functions, TTL, backups and PITR. v0.4.0 saves/deduplicates structured public observations automatically without a Share flag; provisional observations remain private staging. Exact confirmed compatible candidates are public with qualified unreviewed evidence. Photos/raw OCR stay private. Guests keep history/saved data locally. v0.2.0 optional password sign-in selects a separate verified-UID local namespace and private profile/saved/history sync; cloud/device differences need an explicit choice. Appearance and Welcome completion stay device-local; photos/raw OCR/dietary health preferences are outside private sync. See docs/planning/BACKEND_V0_4_0_REVIEW.md and docs/architecture/COMMUNITY_CATALOGUE.md.


- There is one app identity role: the scanner/client user. Guests use automatic anonymous Firebase authentication for public facts; signed-in password scanners retain their SDK session. Implemented v0.7.0/v0.2.0 adds optional scanner login/profile/private sync; guests retain useful local workflows and never upload personal records before login. Keep private signed-in data separate from public package observations. Do not add reviewer/admin app accounts, role claims or dashboards. The existing service account is a backend machine credential, not a user login; exact-hash CLI conflict maintenance stays manual tooling. Compatible safe facts qualify automatically and conflicts remain unresolved.
- Use local barcode lookup and conservative OCR first for known products. User authorized optional backend Gemini/OpenAI photo extraction on 8 October 2026, with explicit transfer consent, bounded unverified output, one global credential and sticky failure replacement. No custom model/training or Firebase billing is selected. Gemini synthetic evidence is separate from hosted/native accuracy. OpenAI uses the supplied operator account; no billing is enabled by our tools.
- Exact-identity-compatible confirmed gap fills may appear as qualified submitter-confirmed/unreviewed facts after strict validation; identical rescans do not require repeated operator review. Conflicts/identity mismatches await review. Moderator review is an additional state, never safety/current-package proof. Preserve semantic deduplication, immutable receipts, provider-reference checks and transactional admission.


- Historical v0.5.0 ingredient scope has three reviewed Codex technological-function entries; current v0.9.0 expands to six reviewed English/Hindi entries in `glossary-v2.json`, preserving v1. F08 stays partial. No health/allergy/Indian-permission verdict, universal score or Gemini/training dependency. Current reports and historical barcode reports retain distinct evidence. Sugar cubes use the explicit approximate 4 g/cube version and original table basis, never inferred serving size.
- Run backend tests with backend `.venv` Python and Flutter checks from frontend. Validate meaningful importer/secret/process boundaries, all Markdown/scripts, affected tests, docs links and current contracts before pushing. Remove demonstrably dead code. Hosted claim knowledge requires a verified two-file receipt; unknown/conflicting evidence remains insufficient.

## Current documentation

Use Context7 MCP for library/framework/SDK/API/CLI/cloud-service docs, even familiar tools. Start with resolve-library-id unless an exact /org/project ID is supplied. Select the relevant official/high-reputation match; query-docs for one concept per call. Use fetched docs for API/configuration decisions.

## UI work

Use Better Design MCP for frontend/UI/UX/interaction work. Start UI builds with find-design-system. Load get-ui-principle and get-ux-principle; review with get-review-rules and check-comprehension. With a rendered DOM, run inspect-spacing. React Native/Expo, Three.js and Shopify use their respective guides. A custom brand uses create-design-system and its status/kit workflow. The supplied white/forest/mint references now set the visual direction; their scores and health claims remain illustrative. DESIGN.md records the Flutter adaptation.
