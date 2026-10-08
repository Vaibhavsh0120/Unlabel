# Controlled Unlabel releases

Verified checkpoint (8 October 2026): backend **v0.9.0** and frontend
**v0.4.0+5** were independently reviewed, documented and pushed on `main`.
Their exact implementation deployments are READY with **26 backend / 49 frontend
hosted checks**, including all 21 OCR asset hashes. The local suites passed
**1058 backend tests (five provider skips) / 181 Flutter tests**; static checks,
release web build and synthetic browser workflows passed. Physical-device gates
and separate GitHub source-release publication are not established by this proof.
[Backend review](BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](FRONTEND_V0_4_0_REVIEW.md).

Updated **8 October 2026**. Work directly on **main only** and preserve historical
source tags. The user has authorized finishing the requested screens, checking
remaining tasks/docs/dead code, then pushing **one frontend version and one backend
version** independently. Do not stage the entire mixed tree as one release.

## Recovery and preserved history

- The original 65 changed files were copied and SHA-256 verified in the local
  Git-directory recovery snapshot `.git/unlabel-recovery/2026-10-07/`. Its
  manifest records original source, file hashes and version assignment; a binary
  patch preserves tracked changes. This snapshot is not published.
- The unused managed worktree was archived after the user's main-only correction.
- Backend v0.7.0 implementation source
  `9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0` remains historical published evidence.
- Later steering brought basic live camera/gallery, live search and reference
  Results/Compare into published frontend v0.2.0. Its implementation source is
  `5f3e92fe58f87aeed6a78f989b3f9289233ca2f2`; its hosted READY deployment is
  `dpl_C67D8NT38YmhRXr2AsRoibKswaZy`. Later docs-only closure commits do not
  replace that implementation identity.
- Preserved capture/OCR modules have now been integrated into v0.3.0. Unfinished
  live-highlighting/automatic-barcode plans remain explicit rather than advertised
  as working code.

## Release ledger

| Release | Goal | Current stage |
| --- | --- | --- |
| Backend v0.7.0 | Private Account Sync | Published: 931 passed / 5 emulator-only skips; 18 synthetic + 13 fresh hosted checks; source tag v0.7.0 |
| Frontend v0.2.0+3 | Welcome/Home, optional account sync, basic capture and sourced report/Compare flows | Published: 135 tests, clean analyzer, hosted READY deployment and source release; native lane separate |
| Frontend v0.3.0+4 | Visual Label Reader: reference Welcome/Profile, app-only startup, local OCR and bounded search behavior | Published: 168 tests, clean analysis/build, light phone/PC captures, READY deployment and 49 hosted checks; all 21 OCR hashes verified |
| Backend v0.8.0 | Sourced Nutrient Comparison | Pushed `1a2fd25`, READY deployment and 25 hosted checks; source publication not established |
| Frontend v0.4.0+5 | Sourced Comparison and Ingredient Detail | Independently pushed/READY, 181 tests and 49 hosted checks; native/device gates remain separate |
| Backend v0.9.0 | Reviewed Ingredient Functions | Six-entry partial glossary and integrity hardening; independently pushed/READY, 1058 tests/five provider skips and 26 hosted checks; no suitability verdict |

Stages: **Planned → Implemented → Tested → Visually verified → Pushed →
Hosted verified → Published**. Backend visual verification is not applicable.
Record source SHA, hosted deployment and production receipt only after each
gate succeeds. Documentation-only closure commits have separate identities.
The frontend release remains compatible with published backend v0.7.0; its
publication does not need to claim or depend on unpublished v0.8.0 functionality.

## Published frontend v0.3.0 acceptance

Implementation source: `3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`.
Hosted READY deployment: `dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`.
[Source release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0) ·
[Production receipt](../research/FRONTEND_V0_3_0_PRODUCTION.json).
Later documentation-only closure commits do not replace the implementation SHA.

Latest user corrections supersede the old screen-order plan and attached navbar
design. Screens come first, then loading/performance improvements.

- [x] Responsive reference-style Welcome for mobile/PC with working guest start
  and optional sign-in; generated artwork/provenance retained.
- [x] Botanical Unlabel startup screen for apps only, during real restoration,
  without an artificial delay. Website has no branded loading screen.
- [x] Profile botanical card and actual identity/history/saved values. No top-right
  gear or bottom Continue as guest action.
