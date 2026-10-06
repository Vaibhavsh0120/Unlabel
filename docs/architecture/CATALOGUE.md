# Product catalogue: export in, SQLite out

Backend v0.2.1; frontend remains v0.0.0. This is a product identity catalogue, separate from direct-label nutrition and future FSSAI findings.

## Storage choice

| Option | Role | Decision |
| --- | --- | --- |
| OFF CSV/TSV | Bulk download, inspection and identity projection | Use the verified official nightly export. Its nutrient columns are aggregated and excluded from this version. |
| OFF JSONL | Richer raw product input | Import supported local plain/gzip JSONL; acquiring the full 13.08 GB compressed source is optional when richer fields are required. |
| SQLite | Indexed serving database | Selected. Exact barcode primary key, one read-only file, no database account/key, staged manual replacement. |
| Firestore | Shared mutable cloud documents | Defer until shared user accounts/data are needed. Adds remote operations, credentials and quota management to a read-only catalogue. |

CSV is an input format rather than a competing database service. Reading the full CSV per barcode would do unnecessary work. SQLite supports read-only URI connections and indexed parameterized queries. [Python SQLite documentation](https://docs.python.org/3.12/library/sqlite3.html#how-to-work-with-sqlite-uris).

Firestore Standard's published free quota includes 1 GiB stored data, 50,000 document reads/day and 20,000 writes/day. A 24,706-document initial load already exceeds one day's free write allocation; splitting uploads is possible but adds work. These limits do not make Firestore unusable; SQLite better matches this particular immutable snapshot. No Firestore project or billing account was created. [Official quotas](https://firebase.google.com/docs/firestore/quotas).

## Implemented flow

1. `scripts/acquire_india_catalogue.py` streams the fixed official global gzip CSV. Its actual format is unquoted UTF-8 TSV. Verify header/column counts, compressed byte count and gzip EOF; retain SHA-256 and source HTTP Last-Modified separately.
2. Select exact `en:india` country tags. Write only identity, ingredient and supported provider-grade fields to a compact JSONL projection. Exclude images/nutrition. Bare legacy `allergens` can omit ingredient-derived tags, so only a real `allergens_tags` column is mapped; otherwise allergen tags stay unknown. Preserve `traces_tags` when supplied.
3. `scripts/import_india_catalogue.py` streams the local projection/JSONL into unique staging SQLite. Validate rows, supported barcodes, unknowns, budgets and full EOF. Exact duplicates fail instead of choosing a winner. Unsupported barcode rows are counted, not silently considered indexed.
4. Embed the validated manifest, run integrity/count checks and close the writer before replacing `catalogue.sqlite3`. Existing unrecognized databases are refused; failed imports preserve the active catalogue. Only invocation-owned staging files are removed.
5. A configured API caches the verified store at startup. Each barcode read opens/closes a short read-only transaction for the current manifest and indexed product; no full scan or OFF request per lookup. Manual replacement becomes visible at the same path. A missing/corrupt startup catalogue stays unavailable until corrected and restarted; live routes remain usable.

The importer manifest hash covers decoded local import-input bytes. For CSV projection, the separate acquisition record contains the original compressed global source hash. These hashes identify different artifacts. `exported_at` describes supplied source age, `indexed_at` is build time; neither is a live provider retrieval time. `coverage: unverified` does not claim independent market completeness; `sample` labels small samples. Global exports may include obsolete records.

## API and configuration

`GET /v1/catalogue/products/{barcode}` returns `CatalogLookup` with its own `Manifest`; it never claims upstream API3.6 provenance. HTTP 200 means an indexed record, 404 means absent from this snapshot, 503 means inactive/unavailable. All carry `Cache-Control: no-store`. Invalid barcodes use the shared redacted 422 schema. Matching is exact: leading-zero variants are separate keys.

Set `CATALOGUE_DIRECTORY=storage/runtime/india` in ignored `backend/.env` only after import validation. Relative paths resolve from backend; empty means inactive. `/v1/meta` exposes catalogue status/manifest and enables `catalogue_lookup` only for a readable configured catalogue. The existing `/v1/products/...` endpoints keep their live OFF contract and do not silently switch origins.

## Finite storage and refresh

Acquisition caps compressed transfer at 2 GiB, decoded source at 32 GiB, a physical record at 2 MiB and retained India projection at 100 MiB. It never stores the world file. Use a fresh existing source directory; an exclusive lock and exclusive publication refuse competing producers. A crash may leave a lock/part file; remove only the identified invocation-owned files after checking no acquisition is running.

SQLite defaults to 100 MiB artifact and 1 GiB immediate work-directory files, with SQLite page limits also bounded by remaining directory space. Raw source storage outside that directory must be budgeted separately; the catalogue limit is not a recursive whole-disk quota. Check free disk before acquisition/import. No image cache is present.

Refresh manually every nine months: acquire a new source, validate/hash/compare counts and gaps, stage a new index, verify representative lookups, then replace. Keep one active database. Preserve the prior validated artifact separately only for a deliberate rollback window; clean only known owned source artifacts afterward. Acquisition has no automatic schedule or regulator scraping.

## Production and offline boundary

The Vercel backend remains on live OFF lookup until a reproducible deployment path for the measured immutable artifact is verified. Ignored `storage/runtime/` is excluded from automatic Git deployments. Python functions can include build-time files; the published standard bundle limit is 500 MB uncompressed including dependencies, while larger beta eligibility is separate. [Vercel Python runtime](https://vercel.com/docs/functions/runtimes/python).

A local index is not proof that the hosted index is packaged or that phones work offline. The frontend still needs its own saved-result/cache integration. Reviewed FSSAI rules are separate files with independent effective dates. Keep OFF attribution/ODbL/DbCL obligations, private scans and regulatory findings separate; no image reuse or contribution upload occurs here.
