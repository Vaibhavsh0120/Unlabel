# India snapshot: measured storage and nine-month refresh

The current rich JSONL snapshot, unchanged in backend v0.5.0, has **24,641 supported records** and source **2026-10-06T06:53:46Z**, due **2027-07-06T06:53:46Z**. Its verified SQLite is **59.58 MiB**, not the smaller historical CSV index below. [Current rich-facts measurements](#current-rich-facts-snapshot-retained-by-v050) · [Current workflow](../architecture/CATALOGUE.md).

Historical CSV measurements below were updated 6 October 2026. The user changed the manual replacement policy from six to **nine calendar months**. v0.2.1 acquired the full official nightly global CSV stream and selected exact India country tags. Backend v0.2.2 adds a networkless tracked-source build, verified immutable SQLite/receipt and typed source-age status. [Acquisition history](INDIA_EXPORT_FEASIBILITY.md), [catalogue workflow](../architecture/CATALOGUE.md), [historical CSV coverage measurement](CATALOGUE_V0_2_2_COVERAGE.json) and [v0.2.2 release verification](../planning/BACKEND_V0_2_2_REVIEW.md).

## Historical v0.2.1/v0.2.2 CSV measurements

The compressed world source was 1,275,171,186 bytes. Streaming checked 4,535,553 rows without retaining the world file. The India identity projection is 6,588,910 bytes; the SQLite index is **11,993,088 bytes (11.44 MiB)**. It contains 21,138 supported barcode records out of 21,188 India-tagged rows; 50 unsupported codes are counted. Missing ingredients affect 74.65% of indexed products. No exact duplicates or leading-zero equivalence collisions were found.

This is every matching row in this particular export, not every product sold in India. Initial live search reported 24,706 matches; the bounded v0.2.2 follow-up on 6 October counted 24,715, a 3,527-row gap from the export. The discrepancy remains unexplained. Global exports can include obsolete records and source timestamps differ. Coverage stays `unverified`; a live-found chocolate sample is absent from the snapshot. The selected identity dataset excludes aggregate nutrition, images and record modification dates. Canonical allergen data is unknown when its exact export column is absent.

## Placement comparison

The identity projection is now retained in Git as an 840,099-byte gzip with hashes, provenance and licenses. [Setup](../planning/LOCAL_DEVELOPMENT.md) rebuilds ignored SQLite from this [bundle](../../data/catalogue/README.md). The separate hosted build generates its own ignored SQLite/receipt under `backend/app/catalogue/data/`; deployment verification is recorded in the current review. Neither rebuild path implements frontend offline support.

| Placement | Benefit | Cost or limitation |
| --- | --- | --- |
| India identity database in app | Indexed lookup without a backend connection | The measured file adds about 11.44 MiB before packaging; richer nutrition/images add unmeasured size. Every device needs updates and a database reader. |
| SQLite catalogue on backend | Small client, central updates, indexed barcode reads without OFF per cached identity request | Requires verified file packaging/distribution and backend connectivity. Not a durable writable serverless database. |
| Backend plus small client cache | Central source with offline saved/recent products | Frontend cache limits/eviction/freshness still need implementation. |

The measured identity database is not intrinsically too large to bundle in an app. Size alone does not justify a full offline conclusion: nutrition/source richness, missing fields, runtime support and nine-month device updates also matter. Retain the chosen online-first backend with a future small client cache; the teammate can evaluate offline catalogue download later. No corpus is bundled into Flutter now.

CSV/JSONL are acquisition formats; **SQLite is selected for serving**. Firestore adds shared cloud document operations and finite quotas without improving this read-only snapshot's core requirement. [Storage comparison](../architecture/CATALOGUE.md).

## Bounded storage

Acquisition retains only an India projection, with 100 MiB output, 2 GiB compressed-transfer and 32 GiB decoded-stream caps. The importer defaults to a 100 MiB SQLite artifact and 1 GiB immediate work-directory file budget. Current projection plus index occupy about 17.72 MiB locally; a new projection/index and deliberate short rollback copy fit well within that budget. These are operation-directory bounds, not a recursive quota over all user files. Keep source/rollback files in known owned directories and check free disk before refreshing. No images are downloaded.

Ignored local runtime data does not reach Vercel through Git. v0.2.2 instead builds the tracked 840,099-byte source into a generated immutable database/receipt. The documented standard Python function bundle limit is 500 MB uncompressed including dependencies; eligibility for larger beta bundles is separate. A measured local index and successful build validation do not establish live cloud reads; the current review records that separate deployment gate. [Vercel Python runtime](https://vercel.com/docs/functions/runtimes/python).

## Nine-month replacement procedure

1. Use a fresh source directory and keep the active catalogue serving. Stream the documented official export, verifying header/dialect, full EOF, byte count and checksums. Do not scrape per barcode or retain the world dump.
2. Compare country/index counts, unsupported/duplicate codes, dates and field gaps with the active manifest. Review a large unexplained reduction before promotion. Preserve source attribution/licenses and keep private scans/regulatory findings separate.
3. Keep a deliberate short local rollback copy if needed. Validate a staging index, manifest, count and representative products with exclusive import and finite storage bounds. Update the tracked gzip, metadata, provenance, notices and docs together. A failed local import preserves the active local database; crash/busy locks require operator review.
4. Push the reviewed source to create a new immutable hosted deployment. The build generates and verifies SQLite/receipt before success; publication of those two files is not an atomic filesystem pair. Do not promote a failed build or hot-swap packaged runtime files.
5. Check the exact production commit, source/hash/count, source-age status and found/absent lookups. Roll back through the prior validated deployment and matching source/configuration when needed. Clean only identified owned local artifacts after success; Git still retains historical source versions.

The historical CSV source timestamp is **2026-10-05T12:19:34Z**; nine calendar months sets the due boundary to **2027-07-05T12:19:34Z**. Freshness uses this source time rather than a new indexing/deployment time; future source dates are flagged with unknown age. This is a documented operating policy, not a scheduled job. Preserve data age between updates and keep live lookup available separately. Confirmed package fields take priority for current ingredients/allergens. Reviewed FSSAI evidence needs its own effective-date checks whenever rules change, independently of product-data cadence.

Retain OFF attribution and applicable ODbL/DbCL/share-alike requirements. Private scans and reviewed regulatory findings are separate; no contribution upload is implemented. [OFF cache guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/creating-a-local-cache-of-open-food-facts-data/) and [license guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/).

## Current rich-facts snapshot retained by v0.5.0

The separately released v0.2.3 JSONL acquisition reached validated full gzip EOF: 13,084,464,175 compressed bytes, 83,007,975,584 decoded bytes, 4,795,607 source rows, 24,695 India rows and 24,641 supported unique indexed records. The tracked gzip is 2,098,225 bytes, decoding to 15,084,130 bytes. The rich-facts SQLite is 62,472,192 bytes (59.58 MiB), within the configured 100 MiB artifact budget. Source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. These current values supersede the historical CSV sizes/date above. [Full current-source measurements](CATALOGUE_V0_2_3_COVERAGE.json) · [Independently verified v0.2.3 hosted proof](BACKEND_V0_2_3_PRODUCTION.json).

All 24,641 facts validate; 4,657 records have direct packaging/manufacturer tables and only 4,519 have reported nutrient values. Legacy aggregate, missing and invalid nutrition remain explicit. 18,682 records have attributed official image descriptors; no image bytes are bundled. Exact identity keys preserve leading zeros; image paths use OFF canonical normalization. The JSONL acquisition has separate finite transfer/decoded/work/output budgets documented in its script and source review; the smaller historical CSV acquisition caps above do not describe the rich JSONL operation. Coverage remains unverified. Backend v0.5.0 retains this source and the separate confirmed-label numerical claim bundle unchanged, without automatically treating snapshot rows as current-package evidence. [Current workflow](../architecture/CATALOGUE.md) · [current v0.5.0 gates](../planning/BACKEND_V0_5_0_REVIEW.md).
