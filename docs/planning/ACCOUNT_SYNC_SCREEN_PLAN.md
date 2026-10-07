# Accepted account and screen releases

Updated **8 October 2026** from the user's latest screen, behavior and release
instructions. Backend v0.7.0 and frontend v0.2.0+3 are independently published and
hosted-verified. Current work is frontend **v0.3.0+4 Visual Label Reader**, followed
by an independent backend **v0.8.0 Sourced Nutrient Comparison** publication.
Work directly on main, update docs before each push, and preserve historical tags.
Backend work does not rebuild APK/IPA.

## Published backend v0.7.0 — Private Account Sync

Optional scanner accounts retain bounded private display name, saved reports and
history while guest workflows and automatic public package facts remain separate.

- [x] One scanner role, verified non-anonymous ownership, no admin/reviewer app roles.
- [x] Guest records stay local; authenticated private sync derives UID from the token.
- [x] Bounded requests/storage, explicit cloud/device choices, account isolation,
  logout, offline/failed sync and pending deletion behavior.
- [x] No paid Storage/Functions, billing, card, TTL, backups or PITR.
- [x] Additive contracts, old-client/auth/ownership/quota/conflict tests and docs checks.
- [x] Independent source push, hosted synthetic checks and GitHub v0.7.0 publication.
  [Historical review](BACKEND_V0_7_0_REVIEW.md).

## Published frontend v0.2.0+3 — Welcome, Home and Optional Account

Implementation source:
`5f3e92fe58f87aeed6a78f989b3f9289233ca2f2`.
[Production receipt](../research/FRONTEND_V0_2_0_PRODUCTION.json).

- [x] Persist first-use Welcome completion; useful guest flow with optional password login.
- [x] Reference-style Home, light default/dark support and manually swiped tips.
- [x] Four bottom destinations **Home / Scan / Compare / Saved**; Profile at the top right.
- [x] Account private sync with UID-specific local namespaces and explicit conflict choices.
- [x] Basic live camera/gallery/manual review, live header search and sourced Results/Compare.
- [x] Artwork provenance, reduced motion, interaction feedback and meaningful empty states.
- [x] 135 Flutter tests, clean analysis, release web build and browser checks.
- [x] Independent push, READY hosted source verification and frontend source publication.
  [Historical review](FRONTEND_V0_2_0_REVIEW.md).

## Frontend v0.3.0+4 — Visual Label Reader

This is the active frontend release. Latest corrections keep the existing navbar
design/order and Scan Label UI. The attached reference navbar, top-right Profile
gear, sample identity/counts and illustrative health scores are not approved behavior.

| Requested area | Implemented behavior / honest boundary |
| --- | --- |
| Welcome mobile and PC | Botanical pouch/leaves composition, responsive layout, working Get started and optional sign-in |
| Startup | Botanical Unlabel screen during app state restoration only; website excluded; no artificial delay |
| Home Search | Input mounted before tap, immediate focus/keyboard request, real candidate selection and report opening |
| Header/status bar | Opaque surface, no blur or scrolled-under elevation tint |
| Scan Label | Existing screen layout retained; camera/gallery/manual controls and front/back/barcode modes |
| Find a product removal | Standalone route deleted; numeric barcode fallback is an autofocus sheet inside Scan Label |
| Post-capture text | Bounded local English/Hindi OCR, editable extraction, conservative suggestions and explicit confirmation; nutrition manually reviewed |
| Navbar behavior | Existing four-tab design/order; reduced bottom gap within safe area; active icon/indicator follows hold/drag and commits on release |
| Profile | Botanical card, actual identity/history/saved counts, local reminders and working settings; no top-right gear or bottom guest action |
| Loading/performance | Accessible search skeleton, public-only bounded read caches, shared identical requests, limited thumbnail queue and bounded image decoding |

- [x] Source implementation and targeted regression tests.
- [x] Clean Flutter analysis; 168 tests passed at the recorded full-suite checkpoint.
- [x] Four browser OCR bridge tests, 21 vendored runtime/model hashes and 42 icon checks.
- [x] Real compiled local browser reads a synthetic label using same-origin local OCR.
- [x] Android OCR bridge Kotlin compilation.
- [ ] Final release web build and light-mode rendered phone/PC reference checks.
- [ ] Confirm every visible action, errors, enlarged text, reduced motion and responsive overflow.
- [ ] Check all Markdown/local links/scripts, remove confirmed dead code and review private data.
- [ ] Independently push, verify exact hosted source/assets/flows and publish frontend source.

The [v0.3.0 review](FRONTEND_V0_3_0_REVIEW.md) records source behavior and limits.
The final render targets are 390px phone and 1440/1728px PC. Native device accuracy,
camera/picker interruption/haptics and iOS compilation remain separate gates.

## Profile controls and next-version commitments

| Control | Current behavior | Remaining work |
| --- | --- | --- |
| Identity / Edit profile | Guest sign-in or signed-in display-name update | No account roles or fabricated reference identity |
| Scans / Saved | Active local-namespace library sizes and working library shortcuts | Counts are current retained records, not lifetime totals |
| Comparisons | Opens working Compare; total shows unknown | Explicit comparison-history storage/migration design before enabling a total |
| Preferences / Allergens | Bounded device-local reminders with edit/save/error behavior | Any product-matching/suitability behavior needs separate evidence and acceptance |
| Notifications | Disabled switch; row explains this version has no notification delivery | Select/design useful reminder behavior and free provider/platform support before enabling |
| Dark mode | Persisted appearance toggle | System appearance remains supported by the existing device setting |
| Privacy | Sync status, explicit cloud/device conflict choices, guest-copy and confirmed account-data clearing | Preserve device/account/public separation |
| Help | Working explanation and About destination | Expand only with useful supported guidance |
| Log out | Signed-in users only; confirmation returns to separate guest library | Native session/device checks remain separate |

Photos, raw OCR and dietary/allergen reminders remain outside private account
sync. Reminders do not filter products or establish allergy safety. There is no
decorative working-looking notification toggle or invented comparison count.

## Independent backend v0.8.0 and following versions

Backend v0.8.0 locally implements sourced nutrient comparison, preserving exact
current-confirmed or historical references, original table basis/preparation,
unknown/conflict states and bounded arithmetic. Frontend v0.3.0 remains compatible
with published v0.7.0 and does not depend on this new route. Push/review/publish
backend separately after the frontend release boundary.

Following frontend v0.4.0 work includes integration of source-aware comparison,
remaining reference-screen refinement and device/browser acceptance, with barcode
camera detection and live highlights kept explicit until implemented. Notification
delivery and comparison-history totals need actual persistence/behavior decisions;
they are not silently enabled in v0.3.0. Backend v0.9.0 focuses on reviewed bilingual
ingredient knowledge and measured coverage. No custom model/training, Gemini,
paid service or card requirement is selected.

The reference scores, food facts and claim verdicts are illustrative, not approved
fixtures. Missing is unknown. Neither concept art nor a web build establishes
food suitability, barcode/OCR accuracy or installable iOS distribution.

[Controlled release order](CONTROLLED_RELEASES.md) ·
[Next versions](FRONTEND_BACKEND_NEXT_VERSIONS.md) ·
[Tracker](FEATURE_TRACKER.md) · [Design contract](../../DESIGN.md) ·
[Safety/privacy](../SAFETY_PRIVACY.md)