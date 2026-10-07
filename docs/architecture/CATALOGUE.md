# Product catalogue: tracked source, verified SQLite

Updated **7 October 2026**. Local backend **v0.4.0 Community Product Catalogue**
is implemented; production remains **v0.3.0** until push and hosted verification.
Flutter **0.0.0+1** is still a starter. Four additive APIs save structured package
observations automatically, stage provisional facts privately and resolve compatible
fields with source/date and conflicts. Firebase Unlabel has its first Standard
`unlabel` database in Mumbai with free tier/no linked billing, anonymous Auth and
denied direct client access. Frontend capture/OCR/background save remains pending.
[Master plan](../planning/MASTER_PLAN.md) · [Current release gates](../planning/BACKEND_V0_4_0_REVIEW.md).

## Storage and source

| Format/service | Role |
| --- | --- |
| Official OFF JSONL gzip | Rich bulk input streamed through validated EOF; retain only the compact exact-India projection. |
| OFF CSV/TSV | Earlier identity acquisition remains supported; its aggregate nutrients are not direct package tables. |
| SQLite | Generated exact-barcode index and bounded optional facts table, served with read-only parameterized queries. |
| Firestore | Separate configured Standard database `unlabel` stores automatic public observations/private staging; immutable OFF snapshot still needs no cloud credentials. |

The [tracked bundle](../../data/catalogue/README.md) keeps the projected gzip, compressed/decoded hashes and lengths, original acquisition provenance, source date, expected counts and ODbL/DbCL notices. SQLite/receipts are generated, ignored outputs. Image metadata has separate CC-BY-SA attribution; image bytes and the global dump are not retained.

The full v0.2.3 JSONL stream reached validated EOF: **13,084,464,175 compressed bytes**, **83,007,975,584 decoded bytes**, **4,795,607 source rows**, **24,695 exact India rows** and **24,641 supported unique codes**. Candidate projection is **2,098,225 gzip bytes / 15,084,130 decoded bytes**. Source date **2026-10-06T06:53:46Z** sets refresh due **2027-07-06T06:53:46Z**. The [rich-facts source review](../planning/BACKEND_V0_2_3_REVIEW.md) records hashes, raw gaps, strict facts/local build evidence and actual hosted evidence. All **24,641** supported facts pass strict validation; **4,657** have direct tables (**4,519** with reported values), **18,682** have official image descriptors and all have record dates. The network-free local build verifies **62,472,192 SQLite bytes (59.58 MiB)** and its receipt. [Full field/local build report](../research/CATALOGUE_V0_2_3_COVERAGE.json). Local scope has **402 passing tests** and independent review has **103 passing tests**, no actionable findings and no demonstrably dead v0.2.3 code. Actual private-key restoration was not rerun; hosted verification passed with matching actual build receipt/public artifact, 20 HTTP checks and both READY deployments. [Dated production evidence](../research/BACKEND_V0_2_3_PRODUCTION.json). Source-only tag `v0.2.3` points to tested implementation `56064d7fd13d585c949eb2d31a53eb3884a5d520`. The [v0.2.2 CSV coverage report](../research/CATALOGUE_V0_2_2_COVERAGE.json) remains historical. Coverage stays `unverified`: a complete dated India-tagged OFF export is not every product sold in India.

## Acquire, restore and build

1. `scripts/acquire_india_jsonl.py` streams the fixed official full JSONL gzip through validated compressed length, gzip CRC/EOF and bounded strict objects. A range feasibility sample cannot replace full-source proof. Acquisition retains only the selected India fields and records original/source/projection measurements. It is an explicit maintenance operation outside requests and deployment builds.
2. `scripts/import_india_catalogue.py` validates plain/gzip local input and stages SQLite. Exact duplicate supported codes fail. Optional facts are bounded and must match identity keys/counts. Integrity/count checks finish before replacing the single local database; failed import preserves the active file.
3. `scripts/setup.py` verifies tracked source hashes/counts and rebuilds `backend/storage/runtime/india/catalogue.sqlite3` without another bulk download. `run_local.py` activates this local index through process settings with receipt checks off.
4. Vercel's backend build invokes `python build_catalogue.py` through `[tool.vercel.scripts]`. Outside-root build access supplies tracked `data/catalogue/`. The build downloads nothing, decrypts no env, verifies input, generates SQLite/receipt under ignored `app/catalogue/data/`, then checks integrity/hash/manifest/counts before succeeding. The same v0.3.0 hook separately validates/packages the approved claim-knowledge JSON and receipt under `app/claims/data/`; stdout has `catalogue` and `claims_knowledge` keys.
5. Hosted startup requires `CATALOGUE_REQUIRE_RECEIPT=true`, validates the full database once and opens a read-only store. Failure disables catalogue access while health/meta/live APIs remain usable. Each lookup reads identity, facts and manifest in one short transaction.

