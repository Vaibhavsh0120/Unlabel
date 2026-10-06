# Recoverable India product catalogue

Product data from [Open Food Facts](https://world.openfoodfacts.org/), made available under the [Open Database License 1.0](licenses/ODbL-1.0.txt). Individual database contents are licensed under the [Database Contents License 1.0](licenses/DbCL-1.0.txt).

This directory keeps the compact source projection in Git so a fresh clone can rebuild the same indexed catalogue without downloading the global export again. SQLite is generated locally and during the backend v0.2.2 deployment build; it is not a second copy in Git. The hosted build also emits a verified receipt under ignored `backend/app/catalogue/data/`.

## Files

| File | Purpose |
| --- | --- |
| `india-products.jsonl.gz` | Deterministic gzip of the acquired India projection: 840,099 compressed bytes; 6,588,910 decoded bytes. |
| `bundle.json` | Checked compressed/decoded hashes, lengths, source date and expected import counts used by setup. |
| `acquisition.json` | Provenance of the original global download, including its separate compressed SHA-256, HTTP source date, rows scanned and omitted fields. |
| `licenses/` | Official ODbL and DbCL text, retained with the dataset for redistribution. |

`bundle.json` describes the small gzip in this directory. `acquisition.json` describes the original **1,275,171,186-byte global gzip** streamed on 6 October 2026. Their compressed hashes and sizes refer to different artifacts. The decoded bundle SHA-256 is the importer's source hash.

## Coverage and fields

The source was last modified on **5 October 2026 at 12:19:34 UTC**. Its exact `en:india` filter yielded **21,188 rows**. The importer indexes **21,138 unique supported barcodes** and reports **50 unsupported barcode rows**. All source rows are retained here so those counts can be independently reproduced.

This covers India-tagged records in this specific OFF export. It does not claim to contain every product sold in India. The bounded v0.2.2 follow-up counted 24,715 live India-tagged records, leaving a 3,527-row gap from this dated export; the cause remains unresolved. Coverage stays `unverified`. [Current measurement](../../docs/research/CATALOGUE_V0_2_2_COVERAGE.json).

Each JSONL record contains only these projected public product fields:

- `code`, `countries_tags`, `product_name`, `brands`, `quantity`;
- `ingredients_text`, `allergens_tags`, `traces_tags`;
- `nutriscore_grade`, `nova_group`.

Missing values remain unknown. In this source, legacy bare allergens were excluded because they can omit ingredient-derived tags; `allergens_tags` therefore remains unknown. Nutrition tables, product photos, contributor details, private scans, credentials and user history are not bundled. This snapshot cannot establish allergen safety or FSSAI compliance.

## Rebuild and refresh

Use the repository's setup command to verify this bundle and regenerate `backend/storage/runtime/india/catalogue.sqlite3`. The generated database and Python environment can be recreated; the acquired source, its provenance and license notices belong in Git. A clone does not need an OFF key or another bulk download to rebuild this index.

The separate hosted build reads this same bundle without network acquisition or env decryption, verifies hashes/counts and generates SQLite/receipt for immutable function packaging. [Catalogue workflow](../../docs/architecture/CATALOGUE.md) and [v0.2.2 production verification](../../docs/planning/BACKEND_V0_2_2_REVIEW.md) distinguish local build evidence from live deployment proof.

Replace the entire source bundle manually every **nine calendar months**; its source timestamp **2026-10-05T12:19:34Z** sets the exact due boundary to **2027-07-05T12:19:34Z**. New build timestamps never reset this source age:

1. Acquire a fresh official source into a new owned directory and validate its complete download.
2. Project the India rows and compare coverage, counts, missing fields and representative lookups with the active snapshot.
3. Package the JSONL with gzip `mtime=0`, empty filename and compression level 9. Update `bundle.json`, `acquisition.json`, this README and the review evidence together.
4. Run setup/import and hosted-build verification against the proposed source. The local importer stages and validates SQLite before replacing the single active database; failed imports preserve it. Hosted builds generate SQLite/receipt with two separate file replacements inside an unpublished build; a failed build must not be promoted.
5. Commit/push the reviewed replacement bundle to create a new immutable deployment. Verify its exact source/date/hash/counts, receipt status and lookups before treating the refresh as complete. Roll back to the prior deployment with matching source/configuration when needed; never hot-swap packaged runtime files. Keep an explicit temporary local rollback copy only when needed and remove known owned artifacts after the rollback window.

No scheduled job or request-time bulk download is configured. Git keeps historical source versions; a normal clone also receives repository history. If future bundles become substantially larger, review Git growth before adopting an artifact store or Git LFS.

## Reuse and attribution

Redistribution of this projected database is permitted under ODbL 1.0, subject to its attribution, notice, access and share-alike conditions. This projection and any redistributed derivative database retain **ODbL-1.0**; its individual contents retain **DbCL-1.0**. Preserve this directory's notices and provide the machine-readable source or required alterations when publicly using a derivative database. Display OFF attribution in product results. Keep personal data and independently maintained regulatory rules separate.

These dataset licenses apply to OFF-derived data, not automatically to Unlabel's source code. Product photographs have a separate license and are absent from this bundle. The [official OFF licensing guide](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/) and [terms of use](https://world.openfoodfacts.org/terms-of-use) describe the upstream conditions; the included license texts govern reuse.
