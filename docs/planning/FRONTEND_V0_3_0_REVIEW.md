# Frontend v0.3.0+4 review

Checkpoint: **8 October 2026**. Scope: Flutter screens, local capture/OCR, barcode
fallback, search/nav behavior, public-read performance and related assets/docs.
Backend v0.7.0 and frontend v0.2.0 remain independently published. Backend v0.8.0
sourced comparison is a separate release; this client still uses its existing
compatible-basis comparison and does not require the new endpoint.

Stage: **implemented, locally tested and visually checked**. Release web build
passed; light-mode Welcome/Profile were inspected at 390, 1440 and 1728 pixels.
Push, hosted verification and source publication are pending. This document does
not serve as a production receipt.

## Accepted screen and interaction boundaries

The latest user corrections take priority over the attached concept pictures:

- Keep the existing four-tab **Home / Scan / Compare / Saved** navbar design/order,
  with Profile at the top right of main screens. Do not copy the five-tab
  reference navbar. Reduce its excess bottom padding while keeping safe-area
  protection; make the active icon and green indicator follow a hold/drag gesture.
- Keep the Scan Label layout unchanged. Add working behavior behind capture and
  post-capture review, and move manual barcode fallback into this screen.
- Match the botanical white/forest/mint Welcome and Profile direction, including
  a responsive PC composition. Profile has no top-right gear and no bottom
  Continue as guest action. Show real account/library values instead of sample
  personal identity or invented statistics.
- Show the botanical Unlabel startup screen only in the app during state restore.
  The website has no branded loading screen and no artificial loading delay.
- Request mobile keyboard focus in the Home Search tap, remove the header/status-bar
  blur effect, and improve loading/performance after the screen work.

## Implemented behavior

Welcome uses generated pouch/barcode/leaves art, responsive phone/desktop
composition and working Get started/optional account actions. Completion and
appearance stay device-local. App startup uses a bundled licensed serif font,
botanical artwork and loading semantics; `kIsWeb` excludes this screen.

Profile uses a botanical identity card, active-namespace library sizes, Preferences
and Settings. Signed-in users can edit their name and log out; guests can sign in
from the identity card. Scans/Saved open the actual libraries. Comparisons opens
Compare but shows an unknown count because no historical total was recorded.
Dark mode persists; Preferences/Allergens save bounded device-local reminders.
Privacy retains private sync status, explicit cloud/device replacement choices,
guest-copy and confirmed account-data clearing. Help explains supported flows
and opens About. Notification delivery is unavailable; the switch is disabled
and its row explains the limitation. These reminders do not filter products or
establish suitability/allergy safety.

Search is persistently mounted behind the shell and receives focus directly in
the tap gesture. It retains debounce, cursor pagination and stale-result guards.
An interaction regression verifies that the mounted input takes focus on the
Home Search tap; physical mobile keyboard behavior remains a device gate.
The header is opaque without elevation tint or a status-bar blur. Navigation
keeps its existing visual system with two pixels of extra bottom padding inside
the safe area. Hold/drag previews selection, moves the selected icon/indicator,
provides supported selection feedback and commits on release; cancellation and
app backgrounding restore the current tab.

The obsolete `LookupPage` and its standalone Find a product route are removed.
Scan's barcode mode opens an autofocus sheet with exact 8/12/13/14-digit validation,
leading-zero preservation, one pending lookup, recoverable errors and a manual
label fallback. Dismissal cannot open a late report. Captured photos, camera/gallery
controls and Scan viewport stay in the established UI.

Post-capture review reads local English/Hindi text, lets the person edit it and
apply conservative name/ingredient/allergen suggestions. Nutrition stays manually
reviewed. Only explicitly confirmed facts are sent to the existing report API,
with corrected OCR provenance where used. Photos/raw OCR are excluded from
report, public-fact and private-sync payloads. Inputs are bounded to 12 MiB,
24 megapixels and 12,000 characters; timeout, cancellation and late-result guards
retain the manual route.

Android uses bundled ML Kit Latin/Devanagari recognition with bounded decoding
and EXIF orientation handling. iOS uses Vision and explicitly checks selected
language support. Browser Tesseract 7 runtime/core and English/Hindi models are
pinned, licensed and hash-verified same-origin files. They load only on OCR use,
with no photo upload/provider request or retained private OCR cache.

## Performance changes and local evidence

- Public search cache: 60-second TTL, 20 entries, LRU eviction.
- Historical public report cache: five-minute TTL, 40 entries, LRU eviction.
- Concurrent identical public requests share a future; failed/unavailable results
  are retried rather than retained. Confirmed-label POSTs and account data bypass
  these caches. Closing the repository blocks late cache repopulation.
- Thumbnail report requests use a two-request background queue; a tapped result
  starts immediately. Hidden/changed/disposed search discards queued work.
- First-page search has an accessible skeleton; reduced motion/page visibility
  stop unnecessary animation. Refresh retains existing results.
- Decorative/thumbnail image decode sizes are bounded. Report save feedback uses
  a route-local messenger to prevent duplicate SnackBar Hero failures on rapid
  save/back/Profile navigation.

Fresh local checks reported by the execution run:

| Check | Evidence |
| --- | --- |
| Flutter analysis | No issues |
| Flutter regression suite | 168 passed |
| Browser OCR bridge tests | Four passed |
| Browser OCR vendored files | 21 hashes verified |
| Existing platform/icon assets | 42 verified |
| Real compiled-browser OCR | Synthetic oats label, ingredients and protein text recognized locally |
| Android bridge | Kotlin compilation passed |
| Final release web build | Passed, including Wasm dry run |
| Final rendered reference checks | Light Welcome/Profile at 390, 1440 and 1728 pixels; [captures](../research/ui-v0.3.0/README.md) |
| Push / hosted source and assets / source release | Pending |

The synthetic browser check proves the bundled runtime can perform local
recognition. It does not establish real-package OCR accuracy, Hindi accuracy,
device-wide latency or a measured frame-rate improvement. Cache/queue tests
establish bounded request behavior rather than a hosted speed benchmark.

## Remaining gates and next-version work

Release web build and rendered phone/PC checks are complete. Profile dialogs
open real controls, and notification unavailability is visibly labelled. The
retired Find a product page and unused Scan search callback are removed.
Run the final Markdown/local-link/script/private-data review before push.
Record implementation source SHA and exact hosted deployment separately from
later documentation-only closure commits. Publish frontend independently;
manual native APK/unsigned-IPA builds remain a separate lane.

Automatic barcode camera detection and continuous live highlights remain future
work. Follow-on frontend work also covers source-aware comparison endpoint
integration, explicitly designed comparison-history persistence, notification
behavior/provider choice and broader reference-screen refinements. Backend v0.8.0
provides sourced comparison separately; reviewed bilingual ingredient coverage
belongs to its later backend plan. No unsupported feature is advertised as active.

Physical Android camera/gallery/OCR, picker interruption, haptics and launcher
behavior need real-device checks. iOS Vision has source review only on this
Windows host; macOS/Xcode compilation, supported-language behavior and physical
device recognition remain gates. Neither a web build nor an unsigned IPA proves
iPhone installation. No card, paid OCR provider, Gemini or custom training is added.

[Screen/account checklist](ACCOUNT_SYNC_SCREEN_PLAN.md) ·
[Controlled releases](CONTROLLED_RELEASES.md) ·
[Next frontend/backend versions](FRONTEND_BACKEND_NEXT_VERSIONS.md) ·
[Design contract](../../DESIGN.md)
