# Unlabel workspace instructions

## Active checkpoint and maintenance

- Work directly on main. Preserve teammate edits, historical tags, published
  assets, public source evidence and device-local guest data. Update relevant
  documentation and run affected checks before pushing.
- Start with [docs/README.md](docs/README.md), the [roadmap](docs/roadmap.md),
  and the [verification guide](docs/verification.md). Historical evidence is
  linked from the [release ledger](contracts/versioning/releases.json).
- The existing Vercel/Firebase release stays live until the replacement completes
  acceptance. Oracle/Coolify hosts the next-major API, background work, identity
  and data services. Keep Vercel for the frontend. Existing Firebase data may be
  discarded only after replacement verification and client cutover. See the
  [self-hosted platform architecture](docs/architecture/SELF_HOSTED_PLATFORM.md).
- Canonical versions live in `frontend/pubspec.yaml` and `backend/pyproject.toml`.
  The Flutter version is pinned in `scripts/config/workspace.json`. Derive build
  and runtime metadata from these sources. Native publication requires an
  increased frontend version/build or explicit dispatch. Preserve historical
  mobile/backend tags. Only the dedicated `ios-source/apps.json` feed is mutable
  after verified publication. Hosted source, publication, hosted runtime and
  physical-device execution are separate evidence.
- Preserve the Home/Scan/Compare/Saved navbar order and Profile header shortcut.
  Keep the desktop shell stationary for History/Sources. Readers have no whole-shell
  desktop transition. Section artwork stays local to its section. Insights has
  twenty sourced articles, four unique stable daily picks shared with Home, and
  device-local bookmarks. Home tips rotate every three seconds with pause, swipe,
  dots and keyboard control. Interaction, background and accessibility settings
  pause rotation. Preference and allergen symbols stay distinct.
- Follow [the interface contract](frontend/DESIGN.md) for auth and layout. Auth uses
  live wordmark/forms, fixed desktop page and equal-width centered cards. Desktop
  login/signup cards are 15% narrower than the preceding pass and do not scroll.
  Mobile and portrait iPad keep a single edge-to-edge card over fixed art with
  keyboard lift and restoration. Avoid nested scrolling. Wrap large text without
  overlapping art. Validate both iPad
  orientations and actual renders. Keep sign-in, signup, forgot password and
  neutral link-sent states. Legacy Firebase `/__/auth/action` owns reset completion
  and returns to `#/account-signin` with `handleCodeInApp:false`. Profile-origin
  login/signup shows a back arrow. Welcome-origin login/signup has no arrow.
- Scanner defaults to Barcode, preserves camera aspect ratio and crops to the
  visible preview. Native zoom/focus and compatible browser zoom require device
  acceptance. Keep local `mobile_scanner` and the self-hosted ZXing-C++ WASM,
  package-aware confirmation and the single ProductInfoPage destination.
- Retain 24,641 bulk catalogue records, 243 immutable research observations,
  search v3 and 120 separate sourced image descriptors. Build legacy SQLite from
  the tracked inputs. Keep public files, licenses and hashes intact. New runtime
  database use follows the self-hosted architecture.
- Keep keyed sources optional and honor explicit disable flags. NutriGraph is
  backend-only and session-only, with at most 24-hour retention. Its live US UPC
  lookup is distinct from regional India/Europe vendor staging. It never enriches
  the permanent catalogue.

## Product, setup and evidence boundaries

