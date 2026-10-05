# Backend v0.1.0

Unlabel now has a public FastAPI product lookup service. A barcode returns normalized Open Food Facts identity, ingredients, allergen/trace tags and available Nutri-Score/NOVA insights, with source dates, attribution, licenses and explicit unknown/failure states.

**Frontend remains v0.0.0+1.** Its starter is hosted with a pinned Flutter release web build; no frontend feature code, mobile workflow or existing APK/IPA artifact changed.

| Link | Address |
| --- | --- |
| Website | https://unlabel-india.vercel.app |
| Backend metadata | https://unlabel-api.vercel.app/v1/meta |
| API documentation | https://unlabel-api.vercel.app/docs |

Implemented endpoints: `GET /v1/health`, `GET /v1/meta`, `GET /v1/products/{barcode}`. OFF reads need no key; Gemini is disabled. Exact-origin CORS, total lookup timeout, response bounds and barcode identity checks protect the adapter's contract.

Validation: **33 backend tests passed**, Ruff lint/format and dependency checks passed, shared schemas match runtime exports, and synthetic examples validate. A peer review found malformed Unicode serialization and the fix has passing regression cases. The test client emits one recorded HTTPX deprecation warning.

Both Vercel projects automatically deployed the source push to READY. Public endpoint, schema, CORS/preflight, invalid-input and one live OFF lookup checks passed without a Vercel bypass token. The Flutter starter rendered in Chrome. [Full verification](BACKEND_V0_1_0_REVIEW.md) and [deployment settings](VERCEL_SETUP.md).

This version does not perform nutrition normalization, FSSAI claim checks, OCR, ingredient explanations, comparison, AI or India-wide database import. OFF records are community facts, not confirmation of current packaging, allergy safety or legal compliance. Full offline lookup and new-product analysis are not available in the starter.

Next versions are kept separate: v0.2.0 nutrition/input normalization, followed by the v0.2.1 India snapshot milestone. The proposed snapshot refresh is a manual validated replacement every six months, with measured storage limits and a small client cache; no dataset was downloaded or import scheduled.

[Version plan](../superpowers/plans/2026-10-05-backend-versions.md) · [API contract](../../contracts/README.md) · [Backend run guide](../../backend/README.md)
