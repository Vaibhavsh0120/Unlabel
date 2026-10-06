# India snapshot: measured storage and nine-month refresh

Updated 6 October 2026. The user changed the manual replacement policy from six to **nine months**. Backend v0.2.1 acquired the complete official nightly global CSV stream and selected exact India country tags. A local index is ready; hosted distribution remains a separate v0.2.2 gate. [Acquisition evidence](INDIA_EXPORT_FEASIBILITY.md), [implemented catalogue](../architecture/CATALOGUE.md), and [release review](../planning/BACKEND_V0_2_1_REVIEW.md).

## What was actually measured

The compressed world source was 1,275,171,186 bytes. Streaming checked 4,535,553 rows without retaining the world file. The India identity projection is 6,588,910 bytes; the SQLite index is **11,993,088 bytes (11.44 MiB)**. It contains 21,138 supported barcode records out of 21,188 India-tagged rows; 50 unsupported codes are counted. Missing ingredients affect 74.65% of indexed products. No exact duplicates or leading-zero equivalence collisions were found.

This is every matching row in this particular export, not every product sold in India. Live search reported 24,706 matches; the discrepancy remains unexplained. Global exports can include obsolete records and source timestamps differ. Coverage stays `unverified`; a live-found chocolate sample is absent from the snapshot. The selected identity dataset excludes aggregate nutrition, images and record modification dates. Canonical allergen data is unknown when its exact export column is absent.

## Placement comparison

The identity projection is now retained in Git as an 840,099-byte gzip with hashes, provenance and licenses. [Setup](../planning/LOCAL_DEVELOPMENT.md) rebuilds ignored SQLite from this [bundle](../../data/catalogue/README.md). Local recovery does not enable hosted distribution or frontend offline support.

| Placement | Benefit | Cost or limitation |
| --- | --- | --- |
| India identity database in app | Indexed lookup without a backend connection | The measured file adds about 11.44 MiB before packaging; richer nutrition/images add unmeasured size. Every device needs updates and a database reader. |
| SQLite catalogue on backend | Small client, central updates, indexed barcode reads without OFF per cached identity request | Requires verified file packaging/distribution and backend connectivity. Not a durable writable serverless database. |
| Backend plus small client cache | Central source with offline saved/recent products | Frontend cache limits/eviction/freshness still need implementation. |

The measured identity database is not intrinsically too large to bundle in an app. Size alone does not justify a full offline conclusion: nutrition/source richness, missing fields, runtime support and nine-month device updates also matter. Retain the chosen online-first backend with a future small client cache; the teammate can evaluate offline catalogue download later. No corpus is bundled into Flutter now.

CSV/JSONL are acquisition formats; **SQLite is selected for serving**. Firestore adds shared cloud document operations and finite quotas without improving this read-only snapshot's core requirement. [Detailed comparison and current official quota links](../architecture/CATALOGUE.md).

## Bounded storage

Acquisition retains only an India projection, with 100 MiB output, 2 GiB compressed-transfer and 32 GiB decoded-stream caps. The importer defaults to a 100 MiB SQLite artifact and 1 GiB immediate work-directory file budget. Current projection plus index occupy about 17.72 MiB locally; a new projection/index and deliberate short rollback copy fit well within that budget. These are operation-directory bounds, not a recursive quota over all user files. Keep source/rollback files in known owned directories and check free disk before refreshing. No images are downloaded.

Ignored runtime data does not reach Vercel through Git. The documented standard Python function bundle limit is 500 MB uncompressed including dependencies; eligibility for larger beta bundles is separate. A measured small local index does not establish private artifact download/build inclusion or live cloud reads. Verify that reproducible free deployment path before enabling snapshot preference. [Vercel Python runtime](https://vercel.com/docs/functions/runtimes/python).

## Nine-month replacement procedure

1. Use a fresh source directory and keep the active catalogue serving. Stream the documented official export, verifying header/dialect, full EOF, byte count and checksums. Do not scrape per barcode or retain the world dump.
2. Compare country/index counts, unsupported/duplicate codes, dates and field gaps with the active manifest. Review a large unexplained reduction before promotion. Preserve source attribution/licenses and keep private scans/regulatory findings separate.
3. Make a deliberate short rollback copy of the active validated index if needed. Build a unique staging database beside the active file, with an exclusive import lock and artifact/work/free-disk bounds. Validate integrity, manifest, count and representative products before publication.
4. Atomically replace the single active file. Each lookup's read-only transaction reads its manifest and product together; cached store reads see the new file on subsequent connections. A failed acquisition/import keeps the active catalogue unchanged. Crash/busy locks require operator review rather than automatic reclamation.
5. Check source/hash/count, representative found/absent lookups and the exact hosted artifact after deployment. Clean only identified importer-owned source/rollback artifacts after success; retain one active catalogue rather than an ever-growing history.

The current source timestamp is 5 October 2026; target the next manual refresh around **July 2027**. This is a documented operating policy, not a scheduled job. Preserve data age between updates and keep live lookup available separately. Confirmed package fields take priority for current ingredients/allergens. Reviewed FSSAI evidence needs its own effective-date checks whenever rules change, independently of product-data cadence.

Retain OFF attribution and applicable ODbL/DbCL/share-alike requirements. Private scans and reviewed regulatory findings are separate; no contribution upload is implemented. [OFF cache guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/creating-a-local-cache-of-open-food-facts-data/) and [license guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/).
