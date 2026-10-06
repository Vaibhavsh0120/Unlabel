# Backend v0.2.3 review

Review updated: **7 October 2026 (Asia/Calcutta)**; acquisition/source timestamps below use UTC. Backend source becomes **0.2.3**; Flutter stays **0.0.0+1**. This record separates code/contract checks, complete source acquisition, local artifacts, hosted reads and publication. A preceding deployment or READY build does not verify this version.

## Source acquisition and measured coverage

The complete official `https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz` was acquired on 6 October, resolving only to the approved OFF S3 export. Acquisition ran from **17:04:05 to 18:15:39 UTC**, processed the complete compressed transfer and verified gzip EOF. The global dump was never retained; only a bounded India projection was produced. Source export time is **2026-10-06T06:53:46Z**. This establishes complete processing of that dated export, not all products sold in India.

| Measurement | Verified v0.2.3 result |
| --- | --- |
| Source transfer | **13,084,464,175 compressed bytes**, validated EOF; source SHA-256 below |
| Decoded global source | **83,007,975,584 bytes**, **4,795,607 records** |
| Exact `en:india` selection | **24,695 rows** |
| Supported unique/unsupported/duplicate codes | **24,641 / 54 / 0**; all supported records passed strict facts validation |
| Compact projected gzip | **2,098,225 bytes**; compressed SHA-256 below |
| Decoded India projection | **15,084,130 bytes**; decoded SHA-256 below |
| Source-derived refresh date | **2027-07-06T06:53:46Z**, nine calendar months from export |
| Strict facts and local artifact | **24,641** validated fact records; **62,472,192-byte SQLite**, verified local receipt |
| Current live India count | Not measured for v0.2.3; no current-count or complete-market assertion. Coverage stays `unverified` |

Artifact hashes identify different bytes:

- Original full compressed source: `26d5bb5538838f531e406fe73e9070a502bc2070e5bc0a9bda60869bd091d693`.
- Compact compressed projection: `bbdd13097ede75777b2356e27910ae01aff38d7ad0c59598af6868dcf447db24`.
- Decoded India projection/import source: `e508b33d8bf3694d11d052ad4ad70895b254527e0556937e9d2454a8b665818f`.

Acquisition observed these **raw projected-field gaps across all 24,695 India rows**, before strict facts validation: **3,565** missing names, **18,129** missing ingredient text, **634** missing canonical allergen-tag fields, **0** missing modification-time fields, **19,587** rows without direct nutrition input sets, and **5,970** without selected-front image metadata. **15,882** rows had legacy nutrition presence. These counters overlap and do not measure accepted direct tables, validated dates, valid image descriptors or allergen safety. The strict indexed-fact measurements below use supported records only and are separate from these raw counters.

India raw provider schema distribution: **1001: 1,140; 1002: 8,156; 1003: 2,480; 1004: 6,673; missing: 6,246**. Mixed schemas reinforce the direct-table-only boundary; legacy aggregate values are not converted into confirmed label evidence. Validated fact/store coverage is reported separately from raw field presence.

The preceding CSV bundle's 21,138 indexed barcodes and 11,993,088-byte SQLite belong to [v0.2.2](BACKEND_V0_2_2_REVIEW.md). They must not be copied as v0.2.3 JSONL measurements. Missing facts, legacy nutrient aggregates and canonical tag absence remain visible; no measured field rate proves every current package matches OFF or establishes allergy safety.

## Strict indexed facts and local build

All **24,641 supported identity/facts pairs** passed row-by-row strict model validation and identity-key/count checks. The [dated coverage report](../research/CATALOGUE_V0_2_3_COVERAGE.json) records the actual replacement bundle, measurements and local receipt.

| Validated fact state | Indexed records |
| --- | --- |
| Direct nutrition tables | **4,657**; **4,519** have at least one reported direct nutrient value |
| Legacy nutrition unsupported | **15,486** |
| Nutrition missing / invalid | **4,050 / 448** |
| Official selected-front image descriptor / missing | **18,682 / 5,959**; remote image availability is a separate check |
| Record modification date | **24,641** |
| Provider schema available / missing | **18,419 / 6,222** |
| Canonical allergen tags available / missing | **24,012 / 629** |
| Canonical trace tags available / missing | **24,012 / 629** |
| Category tags available / missing | **13,116 / 11,525** |
| Label tags available / missing | **9,301 / 15,340** |

