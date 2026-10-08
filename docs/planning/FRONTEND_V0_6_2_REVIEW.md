# Frontend v0.6.2+9: selected-only Profile summaries

Published correction, 8 October 2026. Implementation source `ed2b8ff6d6d1247b85b2445c0bbf6f4560e75137` is
pushed on main; v0.6.1 evidence stays historical.

The empty Preferences summary previously displayed Low sugar, High fibre and
Vegetarian as quick choices. It now shows only saved selections, matching the
existing empty-state message. Both food preferences and allergen reminders show
the first two selected labels in stable model order. Additional selections use a
`+N` chip: six selections display two labels and `+4`.

Selected chips, the overflow chip and each section heading open that group's
separate editor. The full eight preference and twelve allergen choices remain
available. Truncation affects rendering only; every saved choice is retained.
Save/Cancel, device-only storage and separation between the groups are unchanged.
The obsolete quick-toggle helper is removed. No backend, catalogue, keys, OCR,
artwork or camera behavior changes in this correction.

## Verification

The focused Profile/account suite passed **38 tests**. Five new regressions cover
empty, one, two and six selections; the six-selection fixture checks both groups
at 390 px dark and 1440 px light, correct overflow routing, checked hidden choices
and preservation of all saved values. Existing Save/Cancel, large-text reachability
and account/private-sync boundaries remain covered.

The full Flutter suite passed **237 tests**; analysis reported no issues and the
release web build passed. Independent source review found no actionable issues.
Browser screenshots at 390/1440/1728 confirm that empty summaries have no chips.
The two summary disclosure headings now have 48 px minimum tap targets after
measured review found the preceding 35 px targets too small. The all-selected
rendering and popup routing use synthetic widget fixtures; no personal reminder
selections were saved during browser review. Better Design UI/UX guidance and copy review are used;
comprehension passes. Geometry measurements do not certify canvas pixel equality.
Final Better Design measurement reports no findings in the two affected summary
heading controls at all three widths. [Render receipt](../research/FRONTEND_V0_6_2_RENDER.json).

## Production

Deployment `dpl_8bC1g9PYP64j1hsdvdZ69oFGKyJZ` is READY at
https://unlabel-india.vercel.app with **55 hosted checks**, all 21 pinned OCR
hashes and all 13 pinned artwork assets.
[Production receipt](../research/FRONTEND_V0_6_2_PRODUCTION.json).
The unchanged backend remains v0.12.0; its preceding production receipt is
retained independently. This frontend helper checks public backend compatibility
but does not rerun the preceding 389-check backend audit. Later documentation-only
closure commits preserve this implementation identity.

[Preceding frontend review](FRONTEND_V0_6_1_REVIEW.md) ·
[Backend review](BACKEND_V0_12_0_REVIEW.md).
