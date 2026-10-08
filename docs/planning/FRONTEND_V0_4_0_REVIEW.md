# Frontend v0.4.0+5 — Sourced Comparison and Ingredient Detail

Reviewed on `main`, **8 October 2026**. Uses the existing backend comparison
contract and six reviewed ingredient-function entries; preserves the Scan Label
layout and Home / Scan / Compare / Saved navigation.

## Delivered behavior

- Select original OFF snapshot, community revision or current confirmed label
  and its actual table. Amounts use a compatible 100 g/100 mL basis with original
  values, source references and unknown/conflict reasons retained.
- Validate all eleven ordered nutrient cells, exact source/table pins, echoed
  request/session/revision and bounded finite arithmetic. Read-only comparison
  uses no authentication callback and limits requests to 64 KiB.
- Current confirmation envelopes remain in bounded, namespace-specific session
  memory. History/private sync contain only the existing report contract. Restored
  current reports ask for label review again; removed records cannot regain
  confirmation. Selection, source, swap, namespace and disposal invalidate late
  results. Retry preserves selections.
- Expand matched ingredients inside the existing educational screen. The detail
  dialog includes English/Hindi functions, exact matched text, source title,
  copyable HTTPS URL and review date. Limited coverage and function-only scope
  remain explicit.
- Android camera initialization starts immediately after the first frame while
  interrupted-gallery recovery runs concurrently. Recovery previously blocked
  preview for up to five seconds. Revision guards prevent a recovered image from
  replacing a newer capture, gallery choice or manual-entry action. Resolution,
  capture quality and lifecycle serialization remain unchanged.

## Verification

Final full Flutter suite: **181 passed**. `flutter analyze` reported no issues.
Release web build passed, including its Wasm dry run. Independent review resolved
the stale basis label next to an exact-source selector and confirmed camera
lifecycle, namespace and late-response guards. A red/green UI regression verifies
the evidence URL/date addition; 29 focused comparison/data checks passed after it.

The release browser completed Welcome/Home, focused catalogue search/results,
dated report lookup, camera permission fallback, manual label entry/confirmation,
current reports, local save, ingredient matching/evidence and exact-source
comparison. Two synthetic labels with 8 g and 12 g protein per 100 g displayed
4 g more in B; Swap displayed 4 g more in A. Other cells remained unknown. Profile
showed the actual device history/saved counts. The synthetic backend disables
all community/account cloud writes and loads no credentials.

390/1440/1728 px light/dark screenshots were inspected; the 390 px ingredient
dialog retained its bilingual text, source URL/date and close action. Enlarged
text/overflow, retry and stale-response cases also pass rendered widget tests.
Better Design comprehension passed the initial, missing-confirmation and
ingredient-detail states. Geometry capture completed at all three widths: the
only six raw findings were Flutter's intentional 1 px off-screen screen-reader
announcers at -99999 px. Excluding those two nonvisual tags left 57 measured
shell/semantics elements per width and zero findings. Flutter canvas geometry
cannot prove the internal visual spacing; screenshots and widget checks supply
that separate evidence. Deployment evidence is recorded at closure.

The intermediate frontend Vercel build at backend commit `5ed899e` failed its
old one-match fixture expectation. This frontend slice carries the four-match
compatibility fix; the full 181-test suite and 12 final comparison tests pass.

[Implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md) ·
[Backend review](BACKEND_V0_9_0_REVIEW.md).

## Remaining physical/provider gates

No Android/iOS binary was built or installed during this software audit. Actual
camera opening time, permission UX, OCR accuracy and device performance require
a physical device. Automatic camera barcode detection, live highlights,
notifications and persistent comparison totals remain future scope. Existing
account/provider tests do not constitute a new live credentialed cloud-write
check. Source-release publication is tracked separately from push/deployment.
