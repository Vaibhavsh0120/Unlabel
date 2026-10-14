# Unlabel frontend

Checkpoint **13 October 2026**: product/build version comes from
[pubspec.yaml](pubspec.yaml); Flutter is pinned in [workspace.json](../scripts/config/workspace.json).
Current [auth/provider update](../docs/planning/FRONTEND_V0_9_0_REVIEW.md) is
authorized for completion and push from main. Native publication remains separate. The
[preceding source scope](../docs/planning/FRONTEND_V0_8_0_REVIEW.md) stays separate.
Maintenance, release and native/device evidence are tracked independently in
[the audit](../docs/planning/MAINTENANCE_2026_10_12.md) and
[release guide](../docs/planning/RELEASE_VERSIONING.md).
Edit pubspec.yaml for future product/build version changes; Flutter's build
metadata supplies About and platform versions without duplicated Dart defaults.

## What works

- Mobile and PC Welcome use the supplied white/forest/mint direction with
  generated decorative pouch/leaves, a working Get started action and optional
  sign-in. Completion stays on the device. A botanical startup screen appears
  only during app state restoration, with no artificial delay; the website has
  no branded loading screen.
- Home Search is mounted before the tap so its persistent input can immediately
  request focus and the mobile keyboard. It retains debounce, stale-response
  guards, bounded pagination, explicit candidate selection and recoverable
  misses/failures. The header uses an opaque surface without status-bar blur.
- The existing floating **Home / Scan / Compare / Saved** design/order remains.
  Its bottom padding is smaller while the operating-system safe area remains.
  Hold the active icon and drag it to preview another tab; release selects it.
  Tap, keyboard and accessibility navigation remain available.
- Scan Label retains its camera viewport and front/back/barcode modes. A captured
  barcode is decoded locally with checksum validation before report/research
  lookup. Known catalogue reports open directly. Missing or ambiguous products
  request front/back photos or a visual candidate selection; the manual entry
  page and barcode sheet are removed.
- Reading begins after capture/gallery selection. Optional backend AI returns
  strict unverified identity, claims, ingredient/declaration text, explicitly
  based nutrient tables and actual detected regions. Declined or unavailable
  cloud reading uses conservative local OCR. Missing values remain unknown.
  Optional acceptance of matching front/back facts creates a distinct confirmed
  observation; AI output never sets confirmation flags itself.
- Sourced current and dated historical reports retain original nutrition bases,
  approximate 4 g sugar cubes, reviewed claim states and six English/Hindi
  ingredient-function entries with source URL/date details. Exact-source server
  comparison retains original tables, bounded session confirmation and explicit
  unknown/conflicting outcomes. Insights and
  Sources remain useful. No universal health score or allergy-safe verdict is invented.
- Profile has a botanical identity card, real current history/saved library sizes,
  optional sign-in/name editing, working library shortcuts, preferences and settings.
  It has no top-right gear or bottom Continue as guest action. Comparisons open
  Compare, but the total is unknown because earlier releases did not record it.
- Dark mode updates persisted device appearance. Preferences and Allergens save
  device-local reminders. Privacy exposes existing sync/conflict/copy/clear actions
  with confirmations; Help explains supported flows and opens About. Signed-in
  users can log out. Notifications are disabled with an explicit explanation that
  this version has no notification service.
- App auth has sign-in, signup, forgot-password and neutral link-sent states.
  Equal-width desktop cards are centered in the right section without scrolling.
  Phone/portrait-iPad cards fill the width and move as one unit over stationary art;
  there is no inner scroll area or visible scrollbar. Keyboard opening lifts the
  card, closing restores its position, and enlarged text wraps under a compact header.
  Login/signup use separate animated mascot, sprout and themed garden layers.
  Signup includes full name and confirmation, without an extra email-option button.
  Profile-origin screens retain their back arrow; Welcome-origin screens do not.
  Firebase's hosted page completes password reset and returns to fixed app sign-in.
  Sign-in methods settings links, disconnects and switches Google/password under
  the same UID/library, protects the last method and confirms sensitive changes.
  Credential collisions never merge accounts. Account deletion requires recent
  authentication, private cloud cleanup, Firebase deletion and owner-local cleanup.
- Profile photo editing uses a gallery crop preview and explicit Save. A private
  192×192 PNG thumbnail of at most 96 KiB and optional gender use the existing named
  Firestore database. Unset/male uses the approved male default; female uses the new
  female default. Google gender is never inferred or requested.
- Guests keep bounded history/bookmarks on the device. Google/password accounts
  use a separate verified-UID namespace and explicit private library sync choices.
  Confirmed public package facts save separately through scanner authentication.
  Report analysis remains useful when authentication or storage fails.