Available tags may be empty and never establish allergy safety. Accepted direct tables do not mean all nutrient cells are known; legacy/missing/invalid states remain explicit. The four nutrition-state counts sum to the indexed record total.

The network-free source build generated and verified **62,472,192 bytes (59.58 MiB)** of SQLite. Its dated **local** receipt records database SHA-256 `4f13925ca5566d554765e4e709713931702f257446601e6d7cc964082a67ba89`, snapshot `bf066c69-e7d1-4308-b94d-f2223329112a`, 24,641 indexed records and the decoded source hash above. Builds have their own UUID/indexing timestamp and artifact hash; do not copy this local hash as hosted proof. No rule/source corpus is involved in these product facts.

## Code and contracts

`GET /v1/catalogue/products/{barcode}/facts` uses a separate strict response and the exact snapshot manifest. Category/label/allergen/trace fields expose `available`, `missing` or `invalid`; available empty tags are not safety evidence. Optional schema/modification fields are bounded. The shared direct-table parser accepts only packaging/manufacturer values with supported bases/preparation and preserves rows, origins, conflicts and unknowns. Legacy aggregates stay `legacy_unsupported`.

Selected-image URLs are constructed from validated official selected-image language/revision/400-size metadata using OFF's canonical normalized image disk path. Exact catalogue identity remains the requested key, including leading zeros. Arbitrary source URLs, image proxies and image bytes are excluded. Image attribution and CC-BY-SA metadata remain separate from ODbL/DbCL database attribution.

Generated SQLite stores a bounded optional facts table with identity-key/count validation. An older identity-only store preserves existing identity reads and reports facts unavailable. Snapshot misses make no upstream call. `catalogue_facts` requires a validated facts-enabled store; claim and analysis capabilities remain false. Existing strict contracts and historical OpenAPI files are preserved.

## Local validation

| Gate | Result |
| --- | --- |
| Backend suite and meaningful importer/body/secret/process regressions | **402 passed** for the v0.2.3 scope; future claim tests are excluded from this release count |
| Independent code/contract and dead-code review | No actionable correctness/security findings and no demonstrably dead v0.2.3 code; **103 scoped reviewer tests** and Ruff pass |
| Full source acquisition and boundaries | Complete compressed transfer/gzip EOF verified; v0.2.3 suite includes acquisition truncation, bounds and malformed-row regressions |
| Optional facts, legacy nutrition, direct-table conflicts, tags/dates/images | Passed in the scoped suite; all 24,641 supported records separately validated |
| Existing identity/nutrition/normalization/status contracts | Current export/regression tests pass; separate facts route preserves earlier strict schemas |
| Actual source-to-SQLite build and receipt | Built and verified 62,472,192-byte SQLite with the local receipt recorded above |
| Setup restore and packaged sample reads | Actual `scripts/setup.py --catalogue-only --replace-catalogue` restored 24,641 products; three packaged facts reads passed with upstream transport forbidden |
| Selected-image remote check | [Dated HEAD checks](../research/CATALOGUE_V0_2_3_IMAGE_CHECK.json) returned 200 `image/jpeg` for two sampled canonical URLs; remaining images were not individually requested |
| Ruff/format/dependencies | Scoped lint/format pass for **39 files**; `pip check` clean |
| Encryption and tracked-secret boundary | Public `OFF_USER_AGENT` advanced to 0.2.3 and `.env.age` refreshed successfully. Actual AGE/PEM private-key marker scan: **zero**; plaintext env and generated SQLite remain ignored. Env-tool boundary regressions pass in the 402-test suite |
| Actual private-key decrypt/recovery | **Not rerun in this continuation**; do not infer successful current restoration from encryption or regression tests |
| Current Markdown links and whitespace | Final repository-wide scan: **61 Markdown files**, **306 local targets**, zero missing links or UTF-8 replacement characters; whitespace check clean |

