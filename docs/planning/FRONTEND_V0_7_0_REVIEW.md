# Frontend v0.7.0+11: daily insights collection

Implementation on main, 9 October 2026; final checks completed during the
9–10 October session. Implementation 8b5f9064d61c4003a2fd0ae180d0ece933070cfa
is pushed on main; later docs-only closure preserves that source identity.
Hosted verification and Android/iOS publication remain separate. Backend
v0.12.0 runtime and catalogue observations are unchanged.

The supplied desktop and mobile references replace the previous short tips
screen with a featured article, illustrated cards, topic browsing and saved
insights. Desktop preserves the real navigation shell and the saved/quick-topic
rail. Phone saved articles appear below the feed. Exactly four daily articles
are shown, rather than the larger example list in the references. Empty saved
collections show guidance instead of fabricated sample saves.

Twenty reviewed articles each have three sections, a practical takeaway,
primary-source references, review date and a separately generated transparent
illustration. The date-seeded selection draws four unique topics and articles,
remains stable all day and refreshes at midnight or on app resume. Home consumes
the same selection. Both phone and PC support manual swipe, selectable dots,
keyboard and screen-reader adjustment; the user explicitly selected no autoplay.
The dot strip is reduced from 56 px to 32 px: a 4 px gap and 28 px high controls
that retain 48 px width. Its semantic tap action is exposed and tested.

Editorial bookmarks stay device-local, independent of account/product sync.
Failed writes preserve state, malformed storage is protected from overwrite,
retries coalesce and recovery requires an explicit confirmed clear action.
Source links open in the browser and remain selectable/copyable when opening
fails. All twenty articles are bundled and readable without a network request.

The preference editor and saved summaries use distinct corresponding symbols
for all eight food preferences and twelve allergen reminders. Existing selection
counts, separate editors, saved choices and local-only boundaries are retained.

## Verification

- Full Flutter suite: **267 tests passed**. Analysis: **no issues found**.
- Production release web build: passed from lib/main.dart. The separate
  integrated review entry point also builds in release mode.
- Controller checks cover same-day stability, four unique articles/topics,
  full-year catalogue coverage, saved restart/merge, failed writes, corrupt and
  oversized storage, coalesced/reentrant reads, actual midnight timer execution,
  exactly one date refresh, preserved saves and timer cancellation on disposal.
- Dart VM and optimized JavaScript select identical IDs/order across **3,653
  dates**, including leap days (2020–2029). Output SHA-256:
  5055dd356899940718cd7ec43e884bb1132e31474829450568a54a01c7934cd1.
- UI checks cover topic/all browsing, reader/back navigation, save/remove/empty
  collection, failure messages, exact source URL launch arguments, false/throw
  launch recovery and clipboard arguments. Home has explicit touch, desktop
  mouse, RTL, keyboard, screen-reader adjustment and per-dot tap regressions.
- Feed layout checks cover 320/390/768/1024/1440/1728 px, 1x/2x text and both
  themes: **24 configurations**, without layout exceptions. Existing scanner,
  account, search, storage and OCR tests remain in the full suite.
- All twenty delivered images have distinct SHA-256s, match the generation
  manifest and are 512×512 RGBA with complete padded silhouettes and genuine
  alpha (0–255). Total: **3,174,817 bytes**. All nineteen new SVGs XML-parse,
  have unique hashes and map with the existing protein symbol to twenty meanings.
- Pubspec, About fallback and manual release defaults match **0.7.0+11**. Workflow
  YAML and all six embedded Python blocks parse. Backend tracked source diff is
  empty.

Actual integrated release-web renders were reviewed at **390×844, 1440×942 and
1728×942**, in light and dark. Home's compact dot strip, distinct artwork,
article reader and preference editor were visually checked. Browser interaction
verified PC dots/keyboard, canvas mouse swiping, save/list/remove, reader
navigation and source-action feedback. External browser/native dispatch and
the system clipboard are not established by in-app browser feedback; exact
plugin arguments and failure handling have separate Flutter tests.

Better Design guidance and review rules were loaded. Featured-card copy passes
comprehension (23 words/two actions). The whole-feed heuristic flags the requested
topic filters as too many actions; the supplied reference hierarchy takes
precedence, so no whole-page comprehension pass is claimed. Spacing inspection
completed with **100/100 and no findings**, scoped to featured-card semantic
DOM bounds at 390/1440/1728 in both themes. This is measured geometry, not pixel
equality or a whole-screen visual score. [Render receipt](../research/FRONTEND_V0_7_0_RENDER.json).

The developer-only preview runs the real UnlabelApp shell and feature controllers
with memory-only guest storage, disabled account transport and a MockClient that
rejects product requests. Optional saved IDs are an explicit local review fixture.
Production main.dart never imports that preview; the production build includes
the real preferences adapter and all twenty matching images.

## Publication

Implementation 8b5f9064d61c4003a2fd0ae180d0ece933070cfa was successfully pushed
from main to origin/main; the remote tracking check matched at 0 ahead/0 behind.
This docs-only closure preserves that implementation identity and records the
actual push separately from local validation. Hosted verification remains
pending. No new native artifact or release tag was created by this request.

[Feature contract](../architecture/INSIGHTS.md) ·
[Artwork prompts and hashes](../../frontend/assets/artwork/insights/generation-manifest.json) ·
[Preceding correction review](FRONTEND_V0_6_3_REVIEW.md).
