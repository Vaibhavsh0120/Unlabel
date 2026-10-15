# Current components and remaining work

Current working release: **frontend 0.10.0+14 / backend 0.14.0**, dated
15 October 2026. The scanner/reference account update adds camera framing,
Barcode-first capture, AI front/back matches, automatic unverified observations,
optional live NutriGraph lookup and one ProductInfoPage. Its visual redesign is
explicitly reserved for the next update.
[Frontend review](FRONTEND_V0_10_0_REVIEW.md) · [Backend review](BACKEND_V0_14_0_REVIEW.md) ·
[Release ledger](CONTROLLED_RELEASES.md).

| Remaining gate | Owner/evidence needed |
| --- | --- |
| NutriGraph activation/coverage | User sent trial email; key and India/EAN-13 response pending. Keep disabled until configured |
| Product Info visual redesign | User explicitly deferred to the next update; one shared destination is implemented now |
| Physical barcode/OCR accuracy and shopping latency | Android/iPhone tests with dated package samples and measured results |
| LiveContainer import and execution | Actual iPhone/LiveContainer test of the published device IPA |
| Production Android signing | Stable private demo key is registered/restored/verified; production release signing remains separate |
| Supported reset/sign-in return | Local SDK requests use Firebase's reserved handler and fixed authorized Continue URL; SDK tests and synthetic no-email request passed; no real inbox delivery claim |
| Real Google/reset/profile acceptance | Actual provider consent, email delivery and device/cross-account flows beyond local tests |
| Hosted authenticated extraction/private staging | Separately authorized synthetic consent/authentication/write verification |
| Continuous camera recognition/highlights | Future implementation and device performance verification |
| Notifications/comparison-history totals | Future explicit feature scope |
| Personal suitability and broader ingredient/claim coverage | Reviewed evidence and separately scoped product work |

Existing reminders do not infer allergy safety; partial ingredient functions and
numeric claim checks do not form a universal health score. Source misses, unknowns
and conflicts remain visible. No custom training or billing/card requirement is
selected. Versions live in the canonical component metadata; dated reviews keep
their historical identities when a future release changes those versions.
