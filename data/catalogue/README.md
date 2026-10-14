# Recoverable India product catalogue

Research database checkpoint (8 October 2026): backend **v0.10.0** adds a
separate generated read-only SQLite with **243 observations** (49 manufacturer,
125 retailer and 69 OFF). It preserves dated sources, unknown identities and
formula conflicts. Three additive GETs expose researched product search,
`by-barcode/{barcode}` and `{entry_id}` under `/v1/researched/products`.
The exported API now has 24 paths/25 operations and 29 synthetic examples.
Source normalization does not import the runtime; `scripts/data/build_research_catalogue.py`,
the backend deployment build and `scripts/setup.py --catalogue-only` do. Runtime
files live in ignored `backend/app/research_catalogue/data/`. Frontend **v0.5.0+6**
adds mixed-source search and qualified ingredient/nutrition/source details.
Local verification and hosted/push status: [backend review](../../docs/planning/BACKEND_V0_10_0_REVIEW.md) ·
[frontend review](../../docs/planning/FRONTEND_V0_5_0_REVIEW.md) ·
[product list](../../docs/research/POPULAR_PRODUCTS_ADDED.md).
The user's next automatic-capture/results redesign is recorded in the
[automatic scan plan](../../docs/planning/AUTOMATIC_SCAN_PLAN.md).
Earlier release statements below retain their historical scope.


Product data from [Open Food Facts](https://world.openfoodfacts.org/) is retained under [ODbL 1.0](licenses/ODbL-1.0.txt), with individual contents under [DbCL 1.0](licenses/DbCL-1.0.txt). The compact public source, provenance and license notices belong in Git; generated SQLite/receipts do not.

Backend v0.4.0 retains the independently released v0.2.3 identity/rich-facts source and rebuilds it without another global download. No world dump, image bytes, contributor identities, private scans, credentials or history are bundled. Selected-front image metadata supplies attributed official URL descriptors with separate CC-BY-SA licensing. The separate confirmed-label claim knowledge is maintained in [knowledge/](../../knowledge/README.md), not inferred from community snapshot fields.

| File | Purpose |
| --- | --- |
| `india-products.jsonl.gz` | Deterministic gzip of the accepted India projection. |
| `bundle.json` | Checked compressed/decoded hashes/lengths, source date and expected import counts. |
| `acquisition.json` | Original global-stream URL/date/hash/byte/row evidence, field projection and availability measurements. |
| `licenses/` | Retained ODbL/DbCL texts; image licensing is supplied in facts descriptors. |

The complete official JSONL acquisition verified **13,084,464,175 compressed bytes**, gzip EOF, **83,007,975,584 decoded bytes** and **4,795,607 source records**. Exact India projection: **24,695 rows**, **24,641 supported unique barcodes**, **54 unsupported codes**, **0 duplicates**. Candidate gzip: **2,098,225 bytes**; decoded projection: **15,084,130 bytes**. Source time **2026-10-06T06:53:46Z** sets refresh due **2027-07-06T06:53:46Z**.

The original source, compressed India gzip and decoded India JSONL have different hashes/lengths. Original compressed SHA-256: `26d5bb5538838f531e406fe73e9070a502bc2070e5bc0a9bda60869bd091d693`; projected compressed SHA-256: `bbdd13097ede75777b2356e27910ae01aff38d7ad0c59598af6868dcf447db24`; decoded projection/import-source SHA-256: `e508b33d8bf3694d11d052ad4ad70895b254527e0556937e9d2454a8b665818f`.

The tracked replacement validates all **24,641 supported fact records** and generates a verified **62,472,192-byte SQLite (59.58 MiB)** with local receipt. **4,657** records have direct tables (**4,519** with reported values), **15,486** are legacy-unsupported, **4,050** missing and **448** invalid; **18,682** have official image descriptors. All indexed records have validated modification dates. [Full indexed-field and local receipt report](../../docs/research/CATALOGUE_V0_2_3_COVERAGE.json). Raw acquisition counts, strict API facts and actual hosted reads remain distinct evidence. The [v0.2.3 review](../../docs/planning/BACKEND_V0_2_3_REVIEW.md) records complete-source, local artifact and actual hosted verification; preceding [v0.2.2 CSV measurements](../../docs/planning/BACKEND_V0_2_2_REVIEW.md) remain historical.

## Projected facts and coverage

The rich projection preserves selected public identity fields, exact `countries_tags`, canonical category/label/allergen/trace tags, optional schema/modification time and product language. It retains bounded direct `nutrition.input_sets` from packaging/manufacturer sources and selected-front revision/size descriptors. Arbitrary image URLs, uploaded-image/contributor metadata, computed nutrient values and aggregate nutrient values are omitted; a legacy-presence marker allows the API to identify unsupported nutrition explicitly.

Missing/invalid fields remain unavailable, never zero. Present empty community allergen tags do not prove allergen absence. Direct tables preserve source, bases, preparation and original row references; no current-package or FSSAI verdict is implied. Every exact India-tagged source row is retained within the validated projection limits so supported/unsupported counts remain reproducible.

Coverage stays `unverified`. Complete processing of a dated OFF export does not establish all products sold in India, accurate current package facts or agreement with a differently timed live count. Measure gaps and representative sparse/rich/absent records before accepting a replacement.

## Rebuild and manual refresh

Setup verifies tracked hashes/counts and regenerates the local index. The network-free hosted build reads this same source and creates ignored `app/catalogue/data/catalogue.sqlite3` plus receipt; hosted startup verifies its artifact before enabling reads. [Catalogue workflow](../../docs/architecture/CATALOGUE.md) · [Current validation gates](../../docs/planning/BACKEND_V0_2_3_REVIEW.md).

Replace the source manually every **nine calendar months** from its actual export time; rebuilding does not reset age:

1. Acquire the complete official JSONL into a new owned directory using `scripts/data/acquire_india_jsonl.py`. Validate transfer length, gzip EOF/CRC, bounded objects and source hashes without retaining the world dump.
2. Measure India/indexed/unsupported/duplicate counts, field availability, direct versus legacy nutrition, source date, sizes and dated live-count differences.
3. Package with gzip `mtime=0`, empty filename and compression level 9. Replace the accepted gzip, `bundle.json`, `acquisition.json`, notices and review evidence together.
4. Run setup/import, actual hosted-build checks and meaningful tests. Local import replaces one validated staged SQLite; hosted SQLite/receipt use separate writes inside an unpublished build. Reject failed builds.
5. Push the reviewed replacement, verify its exact deployment/source/hash/date/counts/receipt and identity/facts reads, then accept the refresh. Rollback uses the previous verified deployment/source/configuration; never hot-swap packaged runtime files.

No scheduled job or request-time bulk download exists. Git keeps previous source versions and history; review repository growth for later substantially larger bundles. Keep only deliberate owned temporary rollback artifacts and remove them safely after the rollback window.

## Reuse and attribution

OFF-derived projected databases retain **ODbL-1.0** and individual contents **DbCL-1.0**. Preserve notices and satisfy attribution, source/access and share-alike conditions when distributing or publicly using derivative databases. Show OFF attribution with product facts. Keep independently maintained regulatory rules and personal data separate.

Product photographs use a separate license. This source retains metadata rather than photo bytes; facts descriptors carry CC-BY-SA-3.0 attribution/license and clients must preserve appropriate image attribution. These dataset/image licenses do not automatically apply to Unlabel source code. [Official OFF licensing guide](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/) · [Terms of use](https://world.openfoodfacts.org/terms-of-use).
