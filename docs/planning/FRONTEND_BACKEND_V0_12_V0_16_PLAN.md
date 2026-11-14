# Frontend 0.12.0+17 / backend 0.16.0 plan

Requested 14 November 2026. Work stays on main.

1. Audit all screen families and shared layout/interaction components. Retain
   forest/mint identity, navigation order, source/evidence boundaries and auth.
2. Raise the body/label type scale and weight, neutralize dark surfaces to
   charcoal, use restrained glass and lower the phone navigation within the safe
   area. Preserve 48px controls, enlarged text and reduced-motion behavior.
3. Redesign Profile identity, statistics, preferences and settings: full-width
   selectable email, readable labels, consistent card gutters and explicit sync.
4. Replace notification placeholders with a device-local persistent inbox for
   app updates and actual scan/save activity, plus opt-in daily native reminders.
   Add a public bounded backend announcement feed with no personal data, tokens,
   billing or background server infrastructure. Browser inbox works; native
   reminder permission is requested only on user action.
5. Verify meaningful notification failure/deduplication/persistence boundaries,
   responsive layouts and interactions. Render phone, both tablet orientations
   and laptop sizes in both themes; document physical-device limits separately.
6. Review changes for correctness, dead code and unnecessary rendering work;
   run Flutter, backend, scripts/contracts and repository checks. Update release
   evidence and documentation before committing and pushing main.

Design trade-off: readable text and dedicated identity/settings groups increase
vertical space on phones. Desktop uses available columns; no text is shrunk to
fit a metric tile. Repeated card blur is avoided to preserve scroll performance.
Better Design guidance was requested but blocked by the monthly service quota;
existing DESIGN.md, source checks and rendered evidence remain the basis.
