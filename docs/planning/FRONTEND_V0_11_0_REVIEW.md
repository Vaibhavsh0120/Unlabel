# Frontend 0.11.0+15 - product information, scanner and web refinement

Release review, 26-27 October 2026. This follows the 0.10.0 source checkpoint.
Historical reviews and publication receipts retain their own evidence dates.
The user requested completion of the ongoing work, a reference product-page and
phone scanner redesign, smoother web behavior with particular attention to
iPhone Safari, a guest sign-in-methods toast and the supplied optional food API.

## Product-information source scope

- `ProductInfoPage` remains the single destination for catalogue reports,
  researched products, machine-read labels and unknown barcodes. Opening a page
  does not promote a website observation or machine reading into a confirmed
  package fact.
- The supplied desktop/phone product references now drive the report hierarchy:
  identity/photo/save/barcode, recorded-value summary, four evidence cards,
  nutrition snapshot, ingredient/allergen tabs, qualified allergen notice,
  expandable missing facts and source references. Desktop uses main/supporting
  columns; phones use the same content in one ordered scroll surface.
- The latest user correction explicitly requests smaller phone text. A scoped
  product theme uses the existing bundled Nunito headings and Quicksand body:
  21 px product names, 18 px section headings, 14 px secondary headings, 12 px
  evidence-card headings and 11–13 px body copy at ordinary phone text size.
  Phone product images use an 80 px contained slot and 16 px card padding.
  Barcode digits, the existing barcode vector and their copy action share a row
  with the short Save action when space permits. Controls retain 48 px targets.
  TextScaler is unchanged; enlarged text wraps and stacks naturally.
- The summary uses a 56 px leaf ring and 26 px phone count, a real evidence tag,
  concise unknown/current-package qualifications and an explicit no-health-score
  statement. The generated transparent botanical decoration occupies a separate
  layout slot and never overlaps live copy or substitutes for a product image.
- Four evidence cards form two phone columns or four desktop columns at ordinary
  text size. Six nutrition tiles include total sugars and preserve unknown or
  conflicting values. The complete original nutrient rows, bases, preparation,
  evidence states, dates and source identifiers remain in the nutrient disclosure;
  different bases are not combined or inferred.
- Ingredients and Allergens are interactive tabs. The existing ingredient-function
  reader, source qualifiers and unreviewed/missing states remain. The missing-fact
  section initially shows four items and expands to all recorded warnings and
  missing inputs. Source references retains image attribution, the full Creative
  Commons license name/code and license URL. Declaration provenance has its own
  distinctly named source disclosure.
- Claim checks, ingredient insights, approximate sugar conversion, catalogue
  update receipts and optional live/machine supplements remain reachable. Existing
  save/error handling, session-photo privacy and live-reading expiry remain.
  Research/extracted pages reuse the updated identity/summary/evidence surfaces
  without losing their own original source tables or evidence qualifications.
- Mobile product navigation uses the existing real Home/search/Profile callbacks;
  the no-navigation fallback still exposes Product info and platform back behavior.

## Product checks and remaining evidence

Focused report/research/extracted/live-supplement tests passed during implementation.
The latest phone-sizing pass additionally loads the actual bundled fonts in the
report-layout suite and checks that the ordinary 390 px summary is at most 160 px.
The report suite also covers adaptive evidence/nutrient grids, total sugars,
ingredient/allergen selection, missing-fact expansion, full nutrient provenance,
both themes and 320 px enlarged-text reachability. These are widget regression
checks, not exact reference acceptance or a physical iPhone Safari benchmark.

Better Design review rules were loaded. Product identity, summary, evidence,
nutrition, declarations, unknown facts, source references and ingredient-insight
copy passed comprehension checks; the abbreviated image license was expanded for
readability while preserving its license code and URL.

Final local checks on 27 October: `flutter analyze --no-pub` found no issues;
all 507 Flutter tests passed; all 32 Node web/auth-bridge tests passed; the
production JavaScript web build succeeded. The existing third-party Google
Identity Services Wasm dry-run warning remains; this is a JavaScript build.
Workspace source/docs/links, 21 pinned OCR assets, 42 platform icons and 16 script
tests passed. Actual private-key scans found no source or compiled-web leaks.

