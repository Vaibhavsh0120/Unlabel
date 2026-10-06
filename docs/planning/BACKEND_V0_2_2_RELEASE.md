# Backend v0.2.2 — hosted India catalogue

This backend-only release turns the committed India identity source into a validated deployment bundle. Each Vercel build generates SQLite and an integrity receipt; startup checks the bundle before enabling catalogue access. No database service, new API key or paid tier is required. Frontend remains **0.0.0+1**; existing APK/unsigned IPA assets are unchanged.

## Delivered

- Network-free source-to-SQLite build with strict metadata, byte/hash/count limits and receipt verification.
- `GET /v1/catalogue`: typed catalogue readiness, manifest, optional artifact hash/size, source age, refresh date and known field limits.
- Additive `/v1/meta.catalogue` metadata. Existing product, nutrition, confirmed-input and catalogue lookup schemas stay unchanged.
- Snapshot-only indexed lookup without an OFF request or implicit live fallback. Overdue/future source dates and unverified coverage remain explicit.
- Manual nine-calendar-month source replacement through a new Git deployment; rollback uses a previously verified deployment/source.
- Updated current OpenAPI/status schema, synthetic example, documentation and encrypted local settings.

The current bundle has **21,138 indexed barcodes**, generated from **21,188 India-tagged source rows**. Committed gzip: **840,099 bytes**; local SQLite: **11,993,088 bytes**. Source date **2026-10-05T12:19:34Z**; refresh due **2027-07-05T12:19:34Z**. Rebuilding does not reset that date.

## Boundaries and next version

Coverage is `unverified`; a dated live count of 24,715 differs from the export and the cause is unresolved. This is selected OFF data, not all products sold in India. Nutrition tables, photos and per-record modification dates are absent; canonical allergen tags are absent in this projection. Missing values do not imply zero, safety or compliance. Live product/nutrition routes remain available with independent OFF provenance.

AI, OCR, claim rules, scores, comparison and account/history APIs are future milestones. **v0.2.3** will investigate and implement a richer bulk source with nutrition and record-level provenance within measured storage/build budgets. No custom training is needed for v0.2.2. FSSAI source review/rules follow as a separate phase.

## Verification and release

Local suite: **297 passed**, including source/receipt tampering, refresh boundaries, unchanged contract and graceful failure regressions. Independent focused review: **65 passed**, no remaining actionable code findings. Both production deployments for implementation commit `2df4fb9` are READY. Build-time receipt and public startup-verified SQLite hash/size agree; status/count/date, found/404/422, existing live APIs/POST, CORS, OpenAPI and excluded URL paths passed. [Full v0.2.2 review](BACKEND_V0_2_2_REVIEW.md) · [Dated production report](../research/BACKEND_V0_2_2_PRODUCTION.json).

This is a source-only backend prerelease using tag `v0.2.2`. Mobile release workflow is not dispatched. Public services: [API status](https://unlabel-api.vercel.app/v1/catalogue), [API docs](https://unlabel-api.vercel.app/docs), [website](https://unlabel-india.vercel.app).
