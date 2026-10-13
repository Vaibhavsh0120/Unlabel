# Frontend 0.7.1+12 — UI and release maintenance

This patch improves image delivery and repairs navigation/layout without adding
new product features. Backend remains 0.12.0. The frontend version/build is changed
only in pubspec; runtime metadata and workflows derive it automatically.

- Home: larger daily Insight artwork, tighter spacing below dots and a
  shorter Recent scans empty state with fresh artwork and working actions.
  Daily tips rotate every three seconds with pause/resume and manual controls.
  Rotation pauses on interaction, scrolling, background/covered routes and
  reduced-motion or accessible-navigation settings.
- Insights: equal natural card heights, centered image/copy and bottom-aligned
  reading time. Remove the unrelated heading/footer leaves; keep each sourced
  article's own illustration and existing bookmarks.
- History, Saved, Sources and 404: distinct fresh illustrations and responsive
  layouts. Sources exposes six concise summaries; each card opens the full
  explanation and copyable link. Phone icons/art are larger, with no chevrons.
  Phone History/Saved artwork sits centered between the description and action.
  Source details use a centered desktop window or styled phone sheet, with
  readable sections, a scrollable body and an always-reachable close action.
- Desktop History/Sources switch inside the fixed shell; readers retain header/
  sidebar without whole-page transitions. Logos return Home and enlarge slightly
  on hover without a tooltip or layout shift. Phone navigation order is preserved.
- Missing links keep HTTP 404. A loading fallback lasts until Flutter's first
  frame, which already includes the desktop/mobile navigation shell. Recovery
  stays valid through delayed restore and account changes.
- Sized WebP, early browser fetches and bounded decoded-image warmup reduce late
  artwork appearance without blocking UI or fetching private/product photos.
  Four unused images are removed; licensed sources and historical tags remain.
- The prohibited leafy branch is removed from every caller and the bundle.
  Decorative motion pauses at its current pose while scrolling, avoids per-scroll
  visibility work, and resumes only when idle/visible with motion enabled.
- README banners/navigation, metadata, documentation links and release tooling
  repairs are included. Backend deployment recovery was a transient Git retrieval
  failure; backend runtime/configuration did not need a change.

Local checks and exact implementation, hosted and native publication identities
are recorded in the [maintenance receipt](../research/MAINTENANCE_2026_10_12.json).
The [audit](MAINTENANCE_2026_10_12.md) includes the preceding native build and feed
repair. A hosted check, verified IPA download and physical LiveContainer launch
remain distinct; physical iPhone import/launch is not established by these checks.
