# Flutter frontend

Frontend **0.1.0+2 — Connected Label Reader** replaces the starter with a working
Flutter client. Backend **0.6.0 — Product Discovery** adds bounded catalogue
search and is independently published with 23 hosted checks after v0.5.0. Local implementation is present; final layout/test, browser, publication and native-device evidence are separate gates in
the [connected release plan](../docs/planning/CONNECTED_RELEASE_PLAN.md).

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
- White/forest/mint Material 3 appearance, Light (default)/Dark/System selection, reflow for
  narrow screens and large text, and locally bundled Solar icons with attribution.

Camera, image selection/OCR, live highlighting, comparison, personal suitability
and insight feeds remain future work. There are no non-working buttons for them.
A stored report can be reopened without a fresh API request while the app is
loaded; first-visit offline website availability is not established.

The [next accepted v0.7.0/v0.2.0 plan](../docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md)
adds first-launch Welcome, complete reference-style light/dark screen destinations
and optional scanner login/private sync. This does not change the current
v0.1.0 boundary: personal data stays local, and public package facts save separately.

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

Reserved camera/OCR, preference/comparison, knowledge and localization folders
remain plans. The backend owns deterministic criteria; the client does not
reimplement FSSAI thresholds or train a model.

[UI requirements](../docs/planning/UI_REQUIREMENTS.md) ·
[Data flow](../docs/architecture/DATA_FLOW.md) ·
[API contracts](../contracts/README.md) ·
[Release/versioning](../docs/planning/RELEASE_VERSIONING.md)
