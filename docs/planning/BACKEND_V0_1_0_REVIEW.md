# Backend v0.1.0 validation and handoff

Date: 5 October 2026. Scope: FastAPI service metadata and live normalized OFF barcode lookup, plus subsequently authorized Vercel backend/web hosting setup. Frontend source/version remains v0.0.0+1; only frontend hosting config/build script/docs change, with no APK/IPA rebuild or mobile workflow change. [Production domains and settings](VERCEL_SETUP.md).

## Verified

- 33 pytest cases passed: product/sparse normalization, source/unknown handling, optional malformed values/Unicode serialization, leading-zero identity, missing/mismatched records, timeout/HTTP failures, redirects, malformed/oversized responses, input rejection, exact-origin CORS/invalid ports/whitespace, service metadata and versions.
- Ruff lint and formatting checks passed; `pip check` reported no broken requirements.
- A local ASGI smoke returned 200 for health/meta. One live OFF v3.6 lookup through the application returned 200/found for public example barcode `3017620422003` (Nutella); this is connectivity evidence, not an Indian-market coverage or food-quality test.
- A local Uvicorn TCP HTTP smoke returned health/meta/OpenAPI 200 and invalid input 422. Exported OpenAPI and product schema exactly match the running models; the synthetic example validates. Thirty documentation files have no broken relative file links. The Vercel JSON files parse and the Bash web-build script passes syntax checking.
- Local `.env` and `.venv` are ignored; no API key is needed or populated. AI remains disabled. Raw provider internals and arbitrary returned identities are excluded by the adapter.

The installed Starlette test client emits one deprecation warning for HTTPX 0.x. Tests pass; the warning is recorded rather than suppressed. A later dependency update should migrate test transport when necessary and rerun the contract suite.

A read-only peer source review found malformed provider Unicode causing a response serialization error. Two failing regression cases reproduced it; the adapter now marks invalid text/tags as unknown with warnings, and both pass. Unsupported text never becomes an allergen-free finding.

Vercel project roots, framework/build settings, preview-only protection, exact public CORS and verified free domains are configured. Push `0c10e0b807948d70d3327517387f1db8cddc52c7` automatically deployed both projects to production and both reached READY. Public health/meta/OpenAPI returned 200, the live schema matched the exported contract, invalid input returned 422, exact-origin CORS/preflight passed and an unrelated origin received no CORS permission. One live OFF product lookup returned 200/found in a 0.91-second sample; this is not a general performance benchmark.

The website returned HTML/release JavaScript 200 and rendered the existing Flutter starter in Chrome. Unpublished `.env`/Dart source and missing assets returned 404. Build defines are supplied but currently unconsumed `BuildInfo` constants can be tree-shaken; no app-to-API user flow has been implemented or verified. Tests used ordinary public HTTP, without Vercel authentication cookies/bypass. APK/IPA artifacts were not rebuilt.

## Limits and next version

No nutrition basis conversion, FSSAI thresholds, all-product search, ingredient glossary, health score, Gemini, product comparison, frontend camera or provider-cache behavior is implemented. Invalid input is 422; lookup missing/rate-limit/unavailable/incompatible states have documented HTTP codes and no manufactured facts. Runtime health does not ping OFF or promise its availability.

India-wide bulk export/indexing remains a separate version after measuring source availability/size and hosting fit. User preference is a manual six-month refresh with storage budgets; no multi-GB download or scheduled automation was performed. The record-only product source is not proof of allergy safety or current legal compliance.

Before the next push, update the version plan, API examples and this version's successor review. Next planned implementation is v0.2.0 nutrition normalization; the separate v0.2.1 data milestone addresses the India snapshot. Backend tags/releases are independent of frontend releases.
