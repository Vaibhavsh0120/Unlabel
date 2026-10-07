# Flutter frontend

Frontend **0.2.0+3 — Welcome, Home and Optional Account** is implemented locally
and locally verified; docs/push/publication are authorized after final review.
Published frontend **0.1.0+2** remains the production release. Backend
**0.7.0 — Private Account Sync** is independently pushed, hosted-verified and
published. Follow the [controlled releases](../docs/planning/CONTROLLED_RELEASES.md).

One application directly in this folder targets Android, iOS and web. The
website is [unlabel-india.vercel.app](https://unlabel-india.vercel.app); its shared
API is [unlabel-api.vercel.app](https://unlabel-api.vercel.app). These are separate
Vercel projects. See [deployment settings](../docs/planning/VERCEL_SETUP.md).

## What works

- Manual barcode lookup and name/brand search, with explicit candidate selection,
  bounded pagination, loading, misses, refinement and recoverable failures.
- A manual current-label form: identity, printed ingredients/allergen declarations,
  nutrient rows, table basis/preparation and front claims. Blank values remain
  unknown. The person confirms facts and front/back pairing before analysis.
- Sourced current and dated historical reports, original nutrition bases,
  approximate sugar cubes, reviewed claim states and three English/Hindi
  ingredient-function entries. No invented score or allergy-safe verdict.
- Automatic structured-fact storage through anonymous scanner authentication.
  Analysis remains available when authentication or storage fails. There is no
  Share flag or admin/reviewer account.
- Device/browser-local recently viewed history and explicit bookmarks, removal,
  history clearing, bounded storage and readable persistence/recovery errors.
- First-use Welcome, reference-style Home, four Home/Scan/Compare/Saved tabs,
  top-right Profile, optional password sign-in and isolated private sync with
  explicit conflict choices. Guest records remain device-local.
- Compatible-basis product comparison, sourced Insights and Sources destinations.
- White/forest/mint Material 3 appearance, Light (default)/Dark/System selection, reflow for
  narrow screens and large text, charcoal dark surfaces, filled-leaf branding and
  locally bundled Solar feature icons with attribution. Seven decorative artwork assets
  have recorded provenance; gentle motion respects accessibility and visibility.
- Navigation and confirmed save feedback, with harmless unsupported haptics.

Opening Scan requests camera permission and shows the live feed in an adaptive,
non-scrolling viewport. Camera/gallery photos stay in session memory for manual
review; audio and uploads are disabled. Search updates as you type and opens
actual reports. Home tips are manually swiped, with no autoplay/pause controls.
Reference-style Results/Compare use sourced evidence instead of illustrative scores.
Local OCR, automatic barcode reading and Ingredient Insights complete the separate
frontend v0.3.0 release. Continuous live-camera highlighting, personal suitability
and broader ingredient knowledge remain future work.
A stored report can be reopened without a fresh API request while the app is
loaded; first-visit offline website availability is not established.

The [account and screen plan](../docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md)
retains independent version boundaries. Personal records sync only after optional
password sign-in; public structured package facts save separately.

## Run and check

From the repository root:

~~~sh
python scripts/setup.py
python scripts/run_local.py
~~~

From this folder, use the pinned Flutter **3.47.4** toolchain:

~~~sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
~~~

The launcher supplies the local backend URL and release metadata. The default
public backend is production HTTPS. [Configuration policy](config/README.md)
describes endpoint and Firebase settings. Native APK/unsigned-IPA workflows
remain manual; web/widget checks do not prove camera behavior or an installable
iOS distribution.

## Source ownership

| Path | Current responsibility |
| --- | --- |
| lib/app | Composition, Material 3 theme, appearance and public build/Firebase configuration |
| lib/core/models | Validated report/search display models and confirmed-label draft |
| lib/core/network | Bounded HTTP, capability/version handshake and anonymous scanner Auth |
| lib/core/storage | Bounded private local reports, bookmarks and appearance preferences |
| lib/features/scanner/presentation | Home, lookup, label entry, reports, ingredient details, saved/history views and shared widgets |
| assets/brand | Authored light/dark app-icon masters, generated platform assets and verification manifest |
| assets/icons | Bundled Solar feature icons and their attribution/license |
| test | Network/model/storage, form and responsive interaction regressions |
| android, ios, web | Platform projects for the same Flutter application |

OCR and automatic barcode reading remain the next controlled release. Broader preferences, knowledge and
localization remain plans. The backend owns deterministic criteria; the client does not
reimplement FSSAI thresholds or train a model.

[UI requirements](../docs/planning/UI_REQUIREMENTS.md) ·
[Data flow](../docs/architecture/DATA_FLOW.md) ·
[API contracts](../contracts/README.md) ·
[Release/versioning](../docs/planning/RELEASE_VERSIONING.md)
