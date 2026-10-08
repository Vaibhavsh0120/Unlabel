# Frontend v0.6.1+8: Home, Profile and draggable navigation

Local reviewed correction, 8 October 2026. Source is not yet pushed. It follows
the user's new production screenshots after the v0.6.0 deployment.

## Changed behavior and composition

- Sidebar navigation and its footer share a constrained scroll area. All six
  destinations fit a 730 px desktop window; shorter windows and enlarged text
  retain scroll access. The pale mint leaves are a non-interactive background
  layer behind navigation, never an overlay over links.
- A newly generated 3:1 insight banner replaces the oversized tightly cropped
  bowl. Its rim and food stay near the top of the image so the wide card retains
  a clear bowl at desktop sizes. Copy receives 70% of the card width; mobile
  illustrations also use a smaller reserved slot. Existing tips/actions remain.
- Mobile recent scans has a compact empty state with a small mint scan badge,
  one short line and a working Start Scan action. Desktop artwork is smaller and
  the message/actions are grouped together.
- Preferences and Allergens open separate white editors. Eight food preferences
  and twelve allergen reminders are selectable, with visible selected counts and
  chips. Each editor preserves the other group's choices. Save/Cancel stay
  outside the scrolling body; enlarged text uses fewer columns.
- Preferences remain device-local reminders. Cancel discards the draft, backdrop
  clicks preserve unsaved work, and Save retains the existing persistence path.
  Nothing becomes a food-safety or dietary-suitability verdict or cloud profile.
- The mobile green pill follows either a hold-and-slide or a direct horizontal
  drag beginning on the active tab. Candidate highlighting follows the finger;
  icons stay in their tab positions. Release selects one destination and the
  pill settles there. Pointer cancellation/lifecycle changes restore the current
  tab. Other tabs remain tappable, and RTL/reduced-motion behavior is preserved.

Each editor keeps its own choices together; mobile users scroll with actions
retained. Existing device-local selections survive the schema upgrade. The
sidebar reserves less room for decoration in shorter windows to prioritize links.

## Verification

The frozen-source full Flutter suite passed **232 tests**. Analysis reported no
issues and the release web build passed. Live local browser drag moved Home to
Compare and back to Home without changing the four-tab order.
Four sidebar regressions check short/tall desktop navigation and 2x text; six
editor tests cover all choices, Save/Cancel and backdrop preservation. Seven
device-model tests include old-format reads, strict new-format writes and
opposite-group preservation. Seven recent-scans tests check compact layout and
working actions. Five new navbar regressions check continuous direct drag,
cancellation, bounds, active-pill starts and RTL, alongside existing hold tests.
OCR bridge tests and backend validation belong to the unchanged base release.

Before/after Home and separate Profile editor review and visible Flutter
semantics are recorded in the [render receipt](../research/FRONTEND_V0_6_1_RENDER.json).
Canvas card/image styling is reviewed through screenshots; semantic geometry is
not CSS/pixel equality. Better Design principles, review and comprehension are
guidance/evidence, not dashboard visual approval.

Better Design spacing measurement completed at 390/1440/1728 with no findings
in the measured control subset. Its text heuristic initially treated the four
persistent tab destinations as competing page CTAs. They are the user's explicit
navigation contract, so labels were retained; the tab-label/hint comprehension
check passes with this context. Both separate editor copy checks also pass.

Hosted asset verification will be added after the exact deployment is READY.
Physical camera, recognition accuracy and the 3–5 second workflow remain unproven.
The 243-observation catalogue and 120/243 researched images are unchanged.

[Base frontend review](FRONTEND_V0_6_0_REVIEW.md) ·
[Backend review](BACKEND_V0_12_0_REVIEW.md) ·
[Artwork record](../../frontend/assets/artwork/README.md).
