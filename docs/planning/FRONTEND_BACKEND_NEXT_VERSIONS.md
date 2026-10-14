# Current components and remaining work

Checkpoint: **13 October 2026**. Canonical versions are in
[frontend pubspec](../../frontend/pubspec.yaml) and [backend pyproject](../../backend/pyproject.toml).
The frontend retains automatic reading, sourced reports/comparison, libraries and
twenty daily Insights, adding reference auth, linked Google/password methods,
private thumbnail editing, optional gender/default avatars and confirmed account
deletion. Backend adds recent-auth owner cleanup and permanent retry/admission
markers; existing public/library/AI payload contracts stay intact.

The user authorized these features and component bumps after the initial
maintenance and later authorized completion/push from main, superseding the hold.
Firebase's hosted handler completes reset with a fixed app sign-in return; the
app keeps four auth states. Login/signup share themed artwork and the supplied
desktop/phone composition. Local checks and final hosted/native acceptance stay
separate. [Audit](MAINTENANCE_2026_10_12.md) · [Release ledger](CONTROLLED_RELEASES.md) ·
[Frontend review](FRONTEND_V0_9_0_REVIEW.md) · [Backend review](BACKEND_V0_13_0_REVIEW.md).

| Remaining gate | Owner/evidence needed |
| --- | --- |
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
