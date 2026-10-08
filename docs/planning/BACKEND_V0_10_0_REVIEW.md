# Backend v0.10.0: researched product database

Independently pushed from `e04ba543bbda129fd031d44ec7c307c4e870f02d` on `main`,
8 October 2026. Production deployment `dpl_6e39XSRkf8bhmB4Ar3LQ9C8W2BN9` is
**READY with 389 hosted checks passed** at
[the production API](https://unlabel-api.vercel.app). See the
[pinned production receipt](../research/BACKEND_V0_10_0_PRODUCTION.json).
Frontend v0.5.0 integration/render/deployment verification remains independent
and pending; this receipt establishes the backend v0.10.0 checkpoint only.

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

## Hosted verification

A fresh Vercel inspection matched the implementation SHA, READY state,
production target and canonical alias. The 389 public HTTP checks include exact
payload and immutable-hash equality for all 243 acquired observations; all 69
barcode groups (41 exact groups found and 28 unconfirmed groups left unlinked);
complete 21-observation Lays pagination; Unicode brand matching; bounded query,
cursor and identity rejection; CORS and `no-store`; and preserved original OFF,
claim, nutrition, historical-report and comparison behavior. Hosted OpenAPI
matches the tracked export: 24 paths and 25 operations, preserving every v0.9.0
path and schema component. No authenticated writes, credentials, photos or raw
OCR were sent.

The hosted research source digest is
`1f5693f29ffff1f62ef57b8a1a7fb321f6efb5a1559f8efdad19d1e0f4d38a52`.
Its generated database digest is
`fef4a8395e0c257daf2890c1a76258680a04ffe055f0f155a0b9c9220f360158`.
Generated build timestamps and catalogue snapshot IDs can differ from local
rebuilds; the receipt records this hosted build separately and all immutable
source observations remain exact. These checks establish acquired-source
delivery, not complete retail coverage, current-packet compatibility, allergen
safety, physical camera accuracy or end-to-end scan latency.

See [plan](POPULAR_PRODUCTS_DATABASE_PLAN.md),
[source inventory](../research/POPULAR_PRODUCTS_ADDED.md), and
[dataset](../../data/catalogue/popular-india-v1/README.md).