Rendered verification after the latest sizing correction belongs to the
[visual receipt](../research/FRONTEND_V0_11_0_VISUAL.json). Hosted deployment,
native publication and physical-device acceptance remain distinct gates.
The sourced product photo displays in Chromium and in unchanged WebKit with
software CanvasKit rendering. Windows headless WebKit's default GPU path left
that photo blank despite identical valid JPEG bytes, successful HTML image
decoding and permissive CORS. This isolates a renderer/environment difference;
the application does not force software rendering or claim physical Safari proof.

## Scanner, web and account checks

Barcode mode uses the free `mobile_scanner` 7.4.2 SDK: CameraX/ML Kit on Android,
Apple Vision/AVFoundation on iOS, and pinned ZXing-C++ WASM 3.1.3 on web. No
Dynamsoft trial, card, account or subscription is required. Front/back still
capture retains the camera plugin; the two camera owners are mutually exclusive.
Local barcode results go directly to the existing report/research lookup path.
Valid EAN/UPC checksums, actual decoder corners and the scan window are enforced;
duplicates and late mode/route/background results cannot reopen a product.
The optional native iPhone close-range lens uses supported SDK APIs with fallback.

The web decoder JS/WASM and MIT/Apache notices are self-hosted with package
integrity and file hashes. Still-image decoding runs in a bounded, cancellable
worker; no old Dart decoder is silently substituted on web. Ordinary native
front/back label interpretation retains its separate local barcode helper.

Actual Chrome `getUserMedia` tests with owned synthetic Y4M video verified the
real SDK reading one checksum-valid EAN, duplicate suppression, scan-window
exclusion and cancellation. They exposed package web omissions that the app now
guards: SDK video is muted/playsinline before play, and only SDK-owned tracks
are explicitly ended on detection/stop/close or a late permission completion.
The corresponding Node regression checks preserve unrelated camera sessions.
[Controlled SDK receipt](../research/SCANNER_SDK_V0_11_0_SYNTHETIC.json).
These are controlled browser tests, not physical package/device accuracy.

The actual self-hosted still-image WASM decoder also passed in WebKit 26.0
with four rotations, inverted contrast, invalid-checksum rejection and
cancellation/retry. That fixture made no external requests and reported no
browser errors. Static native SDK/platform compatibility checks passed;
APK/IPA compilation and physical-camera accuracy remain separate evidence.

The scanner follows the requested clean camera composition with mint corners,
Front/Back/Barcode selection, Click Photo and Choose Photo, preserving the shared
header and four-tab navigation. Short windows and enlarged text keep actions
scroll-reachable. Search loading pulses paint only their shapes instead of
rebuilding opacity layers; motion stops when backgrounded or reduced motion is
enabled. Existing route/scroll pause behavior for decorative artwork remains.

Guests tapping Sign-in methods receive `Please sign in to manage sign-in methods.`
without opening provider management or an unexpected auth screen. Explicit Sign in
remains available separately. Signed-in provider/linking/last-method guards remain.

## Release state

Implementation commit `2246edaa32b29fefef640a53081e8d1ecb8ecb3f` was pushed to
main on 27 October. [Repository CI](https://github.com/Vaibhavsh0120/Unlabel/actions/runs/40510533854)
passed. Both Vercel production deployments are READY and authenticated deployment
metadata maps their public aliases to that exact source. Nineteen
[hosted checks](../research/RELEASE_2026_10_27_PRODUCTION.json) verified web
0.11.0+15, API 0.15.0, the preserved data/knowledge, unauthenticated rejection
guards and the exact self-hosted decoder assets/runtime.

The live guest browser flow also passed ten checks across 390 px phone and
1440 px desktop layouts: welcome, the public Maggi report, product source
references, Sources and the scanner fallback/gallery action. The actual product
photo displayed. There were no page errors or unexpected console errors;
two expected blocked-request console entries came from deliberately intercepting
optional NutriGraph calls before transport. Camera permission was not granted;
capture stayed disabled and gallery remained reachable with 48/60 px targets.

The hosted checks made no authenticated AI or vendor lookup and no record writes.
Native publication is recorded separately. Hosted/source proof does not establish
physical-device camera, Google-consent or LiveContainer execution.
