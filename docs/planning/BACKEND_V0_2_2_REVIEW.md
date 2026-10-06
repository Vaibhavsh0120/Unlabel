# Backend v0.2.2 review

Checked **6 October 2026**. Backend becomes **0.2.2**; Flutter stays **0.0.0+1**. This record separates local verification from the production gate.

## Source, code and contract review

The committed 840,099-byte gzip matches its compressed and decoded SHA-256/length metadata. It retains 21,188 exact India-tagged rows; 21,138 supported unique barcodes are indexed, and 50 unsupported codes are counted. The generated SQLite is 11,993,088 bytes. Source export time is **2026-10-05T12:19:34Z**; the nine-calendar-month refresh date is **2027-07-05T12:19:34Z**.

A bounded live OFF count returned **24,715** on 6 October, compared with 24,706 in the earlier acquisition observation. That query and the export have different timestamps. The gap's cause is unresolved; the bundle's coverage stays `unverified`. Missing names: 3,442; missing ingredient text: 15,780. Canonical allergen tags are absent from this projection. Nutrition tables, photos and per-record modification dates are excluded. The [dated coverage report](../research/CATALOGUE_V0_2_2_COVERAGE.json) records the measurements and source/hash references. This is not every product sold in India.

An independent read-only code review found no remaining actionable issues. Two findings from the earlier review were corrected and covered by regressions: extreme timezone/date arithmetic becomes a controlled validation failure, and appended catalogue warnings retain the existing 100-item bound and undergo model validation. Tampered/missing receipts or databases disable catalogue access without disabling health or live APIs. Packaged runtime manifest replacement is rejected; refresh requires a new deployment.

The bundle builder validates gzip EOF/trailer, bytes/hashes, strict metadata, source/count expectations and generated SQLite integrity. It uses no network, env decryption or provider key. SQLite and receipt publication uses two file replacements in an unpublished build, not an atomic filesystem pair. A publication failure rejects the build. Runtime checks the SQLite hash once at startup; receipt metadata is an integrity record, not an OFF signature. Generated UUID/indexing timestamps can change bytes between builds while preserving verified source/counts.

## Local verification

| Check | Observed result |
| --- | --- |
| Backend suite | **297 passed**; one existing Starlette/HTTPX deprecation warning |
| Independent focused regressions | **65 passed** for bundle, status/date and API failure boundaries |
| Actual committed-source bundle | Built and verified; 21,138 indexed products, 11,993,088 bytes |
| Packaged runtime ASGI smoke | Status/meta ready, rice flour found, absent chocolate 404, invalid barcode 422; upstream forbidden in the test |
| Contracts | New seventh route `/v1/catalogue`; existing product/nutrition/catalogue lookup schemas unchanged |
| Local timing samples | Bundle verification 31.2 ms; 100 indexed reads, median 0.341 ms, maximum 0.550 ms |
| Static/dependency checks | Ruff lint passes for app/tests/build/scripts; format passes for 34 backend and 9 script files using their respective configurations; `pip check` clean |
| Encryption/recovery | Actual external-key restoration matches the updated local `.env` bytes; no plaintext/key content displayed |
| Tracked boundary | Plaintext `.env`, generated SQLite/receipt and runtime files are ignored; no private identity/PEM content found in tracked/new files |
| Documentation links before source push | 57 tracked Markdown files, 245 local targets, zero missing; staged whitespace review clean |

These timings are local samples, not a cloud/network latency guarantee. Documentation links are checked again after the final documentation edits, before pushing. The broader script lint found two existing path-bootstrap imports without an explicit exception; their `E402` annotations now document that intentional ordering without changing behavior.

## Documentation and recovery

Current READMEs, architecture/workflows, API/contract map, clone instructions, roadmap, hosting settings and release notes are updated for this scope. Earlier review/release files remain historical records. The source and licenses are tracked; generated SQLite/receipts remain ignored. The local non-secret application identity was updated and `.env.age` refreshed without printing plaintext or identities. No frontend code, mobile workflow, APK/IPA assets or historical tags are changed.

## Production verification

**Passed on 6 October 2026 at 12:19 UTC.** Source commit `2df4fb9be0d1cca4440ad659c677250dacd379e5` automatically produced READY production deployments for both projects:

- Backend: `dpl_898Km4txv66J7GA5bRTCFrPmrRrd`.
- Website: `dpl_8aTkrJancwVP4i9P22fEBx9b9drf`.

Backend build logs show Python 3.12 and `Executing: python build_catalogue.py`, followed by successful packaging/deployment. The emitted receipt and public startup-verified artifact match: database SHA-256 `b04504e8e6f5b71e45fcfff0ed9f5c5a1463d4ffa1899fb7aeee7edb13521c6f`, 11,993,088 bytes, snapshot `3c0cb046-3201-4cb7-8b3a-acb71118b624`, source SHA-256 `9930e846978729e7fcbb753b1ef6ad1df2da8fa84bfbc94b43e3463bccaf6cc2`. Status reports 21,138 indexed products, the original source date, `unverified` coverage and the unchanged July 2027 due date. Each later build has its own receipt/hash; these values describe this dated deployment.

Unauthenticated public HTTP checks passed: health/meta/status, found rice-flour catalogue record, absent chocolate 404, invalid code 422, OpenAPI equal to the current export, live product and direct nutrition lookups, synthetic confirmed-input POST, POST preflight, exact frontend CORS and rejection of an unrelated origin. Catalogue/product/nutrition/POST responses use `no-store`; health/meta retain their existing platform cache headers. Plaintext/ciphertext env and database/receipt URL paths returned 404. The website returned 200 with its Flutter bootstrap; frontend source/version remains unchanged. [Dated production evidence](../research/BACKEND_V0_2_2_PRODUCTION.json).

The first health probe took 0.8772 seconds and first catalogue lookup 0.5514 seconds from this machine. Five subsequent rice-flour round trips ranged from **0.2927 to 0.3274 seconds**, median **0.2997 seconds**. They include network/request overhead and do not establish platform cold-start timing, cache lifetime or an SLA.

Build failure preserves prior-deployment availability by the documented deployment strategy; an actual failed-production-build or rollback drill was not performed. Corruption/failure boundaries were tested locally. No AI, phone offline capability, native build, scanner or regulatory verdict is established. This review records the implementation commit; a later documentation-only push keeps the same application/source and is rechecked separately before tagging.

Production API: [unlabel-api.vercel.app](https://unlabel-api.vercel.app/v1/catalogue). Website: [unlabel-india.vercel.app](https://unlabel-india.vercel.app). See [release notes](BACKEND_V0_2_2_RELEASE.md) and [hosting configuration](VERCEL_SETUP.md).
