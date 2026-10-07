# Next accepted account and screen releases

Accepted user steering: **7 October 2026**. Frontend v0.1.0+2 and backend v0.6.0
are independently published. Backend v0.7.0 source is pushed and hosted-verified; publication closure is active;
frontend v0.2.0 is implemented with release validation pending. Continue to review, push and verify
**each version separately**: backend v0.7.0, frontend v0.2.0, then frontend v0.3.0.
Preserve historical source tags; backend/tooling work does not rebuild APK/IPA.

## Backend v0.7.0 — Private Account Sync

Goal: optional scanner accounts can save and restore their own bounded personal
records while guest scanning and automatic public-product facts continue to work.

- [x] Select/document the no-card login method using current Firebase docs. Keep
  one scanner role; no admin/reviewer app accounts, claims or dashboards.
- [x] Verify non-anonymous account identity for personal endpoints; derive ownership
  from the token, never a caller-supplied UID.
- [x] Keep guest history/bookmarks/preferences local. Signed-in profile, saved
  reports and history use private per-user storage separate from public facts.
- [x] Bound counts/sizes, reads/writes and sync frequency within the existing free
  database. No Storage, Functions, billing, TTL, backups or PITR.
- [x] Define initial merge, edits/deletions, stale revisions, logout/account switching
  and offline/failed sync. Preserve local results and isolate different accounts.
- [x] Export additive contracts and test old clients, authentication, ownership,
  quotas, deletion/conflicts, scripts, environment and Markdown.
- [x] Push and hosted verification: source 9d9a9b6 and 18 hosted synthetic checks; test identities deleted and private snapshots cleared.
- [ ] Complete independent GitHub publication after refreshed validation/documentation.

## Frontend v0.2.0 — Welcome, Home and Optional Login

Goal: match the supplied light/dark Home direction, add optional private sync and
make navigation useful. Implement/review one screen at a time.

- [x] Cute first-launch Welcome with Continue, without forced login; persist its
  completion locally and send returning users straight to Home.
- [x] Reference-style Home: forest/mint light, near-black/charcoal dark, rounded
  cards, warm decorative art and actual recent records or useful empty states.
- [x] Four bottom destinations: **Home, Scan, Compare, Saved**; Profile at the top right of main screens. Every visible
  action opens a working flow. Until the v0.3.0 redesign, Scan uses existing manual
  lookup/corrected entry and Compare must use a useful implemented selection/facts
  flow; never leave a stale/disabled comparison button or fabricated result.
- [x] Optional scanner sign-in/create account/profile, sync state, sign out and
  deletion controls. Guest workflows stay usable with personal records local.
- [x] Keep public corrected-package intake separate from personal account sync.
- [x] Light stays the first-use default; preserve explicit appearance locally.
  Reuse authored light/dark iOS/Android/web icons with separate native/device gates.
- [x] Generate cute decorative images where useful; never impersonate actual
  scanned product photos or package facts.
- [ ] Complete full release verification of every visible action, guest/account isolation, sync failure/logout,
  first/return launch, small/large widths, large text and both appearances.
- [ ] Review Markdown/scripts/dead code, build, push, hosted-verify and publish
  separately after backend v0.7.0 compatibility is established.

## Frontend v0.3.0 — Complete Scan and Food Screens

Goal: complete remaining reference-styled journeys, one screen at a time, with
working destinations for every visible control. Keep existing useful flows while
replacing their presentation.

| Screen / destination | Working actions and honest states |
| --- | --- |
| Scan/correct label | Front/back/barcode modes, camera/gallery/manual route, permission/error/retry, pairing and correction before analysis |
| Analysis results | Current/historical evidence, facts, claims, approximate sugar, save and source/ingredient details; unknowns visible |
| Compare products | Add/change two actual products, compatible basis, measured rows and source dates; handle missing/incompatible inputs |
| Ingredient insights | Real identified claims, scoped results and reviewed functions; expandable sources and allergen uncertainty |
| Libraries, insights, settings and source details | Saved/history read/remove/clear, reviewed educational details, appearance and build/source information; no stale action |

- [ ] Add only reviewed educational content with explicit source/applicability.
- [ ] Compare compatible measured values with origins/dates; no universal health
  score, inferred safe product or unsupported healthier winner.
- [ ] Keep local OCR/correction first; camera/OCR accuracy and geometry require
  measured browser/native gates. No custom training/Gemini dependency is selected.
- [ ] Use Better Design guidance/review and measured spacing where DOM permits;
  document Flutter canvas limits and perform rendered flow checks.
- [ ] Review tests/contracts/docs/scripts/dead code, then push, verify hosted flows
  and publish separately. Any needed backend extension gets its own accepted version.

The references' 85/100 scores, sample product facts and claim verdicts are not
approved fixtures. Native builds, launcher icon switching and physical-device
camera behavior cannot be inferred from a web build.

[Controlled release order](CONTROLLED_RELEASES.md) · [Current release plan](CONNECTED_RELEASE_PLAN.md) · [Tracker](FEATURE_TRACKER.md)
· [Interface contract](../../DESIGN.md) · [Safety/privacy](../SAFETY_PRIVACY.md).
