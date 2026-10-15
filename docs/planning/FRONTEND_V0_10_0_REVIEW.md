# Frontend 0.10.0+14 - scanner and unified product information

Working review, 15 October 2026. This follows published 0.9.0+13; historical
release receipts remain unchanged. The user authorized completion and push on
main, automatic native publication and the stable LiveContainer feed.

## Delivered source

- iPhone Safari auth no longer switches to the tiny artwork layout when browser
  controls reduce viewport height. Tapping outside a field dismisses its keyboard.
  Existing fixed desktop cards and whole-card mobile movement remain.
- Google popup startup uses the restored SDK synchronously from the tap, avoiding
  an unnecessary initialization await. Existing owner/provider collision guards
  remain. Real iPhone Google consent is a separate device acceptance check.
- Guest display names persist only on that device, independently of signed-in
  profile/library namespaces. No cloud write or account is required.
- Sign-in methods follow the supplied phone/desktop hierarchy: email/password,
  Google connection, method/security guidance and account deletion. Existing
  reauthentication and last-provider protection remain active.
- Scan opens in Barcode mode with Front/Back/Barcode controls, larger preview,
  flash/camera switching where supported, gallery and captured-photo processing
  animation. Reduced motion and stop/cancellation paths remain available.
- Mobile Scan retains the same shared brand/search/profile AppBar as the other
  screens. One continuous mascot/garden layer extends behind preview and controls;
  the floating bottom navigation remains accessible. The local scanner header keeps
  only Scan Label: duplicate back/settings icons and the instruction line were
  removed, enlarging the preview to 440 px at 390x844 with the app header/navbar.
  Photo-reading consent can be reset from Profile > Privacy.
- Preview uses aspect-preserving cover. Capture crops the upright still to the
  preview aspect and then to the visible viewport. Mode/lifecycle/resize changes
  discard stale captures; front-camera text is unmirrored.
- `ProductInfoPage` is the only product destination for report, research,
  extraction and unknown-barcode results. Private content widgets retain original
  evidence sections. The visual Product Info redesign is explicitly deferred.
- Front/back photos continue to AI reading even when a barcode is visible.
  Extracted names search both catalogues; brand/variant/pack-size choices remain
  explicit. A model match does not silently select another SKU.
- Cloud consent v2 explains automatic unverified product contributions. The app
  shows the backend receipt instead of asking for a fabricated human confirmation.
  Old consent v1 is not reused for the broader sharing behavior. The obsolete
  machine-to-confirmed draft converter and its acceptance UI are removed.
- Optional live NutriGraph fields and public machine readings appear separately
  from saved report data. Vendor facts stay in memory, expire on an open page,
  and never enter report/history/account serialization. No trial key is present;
  the optional provider remains disabled.

Captured barcode decoding uses ZXing with bounded wider-row and inverted-luminance
retries. Synthetic fixtures cover off-center placement, four orientations, lower
contrast, checksum rejection and cancellation. These establish regression coverage,
not measured real-camera accuracy. ZBar requires platform integration and a
comparative device benchmark before adoption; no new native/WASM dependency is added.

Photo-read front claims travel with the selected product/pack size to a read-only
catalogue check. Source-table comparisons are shown with missing applicability and
current-package context qualified as insufficient. No confirmed-input flags or
uploaded AI nutrition enter this request.

## Validation and limits

Local release checks on 15 October:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 497 passed.
- `flutter build web --release --no-pub`: succeeded (JavaScript release build).
- Node web/auth-bridge tests: 22 passed; script tests: 16 passed.
- Workspace validation, current contract export, OCR assets (21) and platform
  icons (42) passed; no broken locked Python requirements; Ruff passed.

Coverage includes Safari viewport/keyboard behavior, guest persistence, provider
management, camera lifecycle/crop geometry, front/back routing, unified page
sections, claim provenance, source identity validation and live expiry. The web
build emits the existing third-party Google Identity Services Wasm dry-run warning;
this release uses the supported JavaScript build, not a Wasm build.

Synthetic images prove framing geometry and decoder behavior, not real camera
accuracy. Physical iPhone Safari, Android/iOS camera sensor framing, permission
prompts, Google consent and LiveContainer launch require device acceptance.
NutriGraph India/EAN-13 coverage and live response behavior await the vendor key.

Rendered synthetic fixtures were inspected at iPhone 390x844 (both themes), iPad
768x1024 and 1024x768, desktop 1440x900 and 1728x1000, and 320x844 with 2x text.
Processing-photo and sign-in-methods phone/iPad/desktop views were also inspected.
The shared mobile header and continuous artwork reflect the final user requests.
No browser page errors were recorded. Better Design DOM inspection completed at
390/1440/1728; only nonvisual offscreen Flutter announcement nodes were excluded,
with raw captures retained locally. Flutter canvas control spacing is supported
by widget geometry/tests and screenshots, not invented DOM card measurements.
[Visual receipt](../research/FRONTEND_V0_10_0_VISUAL.json).

## Release state

Local validation is complete. Source push, hosted deployment, native publication
and stable-feed verification are recorded separately after publication.
