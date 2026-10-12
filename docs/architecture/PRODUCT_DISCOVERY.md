# Product Discovery v1

Current backend **v0.12.0** and frontend **v0.7.0+11** preserve this bulk-snapshot
search contract and integrate a separate 243-observation research search. The
current repository caches bounded public search reads for 60 seconds and report/
research details for five minutes, deduplicates in-flight reads and keeps them
separate from private saved/history libraries. [Catalogue](CATALOGUE.md).

Backend v0.6.0 adds `GET /v1/catalogue/search` using the same dated OFF snapshot.
This finds identity candidates. It does not recognize a front photo or confirm
the current package, variant/reformulation, nutrition or allergen safety.

`q` is bounded to 128 characters/eight words/64 characters per token. Unicode
NFKC/casefold normalization retains Indic letter/number/combining-mark runs.
Punctuation separates words. All words except the last match exact tokens; the
last is a prefix of at least two characters. Original names/brands/quantity text
stay unchanged. Quantity words are discoverable; there is no invented OFF variant.

`limit` is 1–20 (default 10). `cursor` is a bounded opaque continuation tied to
the normalized query, limit, search format and snapshot. Results use deterministic
barcode ordering, not a fabricated relevance score. A stale/cross-query cursor
returns redacted 422; start a fresh query after replacing a snapshot.

The optional search tables store exact/prefix postings, term counts and format
metadata. Reads select the smallest posting anchor, cap candidate work at 1,000,
intersect indexed identities and impose a SQLite instruction budget. SQL uses
parameters. There is no JSON full scan or live OFF request on a search miss.

Regular searches have a one-million SQLite VM instruction limit. Initial index
validation and validation after a changed snapshot/source/index timestamp have a
separate 50-million-instruction limit. The real 24,641-product index used 8.295
million instructions and 0.268 seconds for that full validation. Checks include
posting counts, key relationships and index format. A failed validation disables
search; existing exact barcode paths remain independent.

| State | Meaning |
| --- | --- |
| `ready` | Bounded matching set; identity candidates, exact matched count, ambiguity and optional next cursor |
| `not_found` | Checked index has no match; try another name/brand or enter the label |
| `refine_query` | Query is too broad for the work budget; add a more specific word |
| `unavailable` | Index absent, malformed or unavailable; barcode/report paths remain separate |

Every candidate includes only identity fields, its exact OFF source ID and
qualifiers. The existing Manifest carries snapshot/export date, source hash,
licenses and attribution. A lone candidate still needs package identity checking.
Community-only products remain outside this bulk-snapshot index. The separate
`/v1/researched/products/search` route searches qualified name/brand and ingredient/claim
research fields; results retain original sources/unknowns and do not confirm a label.

The Manifest schema and SQLite application/user versions stay compatible. Optional
index absence disables search without breaking old exact identity/facts reads.
Build receipts hash the whole generated database, including search tables.
Ordinary setup upgrades an index built from the same tracked source when search
is absent; a different valid local snapshot is preserved unless explicitly replaced.
Progress reports real validation/index stages, not invented download percentages.
