# Backend v0.10.0: researched product database

Local verification complete on `main`, 8 October 2026. Independent push and hosted
verification remain pending.

Manufacturer/retailer website observations now enter a separate generated,
read-only SQLite product database. Unknown barcodes remain searchable by name,
brand, variant and pack size; details retain ingredients, declared allergens,
nutrition basis, source/date/license, conflicts and unknowns. Existing OFF,
community, confirmed-label, comparison and account contracts remain independent.

## API and storage

- `GET /v1/researched/products/search`: at most 20 results per page, Unicode
  identity matching, bounded complete match counts and dataset/query/limit-bound
  cursors. Queries above 1,000 matches require refinement.
- `GET /v1/researched/products/{entry_id}`: immutable acquired source observation
  addressed by its SHA-256. No cross-source field selection or averaged values.
- `GET /v1/researched/products/by-barcode/{barcode}`: only qualified exact identities
  without recorded barcode-group conflicts. Checksum-only retailer leads stay unlinked.
- `/v1/meta` advertises independent researched database readiness and hashes.

The backend Vercel build verifies the acquired source and generates
`app/research_catalogue/data/research.sqlite3` plus `receipt.json`. Startup verifies
hashes, format, record identities and indexed semantics. Each request uses short
read-only parameterized queries; no provider/network/credential access is needed.
Changed files or unavailable stores fail closed while other APIs remain usable.
Local `scripts/setup.py --catalogue-only` also restores this database.

Acquisition checkpoints every completed read, preserves decimal types on resume,
resanitizes public fields, honors retry pacing and stops immediately on HTTP429.
The earlier OFF maintenance checkpoint contains numeric strings after a resume
encoding bug. Its raw evidence remains retained; those strings are unknown rather
than exact nutrient values in the normalized dataset. Estimate and legacy aggregate
tables stay outside direct nutrition.

## Verification

Full suite: **1,132 passed, five provider/emulator skips**. Ruff and Pyright pass;
source/runtime builds and local setup restore all243 observations. Eighteen store/router tests cover unknown barcodes,
mixed sources, Unicode/SQL input, pagination scopes, broad queries, immutable-source
and rehashed semantic tampering, read-only SQL, concurrent publication and replaced
files. Acquisition/normalization tests cover response bounds, identity, privacy,
atomic checkpoints, resume decimals, HTTP429, interruptions and numeric unknowns.
Integrated app tests exercise the actual bundle without OFF calls or authentication.

Research index format2 joins straight/curly brand apostrophes and folds Latin
accents without dropping Indic marks; Lays/Lay's/Lay’s and Real/Réal find the same
source identities. The original source bytes remain unchanged. Tampered/missing
active databases fail closed in metadata and all research APIs while health stays
usable. Preview tests cover the three exact GET routes and bounded rejected-body
cleanup on Windows;30 runner tests and25 repeated transport cases pass.

The final dataset has243 observations (49 manufacturer,125 retailer,69 OFF).
Its174 website records include139 ingredient sections (12 partial) and83 explicitly
based nutrition tables. Local indexed query medians were2.7–8.7ms across30 runs
for each of eight representative queries; these are local store measurements,
not hosted/device/end-to-end latency. Original bulk source hashes still match.

Independent source review identified retailer formula/quantity conflicts, partial
declarations, restricted-reuse records and discovery-only records. These remain
visible qualifications. The original OFF bulk gzip and receipt are preserved.

See [plan](POPULAR_PRODUCTS_DATABASE_PLAN.md),
[source inventory](../research/POPULAR_PRODUCTS_ADDED.md), and
[dataset](../../data/catalogue/popular-india-v1/README.md).
