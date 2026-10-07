# Frontend v0.3.0 rendered checks

8 October 2026. Local compiled release web preview, light mode. Welcome and
Profile were visually inspected at **390×844, 1440×900 and 1728×972** against the
user's botanical white/forest/mint references. Files are actual Flutter captures;
the references' fake OS status bars/window buttons are not rendered in the app.
Phone Welcome stacks the hero/copy/actions; desktop uses constrained columns.
Profile uses the real guest identity and counts, with the supplied reference's
body hierarchy. Its gear, bottom guest action and reference navbar are excluded
according to later user corrections. Existing navbar/Scan design is preserved.

- `welcome-light-390.jpg`, `welcome-light-1440.jpg`, `welcome-light-1728.jpg`
- `profile-light-390.jpg`, `profile-light-1440.jpg`, `profile-light-1728.jpg`
- `startup-app-light-390.png`: native startup widget rendered at 390×844, 2× image
  resolution, with bundled Cormorant Garamond and the SDK's Roboto loaded in the
  Flutter test renderer. This is a widget composition capture, not a device
  launch screenshot. The web app never routes to this screen.

Actual guest Profile opens editable allergen preferences, privacy information and
Help/About. Tests separately cover signed-in editing, sync/conflict/clear/logout,
theme persistence and device-local preferences. Notifications visibly state
`Not available yet`; comparison totals remain unavailable instead of invented.

Better Design spacing inspection records browser host and accessibility bounds
at the three widths. Flutter paints its cards into a canvas, so those DOM bounds
do not establish individual painted-card padding. The spacing inspection
reports six overflow findings for Flutter's intentionally offscreen 1px live
announcement nodes and eighteen moderate findings for compact control semantics
bounds across the three widths. These are retained as measurements, not treated
as visible page overflow or proof of full Flutter hit regions. The comprehension
heuristic passes the Profile primary identity/action copy and flags the reference's exact
`Get started` label as generic; that wording is intentionally retained from the
user's required Welcome reference, with its action verified in the app.

These captures establish layout review, not identical pixels across browsers,
physical keyboard/camera/OCR accuracy, frame-rate benchmarks or native installs.
Generated artwork prompts/hashes are in the
[artwork provenance](../../../frontend/assets/artwork/README.md).

## Hosted browser checkpoint

Published frontend implementation `3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`,
READY deployment `dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, was exercised in the browser.
Welcome Get started opened Home. Search focused an actual input and returned ten
results from 57 matches. A public barcode report opened and saved locally; returning
to Profile showed Scans 1 / Saved 1 with Comparisons unknown and no SnackBar Hero failure.

Hosted captures are `search-hosted-light-390.jpg` and
`profile-hosted-light-390.jpg`, both with document viewport verified as 390×844.
`welcome-hosted-light-1280.jpg` uses 1280×720; it is a separate desktop capture,
not the 390px local reference comparison. The [production receipt](../FRONTEND_V0_3_0_PRODUCTION.json)
records 49 public asset/API checks, all 21 OCR hashes and exact backend v0.7.0 compatibility.
Browser interaction evidence supplements those HTTP checks; physical mobile
keyboard and hosted OCR recognition are not established by this checkpoint.