- [x] Profile editing/sign-in, library shortcuts, local Preferences/Allergens,
  appearance, privacy/sync/conflict/clear, Help/About and signed-in logout work.
  Notifications are explicitly unavailable; comparison total is unknown.
- [x] Search input is mounted before the tap for immediate keyboard focus; header
  surface no longer blurs/tints near the status bar.
- [x] Preserve **Home / Scan / Compare / Saved** navbar design/order and Profile
  header shortcut. Reduce bottom gap inside the safe area; active icon/indicator
  follows hold/drag, commits on release and cancels on backgrounding.
- [x] Keep Scan Label UI. Retire standalone Find a product route; move manual
  barcode fallback into Scan with validation, retry and safe late-response handling.
- [x] Connect captured/gallery photos to bounded local English/Hindi OCR, editable
  text and conservative suggestions. Require explicit corrected-fact confirmation;
  manually review nutrition. Photos/raw OCR remain private session data.
- [x] Bundle/hash/license same-origin browser runtime/models; Android local OCR
  compiles; iOS Vision source checks supported languages and keeps manual fallback.
- [x] Accessible search skeleton, public-only TTL/LRU caches and request sharing,
  bounded thumbnail queue and reduced image decoding.
- [x] Local analysis/tests, browser OCR bridge/hash checks and synthetic real-browser
  OCR recognition. Native compilation/device evidence stays separate.
- [x] Final release web build and rendered light phone/PC comparison at 390/1440/1728px.
- [x] Markdown/local-link/script/dead-code/private-data review before push.
- [x] Frontend-only source/docs push; exact hosted source/assets verification and 49 checks.
- [x] Hosted browser Welcome enters Home; Search focuses the actual input and returns ten of 57 matches.
- [x] Independent frontend source release without triggering native builds.

See [frontend review](FRONTEND_V0_3_0_REVIEW.md) for exact local/hosted evidence and
remaining native gates. Tests for queue/cache behavior do not establish a device frame-rate or
hosted latency benchmark.

## Backend v0.8.0 acceptance and independent publication

The user authorizes this separate backend release. Its concrete gap is comparison
across exact sourced/confirmed tables; it is not required merely to render the new
screens. Keep the existing report/account/catalogue APIs compatible.

- Implement and validate a bounded, read-only sourced comparison route using exact
  current-confirmed, OFF snapshot or active community revision references.
- Preserve original table basis/preparation, source/date references, unknowns and
  conflicts; allow arithmetic only on compatible measured values. No universal winner.
- Export additive schemas/OpenAPI/examples and test old-client contracts, source
  drift, unsafe/ambiguous inputs, unit arithmetic and actual request-body limits.
- Complete backend tests/static checks/docs/script/private-data review independently.
- Stage/push backend scope separately, verify exact hosted deployment with synthetic
  read-only checks, then publish its source tag. Do not build APK/IPA for backend work.

## Shared evidence rules and future work

- Source tags and manual `mobile-vVERSION+BUILD` artifacts remain separate.
  Mobile artifacts are frontend-only; unsigned IPA does not prove installation.
- Validate narrow/large widths, enlarged text, loading/errors, missing images and
  reduced motion. Report Flutter canvas/DOM measurement limits honestly and retain
  actual rendered phone/PC screenshots.
- Decorative generated artwork never supplies fictional product records, health
  scores or reference identities. Preserve OFF image descriptors and source evidence.
- Guest data stays local. Optional password private sync is separate from public
  structured observations; photos/raw OCR/reminders do not enter that sync.
- Keep ₹0/no card, local OCR first, existing free services and disabled Gemini/training.
- Automatic barcode camera detection, continuous live highlights, comparison totals,
  notifications, personal suitability and broader reviewed ingredient knowledge
  stay explicit future work. Do not enable a control without useful behavior.
- Follow-on source-aware frontend comparison integration is released only after
  additive backend hosted compatibility is established. Native camera/OCR/icon/
  haptic and iOS compilation/installability gates stay separate from web verification.

[Master plan](MASTER_PLAN.md) · [Feature tracker](FEATURE_TRACKER.md) ·
[Account/screen checklist](ACCOUNT_SYNC_SCREEN_PLAN.md) ·
[Next frontend/backend versions](FRONTEND_BACKEND_NEXT_VERSIONS.md) ·
[Historical frontend v0.2.0 review](FRONTEND_V0_2_0_REVIEW.md)
