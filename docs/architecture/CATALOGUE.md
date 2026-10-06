# Product catalogue: tracked source, verified SQLite

Backend **v0.2.2**, frontend **v0.0.0+1**. This is an export-origin product identity catalogue. Live OFF nutrition, user-confirmed label values and future reviewed FSSAI findings remain separate. Hosted verification is recorded in the [v0.2.2 review](../planning/BACKEND_V0_2_2_REVIEW.md); implementing a build hook alone does not prove a successful deployment.

## Storage choice

| Format/service | Role in Unlabel |
| --- | --- |
| OFF CSV/TSV | Official bulk acquisition input. The verified nightly export is unquoted UTF-8 TSV inside gzip. Aggregate nutrient columns are excluded from the current projection. |
| OFF JSONL | Richer local input supported by the importer; richer acquisition is planned for v0.2.3. |
| SQLite | Selected indexed serving format: exact barcode primary key and short read-only transactions without a database account or key. |
| Firestore | Deferred until a shared mutable user-data requirement exists. A remote document store adds credentials, operations and quotas to this immutable snapshot. |

CSV is an acquisition format, not an efficient indexed barcode service. SQLite connections use read-only URI mode and parameterized exact-key queries. [Python SQLite documentation](https://docs.python.org/3.12/library/sqlite3.html#how-to-work-with-sqlite-uris).

## Source and measured coverage

The [tracked source bundle](../../data/catalogue/README.md) contains an **840,099-byte gzip**, **6,588,910 decoded bytes**, provenance and ODbL/DbCL notices. Source export time is **2026-10-05T12:19:34Z**. Its exact `en:india` selection contains **21,188 rows**, indexing **21,138 unique supported barcodes** and counting **50 unsupported barcode rows**. The local generated SQLite artifact is **11,993,088 bytes**; final hosted size/hash must be verified against its own receipt.

The bounded 6 October follow-up counted **24,715 live India-tagged OFF records**, compared with the earlier measurement of 24,706. The **3,527-row** difference from this dated export remains unexplained. Do not force the counts to agree or describe either as every product sold in India. [Measured coverage record](../research/CATALOGUE_V0_2_2_COVERAGE.json).

Coverage remains `unverified`: ingredients are missing in 15,780 indexed records, names in 3,442, and a live-found chocolate sample is absent. This projection excludes nutrition tables, images and per-product modification dates. The canonical `allergens_tags` column was absent; missing allergen tags remain unknown. Provider grades are source-tagged classifications, not Unlabel legal or health verdicts.

## Acquisition, local restore and hosted build

1. `scripts/acquire_india_catalogue.py` explicitly streams the fixed official global gzip through EOF, validates its dialect/header/byte count and records source provenance. It retains the India projection rather than a world dump. Acquisition is never an API-request or deployment-build operation.
2. `scripts/import_india_catalogue.py` validates local input and stages SQLite with supported counts, source hash, attribution and manifest. Duplicate exact barcodes fail. Integrity/count checks finish before the single database file is replaced; a failed local import preserves the active database.
3. `scripts/setup.py` verifies the committed compressed/decoded source hashes and regenerates `backend/storage/runtime/india/catalogue.sqlite3` for local work without another global download. `run_local.py` activates it with process-only settings and `CATALOGUE_REQUIRE_RECEIPT=false`.
4. Vercel's backend build invokes `python build_catalogue.py` through `[tool.vercel.scripts]` in `backend/pyproject.toml`. Outside-root build access supplies tracked `data/catalogue/`. The build performs no network download, env decryption or acquisition. It validates the bundle, generates SQLite and `receipt.json` under ignored `backend/app/catalogue/data/`, then verifies hashes, manifest, integrity and counts before succeeding. [FastAPI build commands](https://vercel.com/docs/frameworks/backend/fastapi#build-command).
5. At hosted startup, `CATALOGUE_REQUIRE_RECEIPT=true` requires that receipt. The backend hashes the SQLite artifact once, validates receipt/manifest/counts and opens a read-only catalogue store. Failed validation disables only catalogue access; health/meta and existing live product/nutrition routes remain usable. Each lookup reads manifest and product together in a short read-only transaction.

The decoded projection hash, compressed projection hash and original global download hash identify different artifacts. Receipts verify the trusted Git/build artifact; they are not independent signatures or proof of OFF authenticity. Generated snapshot IDs/build timestamps can vary between builds, so a repeated build is not promised to produce byte-identical SQLite. Source content/hash/counts remain checked.

## API and configuration

| Route | Behavior |
| --- | --- |
| `GET /v1/catalogue` | Typed status, manifest, source freshness, artifact summary when receipt-verified, and explicit field limits. 200 for ready; 503 for unconfigured/unavailable. |
| `GET /v1/catalogue/products/{barcode}` | Existing `CatalogLookup` v1 contract with export manifest. 200 found, 404 absent from this snapshot, 503 inactive/unavailable; invalid code 422. |
| `GET /v1/meta` | The same catalogue status metadata and `catalogue_lookup` capability. |

Catalogue responses use `Cache-Control: no-store`. Codes match exactly; leading-zero variants are distinct keys. A snapshot miss does **not** trigger an OFF request. Call the separate live `/v1/products/...` routes deliberately when current community data is needed. An overdue snapshot remains queryable with warnings; `within_refresh_window` is a policy age state, not proof that a product matches today's package.

Local settings use `CATALOGUE_DIRECTORY=storage/runtime/india` and receipt checks off. Hosted settings use `CATALOGUE_DIRECTORY=app/catalogue/data` and receipt checks on. Relative paths resolve from backend; an empty directory disables the catalogue. These hosted settings take effect only in a new deployment. Secret env files are excluded from the function; no key is needed for this catalogue.

## Nine-month replacement and rollback

Freshness uses `manifest.exported_at`, never `indexed_at` or a new deployment date. The interval is **nine calendar months**, with month-end/leap-year clamping. This snapshot is due at **2027-07-05T12:19:34Z**; the exact due boundary is `refresh_due`. A future source timestamp is flagged `source_date_in_future` and has unknown age. Dates outside the representable refresh range are refused.

Refresh is an explicit maintenance operation:

1. Acquire a fresh source in a new owned directory. Verify full transfer/EOF, hashes, provenance and redistribution rights.
2. Compare dates, row/index counts, missing fields, representative found/absent codes and the live-count gap. Record unresolved differences; richer source fields need separate adapter/provenance work.
3. Replace the tracked gzip, `bundle.json`, `acquisition.json` and matching notices/docs together after local validation. Keep only a deliberate temporary local rollback copy; clean only known owned files.
4. Push the reviewed source. A new immutable Vercel deployment builds and verifies its own SQLite/receipt. The two generated files are replaced separately inside the unpublished build; there is no atomic two-file filesystem swap. A failed build must not be promoted.
5. Verify the exact production commit, source hash/date/counts, receipt status, found/missing routes and existing APIs. If needed, restore the prior Vercel deployment and matching source/configuration. Packaged runtime files are never updated in place; a changed packaged manifest is rejected rather than accepted as a hot swap.

There is no nine-month scheduled job. Git retains old source versions, so replacement does not erase repository history. The deployment owner must initiate and review each refresh.

## Finite storage and offline boundary

Acquisition caps compressed transfer at 2 GiB, decoded global source at 32 GiB, physical records at 2 MiB and retained projection at 100 MiB. The bundle builder also bounds compressed/decoded input and SQLite to 100 MiB. Local import work-directory defaults are 1 GiB for immediate files; raw source outside that directory and repository history require separate budgeting. No image cache exists. Check free disk and remove only owned temporary artifacts.

The generated hosted SQLite is an immutable function asset, not a durable writable cloud database. Vercel's standard Python bundle limit is 500 MB uncompressed including dependencies; successful source validation and local size are separate from actual hosted packaging/read evidence. [Python runtime](https://vercel.com/docs/functions/runtimes/python).

Backend-held data avoids an upstream request for catalogue identity lookups but still requires app-to-backend connectivity. Flutter has no catalogue/cache integration yet. Saved dated results, local preferences and an optional glossary are future limited offline features; this release does not make phones or the website fully offline. Reviewed FSSAI rules have their own sources/effective dates. Keep OFF attribution, private scans and regulatory findings separate.