Synthetic fixtures verify contract behavior; actual dataset/build tests verify this candidate's source. Neither establishes production reads, native integration, OCR, scores, compliance certification or offline phone behavior.

## Documentation and deployment

Current READMEs, architecture, API/contracts, local setup, handoff, source workflow and roadmap describe this version. Earlier release/review records stay unchanged. Acquired public source/provenance/licenses are tracked; SQLite, receipts, environments, builds, private keys and plaintext `.env` stay generated/ignored. The 20-group tracker records remaining frontend integration and later backend slices independently.

## Production verification

**Passed on 7 October 2026 at approximately 00:02 IST** (dated report starts **2026-10-06T18:32:43Z**). Implementation commit `56064d7fd13d585c949eb2d31a53eb3884a5d520` was pushed independently and produced READY deployments for both Git-connected projects:

| Project | Deployment | Exact deployment URL |
| --- | --- | --- |
| Backend | `dpl_HgRKWoonZJSoGRr1ZaoHDwThSbrF` | [Verified backend deployment](https://unlabel-backend-1faupv40e-vaibhav0120s-projects.vercel.app) |
| Frontend | `dpl_64ccpc7XUCW8CkCEpChAk1SR1kSe` | [Verified starter deployment](https://unlabel-frontend-4ccggui6m-vaibhav0120s-projects.vercel.app) |

The actual Vercel build log receipt agrees with public startup-verified artifact metadata: **62,472,192 bytes**, database SHA-256 `fb194302905d55d182572988d894ca86d5653d6b9c623c880d99325ecafea165`, snapshot `eea89670-b5e7-4980-b49c-d5e49eaebdb1`. Source compressed/decoded hashes, 24,695 India rows, 24,641 indexed records, 54 unsupported codes, source timestamp and July 2027 due date agree with the tracked bundle. The hosted hash differs from the local build as expected; each build has its own snapshot/index timestamp.

All **20 dated public HTTP checks** passed: health/meta/catalogue status, current OpenAPI agreement, rich and sparse facts plus preserved identity reads for `00024907`, `0070970474088` and `8904083506393`, snapshot miss 404, redacted invalid input 422, confirmed normalization, exact-origin CORS/preflight, unrelated-origin denial and excluded env/database/receipt URLs. `/v1/claims/rules` returned 404 and claim capability remains false for this version. The website returned 200 with its Flutter bootstrap; frontend remains **0.0.0+1**. Facts/status/identity/normalization responses retain `no-store`. [Dated production checks and build receipt](../research/BACKEND_V0_2_3_PRODUCTION.json).

These checks prove this implementation's packaged catalogue reads and source integrity. Two separate [sample image HEAD checks](../research/CATALOGUE_V0_2_3_IMAGE_CHECK.json) returned 200 `image/jpeg`; other image URLs were not individually fetched. This does not establish complete market coverage, every image's availability, fresh physical-package agreement, scanner/OCR integration, native/offline behavior or regulatory findings. No failed-production-build or rollback drill was performed.

**Source-only tag published.** `v0.2.3` points to tested implementation `56064d7fd13d585c949eb2d31a53eb3884a5d520`. The independent implementation push and production gate are complete. Keep Flutter **0.0.0+1**, existing APK/IPA assets and historical tags unchanged. The [GitHub source-only prerelease](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.3) is published with zero binary assets. [Release notes](BACKEND_V0_2_3_RELEASE.md) · [Accepted plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md).

Final script review found and fixed setup reuse of a same-source JSONL identity-only database. Default setup preserves that valid legacy store; `--replace-catalogue` now rebuilds its facts table. Intact JSONL facts stores and CSV identity stores still reuse. The CSV acquisition identity was refreshed, and both acquisition network mocks assert the current backend application identity. Final scoped suite: **402 passed**, including migration/reuse regressions.

Publication verified: [v0.2.3 source-only prerelease](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.3), tag56064d7, published with zero assets.

Final pre-push semantic review covered all 61 Markdown files and operational scripts/workflows. Corrected stale current pointers/counts, preserved historical evidence, and checked 306 local Markdown targets with zero missing links or encoding defects. The final publication instruction was replaced by verified release evidence.
