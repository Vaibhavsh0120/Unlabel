# India product snapshot proposal

Updated: 5 October 2026. User preference: download available India product records and refresh manually every **six months**. This is planned for a separate backend version; v0.1.0 uses live product reads. No dataset has been downloaded or import job scheduled.

## Scope and source

Filter OFF's country/market classification for records tagged as sold in India (`en:india` under the documented country tags). This is not a list of every product sold in India, nor proof of Indian manufacture or current regulatory applicability. Coverage, missing country tags, incomplete nutrition and duplicate/normalized barcodes require measurement.

For bulk acquisition use the [official data export service](https://world.openfoodfacts.org/data), not one product call per barcode or paginated search scraping. OFF explicitly directs bulk users to CSV/JSONL exports in its [API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/). A country-specific complete export URL/size was not verified during this version; the data page returned crawler restrictions to the research tool.

Preferred future path: an official filtered export if available; otherwise stream an official global CSV/JSONL dump and select India-tagged records without loading the world dataset into RAM. CSV provides a subset of fields; full JSONL can be much larger. Choose based on actual fields, byte sizes and disk space. Do not assume a country-search result or CSV contains all product facts. Images are separate and need not be downloaded.

## Future import and hosting

1. Record exact export URL, download/export times, checksum, source format/schema, selection predicate and licenses.
2. Stream/filter India records, preserve barcode strings, provider facts/revisions and unknown values. Do not modify OFF snapshots with private scans or FSSAI-derived findings.
3. Build a read-only barcode index (SQLite is suitable locally), with import counts and quality/coverage metrics. Keep raw downloads/generated databases out of Git.
4. Validate fixtures against the importer and normalizer, publish a versioned snapshot manifest and update attribution.
5. Serve snapshot lookup first, with a bounded live OFF fallback for missing records or an explicitly requested refresh. Responses distinguish export age, record modification date and live retrieval time; do not call an old snapshot freshly fetched data.
6. Rebuild the snapshot manually every six months, validate counts/schema/checksums and representative lookups, then switch atomically to its immutable artifact. Retain the old copy only during validation and a short rollback window; remove importer-owned old local artifacts after the replacement is healthy. Keep one active catalogue, not an indefinitely growing collection. This is a release operation, not a long-running Vercel request.

A read-only bundled SQLite index can be deployed only after measuring bundle size and the chosen runtime's packaging/read access. It is not a writable durable Vercel database. Standard Python bundles currently have a 500 MB limit including dependencies; eligible Fluid-compute large-function beta behavior differs and must be verified for the actual account. Do not rely on beta eligibility or larger limits for the no-card baseline. [Python runtime](https://vercel.com/docs/functions/runtimes/python), [large-function announcement](https://vercel.com/changelog/vercel-functions-can-now-be-up-to-5-gb-in-package-size-7yAwSyCig0IQDXUIDistvS/eadf06d6c3).

If the compact India artifact fits comfortably, stage it into the backend build with a checksum. Otherwise keep the importer/index for local demos and use the live API on Vercel until a verified free storage path is chosen. Do not add a paid database, download a multi-GB dump per API request, or promise deployment before measuring.

## Storage and speed budget

The backend's indexed snapshot should reduce upstream latency; this is a performance expectation to benchmark, not a measured result yet. Mobile clients still need backend connectivity for uncached products. Start with backend placement and a small client cache; evaluate a full app snapshot only after measuring its actual size/update overhead. A backend index does not make the phone fully offline.

Proposed importer budgets, subject to measured source size/coverage:

- Target at most **100 MB** for the compact indexed snapshot; keep only fields required by implemented APIs. If it exceeds the target, measure field/index overhead and split the hosting decision before adding more data; do not silently drop products and call it a complete India export.
- Retain one active snapshot, with the previous copy only during replacement/rollback validation. Build the replacement in a temporary directory; budget for temporary overlap and check free disk space before starting. A failed import keeps the current snapshot usable.
- Start with a **1 GB local work-directory budget**, including retained indexes and temporary output. Prefer streaming/filtering the export instead of retaining the full global raw dump. If an import cannot complete inside the budget, fail clearly and choose a filtered source or revised explicit budget.
- Do not download full product photos for the catalogue. Future thumbnails require a separate bounded cache and applicable image attribution.
- Keep raw exports/generated indexes outside Git and outside unrelated workspace folders. Clean only importer-owned expired artifacts after validating the replacement; never erase private scans or files belonging to the user.
- A future mobile/browser metadata cache can begin with a **10 MB / 100-product maximum**, evicting unpinned least-recently-used entries and showing saved data age. User-saved history needs its own visible limit/delete controls. These are client requirements for the teammate, not backend work implemented here.

Benchmark cold/warm barcode lookup latency, index size, product count, missing-field coverage and live fallback frequency before deciding whether the snapshot improves the actual demo. Do not copy the world dataset into every serverless instance or reload the index into RAM for every request.

| Placement | Benefit | Trade-off |
| --- | --- | --- |
| Full India snapshot in app | Low-latency complete-snapshot lookup offline | Adds the actual measured database bytes/indexes to each device; requires download/update and local migration; images can dominate storage |
| India snapshot on backend | Small app, central indexed lookup and six-month replacement; no OFF/FSSAI call for each cached analysis | Phone still needs backend connectivity; hosting/storage size and latency must be measured |
| Backend snapshot plus small app cache | Central updates and offline saved/recent content | Cache eviction/stale-data handling needed; uncached products still online |

Recommended planned direction: backend snapshot plus small metadata cache, consistent with the accepted online-first scope. A full app snapshot remains technically possible if measured size and client update UX justify it; no oversized-data conclusion has been measured. Reviewed FSSAI criteria are separately bundled/versioned on the backend, not queried live per scan. Updating product facts every six months does not mean regulatory updates can wait if applicable criteria change.

## Refresh and evidence policy

Six-month refresh is acceptable for a college-project reference catalogue. It does not promise current ingredients, allergens or FSSAI compliance. Confirmed package fields take priority, missing fields remain unknown, and record-based assessments identify their data age. Users can review a live result when connected; fresh rule/evidence versions remain independently tracked.

Retain OFF attribution, ODbL/database-content obligations and applicable sharing requirements. Keep reviewed FSSAI rules and private scan inputs separate from the source snapshot. No automatic contribution uploads are part of this importer. See [OFF cache guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/creating-a-local-cache-of-open-food-facts-data/) and [license guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/).
