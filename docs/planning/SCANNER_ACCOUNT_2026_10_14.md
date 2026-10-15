# Scanner and account update - 14 October 2026

This work follows published frontend 0.9.0+13/backend 0.13.0. Work stays on main;
published artifacts and source evidence remain immutable. The user authorizes
completion, deployment, native publication and the existing stable iOS feed.

## Implementation order

The user will visually redesign Product Info in the next update. This update
consolidates ReportPage, ResearchedProductPage and ExtractedProductPage into
`ProductInfoPage`, with one page shell and private source-specific content.
Search, scanning, history and saved products use this destination. Preserve
current sections, source distinctions and actions while connecting new data.

1. Repair iPhone 13 Safari auth: keep width-based hero dimensions when browser
   chrome changes the viewport; tap outside an input dismisses the keyboard.
   Preserve whole-card travel, keyboard restoration and large-text access.
2. Enable device-only guest display names without adding cloud writes or mixing
   guest/account namespaces. Check Google popup startup using current Firebase
   guidance; distinguish browser blocking from provider configuration failures.
3. Rebuild sign-in methods to the supplied phone/desktop hierarchy, retaining
   working provider operations, current connection state and last-method guards.
4. Establish one camera framing/crop transform: orientation-normalized source,
   aspect-preserving cover preview, matching capture crop, explicit front-camera
   mirroring, no stale capture after mode/lifecycle changes. Test synthetic edge
   markers, portrait/landscape, camera changes and resize before UI integration.
5. Rebuild Scan to the supplied references, larger preview and Front/Back/Barcode
   tabs (Barcode initially), existing navbar, captured-photo processing overlay,
   accessible loading/error/retry states and reduced motion.
6. Barcode decoding: evaluate maintained ZBar integration and license/runtime
   support across web/iOS/Android; compare controlled fixtures before claiming
   better accuracy. Keep checksum validation, bounded work and cancellation.
7. Front/back AI: front identifies name/brand/claims and searches the catalogue;
   ambiguous products and package sizes require explicit candidate selection.
   Back extracts printed ingredient/nutrition fields with identity references.
   Claims use supported database evidence; missing/conflicting is unknown.
8. Add a versioned AI-unverified contribution path. User explicitly removed the
   separate contribution confirmation step. Do not reuse or fabricate existing
   human-confirmed flags. Keep provenance, immutable source observations,
   identity matching, deduplication and conflict handling. Never silently replace
   sourced facts or turn machine output into an allergen/health verdict. Explain
   transfer/contribution in capture UI and terms.
9. Update docs/contracts/version, run affected and full checks, inspect actual
   PC/iPad/iPhone renders, then push and verify deployment/native feed separately.

## Research findings and constraints

- Safari screenshot reproduced by resizing from 390x664 to 390x640: the former
  `fullHeight < 650` branch changed the hero from 259 px to 76 px. This is a
  layout discontinuity, not an asset loading failure.
- First Chromium Google tap opened a popup with active user activation. Startup
  awaits may still affect Safari; no actual iPhone provider flow is proven.
- The previous public contribution API requires human-confirmation flags. This
  update adds an explicit separate machine-unverified contract; the app no longer
  converts model readings into human-confirmed input.
- NutriGraph public docs advertise a free tier, but its legal terms restrict
  retention beyond 24 hours and database enrichment without a separate license.
  It cannot currently supply Unlabel's reusable catalogue. The user subsequently
  requested live lookup instead: call from the backend for a scanned barcode or
  a selected name-search product with a barcode, cache at most 24 hours, show
  attribution and keep vendor data out of permanent saved/synced reports. Free
  tier is 1,000 calls per calendar month; 429/misses keep local results usable.
  Credentials remain server-only and no key has been supplied for live proof.
  Its documented lookup is UPC-12, not product-name search. EAN-13/India coverage
  remains unverified. The user sent the prepared trial email on 15 October; the reply and key are
  pending. No signup, payment, personalized tracking URL request or provider
  submission was performed by the assistant.
  Sources: <https://www.nutrigraphapi.com/docs.html> and
  <https://www.nutrigraphapi.com/legal.html>.
- ZBar's SourceForge page is old; maintained native upstream and any WASM build
  must be evaluated separately. The existing captured-photo decoder uses
  zxing_lib; a package change alone is not accuracy proof.

## Evidence so far

- Previous release is fully recorded in CONTROLLED_RELEASES.md and its receipts.
- Safari regression tests failed before the layout change and passed afterward.
  All 58 auth widget tests pass, including keyboard dismissal/restoration, large
  text, whole-card movement, desktop cards and both iPad orientations.
- Current source passes 495 Flutter tests including shared-header/art regressions,
  1,481 backend tests, clean analysis and a production web build.
  Current release reviews record the final rerun and publication evidence.
- Physical iPhone Safari, camera accuracy and provider consent remain separate
  acceptance checks. Do not label the remaining stages complete prematurely.
