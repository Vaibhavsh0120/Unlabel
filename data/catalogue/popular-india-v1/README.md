# Popular India product sources

This acquired source dataset supplements the original OFF catalogue with
manufacturer and retailer website observations, plus bounded exact-code OFF reads.
The derived researched SQLite store is served by backend v0.10.0 and browsed in
frontend v0.5.0+6. Product identity and missing/conflicting fields stay explicit.

The verified bundle has 243 observations: 49 manufacturer, 125 retailer and 69 OFF.
The 174 website records have 139 ingredient sections (12 partial) and 83 explicitly
based nutrition tables. These are observations, not 243 newly verified formulas;
146 distinct literal brand/product names include repeated packs and source aliases.
The generated read-only database is 1,413,120 bytes. Dataset SHA-256:
`1f5693f29ffff1f62ef57b8a1a7fb321f6efb5a1559f8efdad19d1e0f4d38a52`.
[Measured source/runtime checks](../../../docs/research/POPULAR_PRODUCTS_DATASET_VALIDATION.json).

| Artifact | Purpose |
| --- | --- |
| `observations.jsonl.gz` | Canonical immutable dated source observations, deterministic gzip. |
| `manifest.json` | Compressed/decoded hashes, input hashes, provider/field counts and barcode conflicts. |
| `targets.json` | Bounded keyword-based discovery targets from the dated OFF snapshot; not sales/coverage proof. |
| `off-api-observations.json` | Original exact-code acquisition/checkpoint evidence and rate-limit failures. |
| [Website sources](../../../docs/research/popular-products-2026-10-08/) | Actually inspected manufacturer/retailer inputs with conflicts, exclusions and unknowns. |

Build the source explicitly with `scripts/build_popular_dataset.py --web-input ...`
and optional `--off-input ...`; verify it using:

~~~powershell
./backend/.venv/Scripts/python.exe scripts/build_popular_dataset.py --verify data/catalogue/popular-india-v1
./backend/.venv/Scripts/python.exe scripts/build_research_catalogue.py
./backend/.venv/Scripts/python.exe scripts/build_research_catalogue.py --verify backend/app/research_catalogue/data
~~~

The source builder's `runtime_promotion: none` means normalization itself does not
write the served database. The second explicit build imports these records into
the separate verified SQLite/receipt. Deployment's backend build and local setup
perform that import. Generated databases are ignored; acquired sources stay in Git.

Manufacturer/retailer source licenses remain unknown or restricted as recorded;
these factual enumerations are not assigned OFF's ODbL/DbCL or community CC0.
OFF observations retain ODbL/DbCL separately. No page HTML, copyrighted advertising
prose, photos/image bytes, contributor identities or private account data is retained.
Images are not acquired. Some retailer offers describe imported products, which
remain marked as such and cannot substitute for an Indian-manufactured formula.

Google/AI Mode supplied discovery leads, not trusted product values. Underlying
pages were inspected. A Cadbury AI summary combined packs/average values; those
claims were excluded. The original source, per-product facts and category averages
have different meanings. Current physical-package truth and comprehensive Indian
retail coverage remain unverified.

The OFF batch stopped on HTTP429 after 69 acquired records. Outstanding discovery
targets were not silently marked acquired. Decimal strings from an earlier resume
encoding defect remain raw/unknown pending source restoration; no blind coercion
is allowed. Future acquisition uses the fixed resume/checkpoint/pacing boundaries.

[Full product list](../../../docs/research/POPULAR_PRODUCTS_ADDED.md) ·
[Implementation plan](../../../docs/planning/POPULAR_PRODUCTS_DATABASE_PLAN.md).