- Inspect current source/contracts and preserve teammate edits. Update docs before every push. Keep the project free with no billing/card requirement.
- Restore with `python scripts/setup.py`; run with `python scripts/run_local.py`. `--scope backend` selects backend-only work. See [local development](docs/development.md).
- Never commit plaintext `.env`, private identities, real scans or credentials. Use `secrets/secrets.ps1 encrypt` to refresh the authenticated full-project bundle and legacy `backend/.env.age`; `decrypt` restores original paths and `verify` compares local bytes. Track ciphertext, public recipient and secret-path manifest/index only. Private key paste belongs in the hidden local terminal prompt. See secrets/README.md.
- Track reusable acquired source bundles, provenance, licenses and hashes. SQLite, SDKs, environments and builds are generated. Rich OFF facts accept direct packaging/manufacturer nutrition only; legacy aggregates stay unavailable. Images are validated official URL descriptors, never bundled bytes. Coverage is unverified. Replace snapshots manually every nine calendar months after validation. Vercel builds the tracked source into a verified read-only legacy bundle. Preserve dated evidence in the release ledger.
- Preserve original OFF/community/current-package observations and reviewed FSSAI evidence. A derived resolved view may complement compatible known product fields with per-field source/date references; retain disagreements and never average incompatible tables. Missing is unknown, not zero or an allergy-safe/compliance verdict; generic-food composition never fills branded-packet gaps.
- Firebase Unlabel (`unlabel-india-catalogue`) uses the existing Standard `unlabel` database in Mumbai, free tier with no linked billing. Anonymous, email/password and Google Auth are configured. Public observations, private libraries and machine collections stay backend-only. The sole direct-client exception is owner-only `profile_media/{uid}` for a strict private profile/gender document and a 192×192 PNG thumbnail of at most 96 KiB; anonymous users and collection listing are denied. Keep Spark/no card; prohibit paid Storage/Functions, TTL, backups and PITR. Public confirmed observations retain qualified unreviewed evidence; provisional observations remain private. Label photos/raw OCR/dietary reminders stay outside library sync. Guests retain local libraries. Signed-in libraries use a verified-UID namespace and explicit cloud/device conflict choices. See docs/architecture/ACCOUNT_PROFILE.md and docs/architecture/COMMUNITY_CATALOGUE.md.


- There is one app identity role: the scanner/client user. Guests use automatic anonymous Firebase authentication for public facts. Password/Google scanners retain their SDK session; linking providers must retain the same UID/library and never merge a credential collision. Guests retain useful local workflows and never upload personal records before login. Optional gender is user-chosen: unset/male uses the approved male default, female uses its distinct new default, and Google gender is never inferred or requested. Private profile data never enters public observations. Do not add reviewer/admin app accounts, role claims or dashboards. The service account is a backend machine credential; exact-hash conflict maintenance stays manual. Compatible facts qualify automatically and conflicts remain unresolved.
- Use local barcode lookup and conservative OCR first for known products. User authorized optional backend Gemini/OpenAI photo extraction on 8 October 2026, with explicit transfer consent, bounded unverified output, one global credential and sticky failure replacement. No custom model/training or Firebase billing is selected. Gemini synthetic evidence is separate from hosted/native accuracy. OpenAI uses the supplied operator account; no billing is enabled by our tools.
- Exact-identity-compatible confirmed gap fills may appear as qualified submitter-confirmed/unreviewed facts after strict validation; identical rescans do not require repeated operator review. Conflicts/identity mismatches await review. Moderator review is an additional state, never safety/current-package proof. Preserve semantic deduplication, immutable receipts, provider-reference checks and transactional admission.


- Historical v0.5.0 ingredient scope has three reviewed Codex technological-function entries; current v0.9.0 expands to six reviewed English/Hindi entries in `glossary-v2.json`, preserving v1. F08 stays partial. No health/allergy/Indian-permission verdict, universal score or Gemini/training dependency. Current reports and historical barcode reports retain distinct evidence. Sugar cubes use the explicit approximate 4 g/cube version and original table basis, never inferred serving size.
- Run backend tests with backend `.venv` Python and Flutter checks from frontend. Follow [verification](docs/verification.md) for checks of importer, secret and process boundaries, source files, documentation and current contracts. Remove demonstrably dead code. Hosted claim knowledge requires a verified two-file receipt; unknown/conflicting evidence remains insufficient.

## Current documentation

Use Context7 MCP for library/framework/SDK/API/CLI/cloud-service docs, even familiar tools. Start with resolve-library-id unless an exact /org/project ID is supplied. Select the relevant official/high-reputation match; query-docs for one concept per call. Use fetched docs for API/configuration decisions.

## UI work

Use Better Design MCP for frontend/UI/UX/interaction work. Start UI builds with find-design-system. Load get-ui-principle and get-ux-principle; review with get-review-rules and check-comprehension. With a rendered DOM, run inspect-spacing. React Native/Expo, Three.js and Shopify use their respective guides. A custom brand uses create-design-system and its status/kit workflow. The supplied white/forest/mint references now set the visual direction; their scores and health claims remain illustrative. `frontend/DESIGN.md` records the Flutter adaptation.
