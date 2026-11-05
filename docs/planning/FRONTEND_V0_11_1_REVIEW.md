# Frontend 0.11.1+16: scanner and visual maintenance

5 November 2026. Backend stays at 0.15.0. This patch preserves scanner navigation
and the free native `mobile_scanner` 7.4.2 / same-origin
ZXing-C++ WASM 3.1.3 engines. No new service, dependency or billing is required.

## Findings and changes

- The scanner requested 1280×720 video and had no pinch gesture. It now prefers
  1920×1080 (the device may negotiate a lower resolution) and supports pinch zoom
  through native SDK controls or browser track zoom capabilities. Hardware writes
  coalesce to the latest gesture value. Unsupported controls leave scanning usable.
  Android's existing automatic zoom and iOS close-range lens selection remain.
- The SDK's native focus handler used whole-screen coordinates, although the
  preview occupies only part of the screen. Taps now map through the preview's
  cover crop, orientation and front-camera mirror. Focus errors are contained.
  Web uses the SDK's existing continuous autofocus; its unimplemented tap-focus
  method is no longer called. Browser hardware zoom depends on camera/browser
  support; there is no cosmetic preview-only enlargement.
- The local still reader shrank every image to 1400px. A synthetic 3200×2400
  image with a small off-center EAN failed before this patch. Failed reads now
  retry from the original encoded photo at up to 2800px, rather than enlarging
  discarded pixels. Normal successes keep the inexpensive first pass. Native
  SDK still failures also try this independent local reader. Barcode gallery
  selections retain up to 2800px at higher quality; front/back settings stay as-is.
- Web still reading now uses the scanner-owned reader, with explicit cancellation
  and disposal, instead of creating an unowned reader for each gallery request.
  Cancelled native SDK results cannot start fallback work or accept an identity.
  The existing hint explains pinch zoom and the failure text no longer tells
  users to move closer when that can put the barcode outside the focus range.

Pixel limits, checksum/product-format validation, one-result routing, private
temporary-file cleanup, camera ownership and no-network decoding are preserved.
Full photographic blur, glare and missing bars cannot be reconstructed reliably.

## Shared visual improvements

Later user steering expanded scope to a modern glass look in both themes with
Manrope headings and Inter body text, forms and navigation. The pairing includes
auth and product-report typography. Both fonts are bundled locally with OFL
notices, in-app license registration and source/hash provenance. Existing startup
serif branding and historical licensed assets remain.

The shared palette uses forest/mint accents, teal-charcoal dark surfaces, neutral
secondary text and quiet borders. Shared cards and desktop search use layered
glass gradients; the sidebar has a tonal surface and phone navigation adds a
clipped 12px backdrop blur. High-contrast mode uses opaque panels and disables
blur. Scrolling cards and camera frames avoid repeated backdrop filters. Shared
page/section spacing is consistent; navigation, auth states, evidence and tap
targets remain. Browser theme-color matches the app surface. See [design notes](../../DESIGN.md).

## Verification

- Regression reproduced before the fix: small EAN in a large package photo.
  Native Dart decoding now returns the correct identity and normalized anchors.
- Native tests cover pinch bounds/stopped cameras, preview-relative focus,
  SDK-still fallback, cancellation, checksums and private temporary-file cleanup.
- Node tests cover browser zoom capabilities, retained camera constraints,
  unsupported controls, high-detail worker inputs and camera ownership.
- Actual Chromium with the self-hosted worker/WASM passes all four rotations,
  inverted contrast, invalid-checksum rejection, cancellation/retry and the small
  off-center barcode (166px wide in a 2800×2100 image). Repeat using
  `frontend/test/barcode_runtime_fixture.html` and `runBarcodeFixtureChecks()`.
- Full Flutter suite: 524 passed, including orientation/cancellation additions
  and both-theme responsive layout checks; focused scanner suite: 30 passed.
- Full backend suite: 1493 passed, 5 skipped. Existing Starlette/httpx deprecation
  warning remains. Ruff and all 16 script tests passed; 35 Node web/auth tests passed.
- Production JavaScript web build succeeded with canonical 0.11.1+16 metadata.
  The existing Google Identity Services Wasm dry-run warning remains.
- Actual production-build renders passed on Home at 390×844 and 1440×1000 in
  both themes, with both bundled fonts returning HTTP 200 and no page errors.
  Auth renders passed on phone/desktop and both iPad orientations (portrait light,
  landscape dark). [Visual receipt and screenshot hashes](../research/FRONTEND_V0_11_1_VISUAL.json).
- Workspace source/docs/link validation, pinned OCR assets, platform icons and
  diff whitespace checks passed. Backend source and data are unchanged.
- [Production asset receipt](../research/FRONTEND_V0_11_1_HOSTED.json) verifies
  READY deployment `dpl_CyR4rKjjtPML5CMeuVgvuWu58RZB` at implementation
  `66f5e39ef5e04347ecc7face2a4525a962a1cdaf`, version 0.11.1+16 and exact scanner,
  browser-appearance and Manrope/Inter font bytes. Repository CI passed for that
  source. Release-policy follow-up adds 19 passing script guard tests and 25
  passing workspace integration checks; it does not change the compiled apps.

## Release-list organization

Historical release titles now explicitly distinguish frontend apps, frontend
web/source, backend API and the LiveContainer subscription. The
[title-only audit](../research/RELEASE_ORGANIZATION_2026_11_05.json) records 38
changes with tags, notes, download identities and historical release states
preserved. The obsolete Latest pointer was caused by newer mobile releases being
prereleases. The follow-up organization workflow now reserves
Latest for a verified, published frontend app built by successful GitHub Actions.
The follow-up validates owned main-branch workflow identity, exact source tag,
Actions bot author, and matching LiveContainer IPA URL/size/hash. Manual retries
require a completed frontend workflow run ID. Backend, source-only, draft and
failed workflows cannot qualify. Latest selection is not performed locally.

The Better Design free-call allowance was exhausted; discovery/guidance/review
calls returned no result. Styling follows the user's direction and the existing
Flutter design system. Physical Android/iPhone camera,
focus-distance/glare accuracy and native artifact execution remain unverified.
Pushing the version increase requests the existing native release workflow;
source push, hosted deployment, APK/IPA publication and device acceptance are
separate evidence. Historical release tags and receipts remain untouched.

References checked: [mobile_scanner configuration](https://github.com/juliansteenbakker/mobile_scanner/blob/develop/_autodocs/configuration.md),
[ZXing WASM reader options](https://github.com/sec-ant/zxing-wasm/blob/main/_autodocs/api-reference/readerOptions.md),
[browser track constraints](https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrack/applyConstraints).
The installed pinned SDK source was also inspected because newer docs contain
API differences.

[Preceding scanner/product review](FRONTEND_V0_11_0_REVIEW.md) ·
[Feature tracker](FEATURE_TRACKER.md) · [Release ledger](CONTROLLED_RELEASES.md).
