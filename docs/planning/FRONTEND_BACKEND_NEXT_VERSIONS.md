# Current components and remaining work

Current source: **frontend 0.11.0+15 / backend 0.15.0**.
The free native/WASM scanner, compact reference product page, optional sources
and guest sign-in-methods toast are implemented and deployed. Local/release
evidence belongs to the current reviews.
[Frontend review](FRONTEND_V0_11_0_REVIEW.md) · [Backend review](BACKEND_V0_15_0_REVIEW.md) ·
[Source setup](../architecture/OPTIONAL_SOURCES.md) · [Release ledger](CONTROLLED_RELEASES.md).

| Remaining gate | Owner/evidence needed |
| --- | --- |
| NutriGraph live endpoint/coverage | Key and encrypted environment configured; supplied endpoint returns HTML 404, so vendor availability and India coverage remain unverified |
| Physical barcode/OCR accuracy and shopping latency | Android/iPhone tests with dated package samples and measured results |
| LiveContainer import and execution | Actual iPhone/LiveContainer test of the published device IPA |
| Production Android signing | Stable private demo key is registered/restored/verified; production release signing remains separate |
| Supported reset/sign-in return | Local SDK requests use Firebase's reserved handler and fixed authorized Continue URL; SDK tests and synthetic no-email request passed; no real inbox delivery claim |
| Real Google/reset/profile acceptance | Actual provider consent, email delivery and device/cross-account flows beyond local tests |
| Hosted authenticated extraction/private staging | Separately authorized synthetic consent/authentication/write verification |
| Real camera recognition accuracy | Free SDK realtime scanning implemented; synthetic browser proof is separate from physical package tests |
| Notifications/comparison-history totals | Future explicit feature scope |
| Personal suitability and broader ingredient/claim coverage | Reviewed evidence and separately scoped product work |

Existing reminders do not infer allergy safety; partial ingredient functions and
numeric claim checks do not form a universal health score. Source misses, unknowns
and conflicts remain visible. No custom training or billing/card requirement is
selected. Versions live in the canonical component metadata; dated reviews keep
their historical identities when a future release changes those versions.