Package camera/gallery photos and raw OCR remain in the capture session and stay
out of reports, public observations and private library sync. Explicitly selected
profile thumbnails are a separate [owner-only contract](../docs/architecture/ACCOUNT_PROFILE.md). Android uses bundled ML Kit
Latin/Devanagari recognition. iOS uses Vision where the selected language is
supported, otherwise offers another clear photo or optional cloud reading. Browser OCR loads pinned same-origin
Tesseract JavaScript/Wasm/language assets only on first use; it does not send the
photo to an OCR provider. Inputs, decoded dimensions, text and execution time are
bounded, with cancel/late-response guards. Asset download and first OCR startup
still depend on device/network speed. Cloud consent explains temporary backend
photo processing and provider data-use terms. Structured unverified output may
enter bounded private staging; images/raw OCR/geometry never enter that store.

Search first-page loading uses a skeleton that respects reduced motion and page
visibility; existing results remain visible during refresh. Public search results
are cached for 60 seconds (20 entries), historical reports for five minutes
(40 entries), with concurrent identical requests shared. Failed/unavailable results
are not retained. Background report requests for thumbnails are limited to two;
a selected result starts immediately. These caches are in memory and contain no
private account data or confirmed-label POST responses. Smaller image decode
sizes reduce decorative/thumbnail work. These changes have regression coverage,
not a claim of measured device-wide latency or frame-rate improvement.

Continuous live-feed barcode recognition/highlights, comparison-history
totals, notification delivery, personal suitability and broader ingredient coverage
remain future work. Reminders do not filter products or establish allergy safety.
Already stored reports can be reopened without a fresh API request; first-visit
offline website availability is not established.

## Run and check

From the repository root:

~~~sh
python scripts/setup.py
python scripts/run_local.py
~~~

From this folder, use pinned Flutter **3.47.4**:

~~~sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
node --test test/*_web_test.cjs
~~~

From the root, `python scripts/release/vendor_web_ocr.py --check` verifies the 21 tracked
browser OCR assets offline; reacquisition is an explicit maintenance action.
`python scripts/release/generate_app_icons.py --check` verifies the 42 existing icon assets.
Artwork and the startup font retain source/license records under their asset folders.

Historical v0.4.0 evidence: **181 Flutter tests passed**, clean analysis and web build,
comparison/manual-report/evidence browser checks. Earlier v0.3.0 additionally
passed four browser OCR bridge tests and pinned asset checks. Its compiled local browser recognized
a synthetic oats/ingredients/protein label. Android Kotlin compilation passed;
physical camera/OCR behavior still needs a device check. iOS Vision source has not
been compiled on this Windows host. Web/widget tests do not prove installation,
native haptics, picker interruption or recognition accuracy across real packages.
Mounted-search regression coverage verifies the input takes focus when Home Search
is tapped; a physical mobile keyboard remains a separate device check.

The launcher supplies local API/release settings. Production uses the HTTPS API.
[Configuration policy](config/README.md) describes endpoint and Firebase settings.
Native APK/unsigned-IPA workflows remain manual and independent of backend/web
source releases. No Firebase billing/card setup or custom training is introduced.
Gemini/OpenAI extraction uses the operator's configured credentials; provider
availability and data-use terms remain separate from Flutter verification.
See the [local repair review](../docs/planning/FRONTEND_V0_8_1_REVIEW.md) for current
gates. Reset email requests use SDK ActionCodeSettings with handleCodeInApp:false
and a fixed authorized Unlabel sign-in return. The rejected custom action URL is
not required. Real email delivery and provider/device acceptance remain separate
from local tests or a synthetic generated-link check; this bugfix is not pushed.

## Source ownership

| Path | Current responsibility |
| --- | --- |
| lib/app | Composition, theme, appearance, startup/Welcome and public build/Firebase configuration |
| lib/core/capture | Barcode-first reading, bounded photo preparation, AI/local OCR fallback and camera lifecycle |
| lib/core/models | Validated report/search models and explicitly confirmed label draft |
| lib/core/network | Bounded HTTP, capabilities, public read caches and scanner Auth |
| lib/core/storage | Bounded local reports, bookmarks and appearance |
| lib/core/accounts | Firebase identity/provider linking, private media, password policy and bounded library sync |
| lib/features/account | Reference auth, Profile/photo/settings windows and device-only reminders |
| lib/features/scanner/presentation | Desktop/mobile Home, automatic Scan, qualified/confirmed/researched results, comparison and libraries |
| assets/artwork, assets/brand | Decorative artwork, startup font, icon masters and provenance/license records |
| assets/icons | Bundled Solar feature icons with attribution/license |
| test | Network/model/storage, OCR, form, lifecycle and responsive interaction regressions |
| android, ios, web | Platform projects, OCR integration and pinned browser runtime assets |

[Account/screen plan](../docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md) ·
[UI requirements](../docs/planning/UI_REQUIREMENTS.md) ·
[Data flow](../docs/architecture/DATA_FLOW.md) ·
[API contracts](../contracts/README.md) ·
[Release/versioning](../docs/planning/RELEASE_VERSIONING.md)