The original global hash, compressed projection hash and decoded projection hash identify different artifacts. Receipt values verify the trusted Git/build bundle, not an independent OFF signature. Build UUIDs/index timestamps can change SQLite bytes between builds; source content/counts stay validated. Two generated files are replaced separately inside an unpublished build, so a failed build must not be promoted.

## API and client integration

| Route | Behavior |
| --- | --- |
| `GET /v1/catalogue` | Ready/unconfigured/unavailable status, manifest, source age, receipt artifact summary and loaded-store field limits. |
| `GET /v1/catalogue/products/{barcode}` | Preserved identity `CatalogLookup` v1: 200 found, dated 404 absent, 503 inactive/unavailable. |
| `GET /v1/catalogue/products/{barcode}/facts` | Separate `FactsLookup` v1: identity/manifest plus strict `details`; found older identity-only stores report facts unavailable. |
| `GET /v1/meta` | `catalogue_lookup` and additive `catalogue_facts` capabilities; facts requires a validated facts-enabled store. |

Codes match exactly and preserve leading-zero variants. Invalid barcode input returns 422. Status/identity/facts responses are `no-store`; metadata retains its existing cache header. Snapshot misses make no OFF request. Explicit live product/nutrition routes remain available when current community facts are wanted.

`details` distinguishes available/missing/invalid category, label, allergen and trace fields. Available empty tags do not prove absence of allergens. Direct nutrition accepts packaging/manufacturer tables only, using the shared bounded parser; `missing`, `legacy_unsupported` and `invalid` do not become zero. Tables preserve origins, rows, bases, preparation, unknowns and conflicts. Optional `last_modified_at` is a record date, distinct from source export and build dates.

An image is null or an official selected-front 400-size URL descriptor with language/revision, optional dimensions, attribution and CC-BY-SA-3.0 metadata. Arbitrary URLs, proxies and image bytes are excluded. OFF's [canonical image-path implementation](https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/lib/ProductOpener/Products.pm) normalizes/pads/splits the code for image storage; exact catalogue lookup identity remains unchanged. Clients need attribution, a fallback and a separate image fetch; a descriptor does not prove the remote image currently exists.

Local settings use `CATALOGUE_DIRECTORY=storage/runtime/india` and receipt checks off. Hosted settings use `CATALOGUE_DIRECTORY=app/catalogue/data` and receipt checks on. Relative paths resolve from backend; empty disables the catalogue. Hosted configuration changes activate through a new deployment, with secret env files excluded from the function.

## Nine-calendar-month replacement and rollback

Freshness uses actual `manifest.exported_at`, never indexing/deployment time. Nine calendar months clamp month-end/leap-year dates; the exact due boundary is `refresh_due`. Overdue records remain available with warnings. Future/out-of-range source dates are flagged/refused. This age is a maintenance policy, not evidence that OFF matches today's physical package.

1. Acquire into a new owned directory; verify complete EOF/length/hashes, provenance and redistribution rights.
2. Compare source dates/counts, field rates, direct/legacy nutrition, representative sparse/rich/absent codes and dated live-count differences. Record unresolved gaps.
3. Replace tracked gzip/metadata/provenance/licenses and docs together after validation; retain only a deliberate owned local rollback copy when needed.
4. Run local suite/build/review and push the source. A new immutable deployment generates its own verified SQLite/receipt; no acquisition or database update runs in an API request.
5. Match production commit/source/date/hash/counts and receipt; verify status, identity/facts and existing APIs. Rollback selects the previous verified deployment/source/configuration. Packaged manifests are never hot-swapped.

There is no scheduled refresh job. Git keeps old source versions and repository history. Remove only verified owned temporary files after the rollback window.

## Finite budgets and offline boundary

The JSONL acquisition caps compressed transfer at 16 GiB, decoded stream at 160 GiB, source records at 16 MiB, projected records at 512 KiB, retained projection at 100 MiB and elapsed time at three hours. Older CSV acquisition retains its own smaller bounds. Bundle/source/SQLite limits remain 100 MiB; local immediate-work-directory defaults are 1 GiB. Check free disk separately for source and repository history. No image cache exists.

The hosted SQLite is an immutable function asset, not durable writable cloud storage. Actual v0.2.3 Vercel artifact size/read verification passed and is recorded separately from the local build. Backend-held facts avoid an upstream call but still need client-to-backend connectivity. Flutter has no catalogue/cache integration yet; saved dated results, preferences and glossary are later limited offline features. The separate v0.3.0 confirmed-label claim subset does not consume snapshot facts automatically. Scores, comparison and AI remain disabled. [API contracts](../../contracts/README.md) · [20-group tracker](../planning/FEATURE_TRACKER.md).
