# Backend v0.2.1 review

Checked **6 October 2026**. Frontend remains v0.0.0+1. The [baseline repository review](PROJECT_REVIEW_V0_2_0.md) completes the earlier docs/files request; this record covers the new source and real acquisition.

## Real acquisition and import

The documented official global CSV URL returned 200 via OFF's S3 mirror. The actual 3,346-byte header and primary writer confirmed unquoted UTF-8 TSV. Compressed source length/checksum and gzip EOF were verified. Transfer ran from 05:15:46 to 05:22:19 UTC; no world file was retained. Source HTTP Last-Modified: **5 October 2026, 12:19:34 UTC**.

| Observation | Measured result |
| --- | --- |
| Compressed bytes consumed | 1,275,171,186 |
| Source rows scanned | 4,535,553 |
| Exact India-tagged rows | 21,188 |
| Corrected identity projection | 6,588,910 bytes |
| Supported unique indexed barcodes | 21,138 |
| Unsupported barcode rows | 50 |
| Exact duplicate supported barcodes / leading-zero equivalence collision groups | 0 / 0 |
| Missing names / ingredient text | 3,442 (16.28%) / 15,780 (74.65%) |
| Read-only SQLite file | 11,993,088 bytes, 11.44 MiB |
| Initial integrity/count validation | 21.27 ms |
| Warm rice-flour reads, 100 local samples | Median 0.334 ms; p95 0.548 ms |

Compressed source SHA-256: `f72687ee8bc6522054fe69dbfda6b91902c16af1ec2e043cde27bc6c29ad8176`. Decoded projection/import SHA-256: `9930e846978729e7fcbb753b1ef6ad1df2da8fa84bfbc94b43e3463bccaf6cc2`. These identify different artifacts. The projection was corrected locally to omit the legacy bare allergen column before hashing/import; the final tool also omits it. Original compressed source proof remains intact. Metadata and database live in ignored local storage; no corpus/image/private scan is committed.

Live India search reported **24,706** matches, exceeding this dated export's country count. The cause remains unresolved; source timing/schema/obsolete-record scope must be investigated rather than assuming equivalence. Rice flour `8904083506393` is found in both live and snapshot evidence. Chocolate `7622202842450` was live-found but is absent from this snapshot. Coverage is `unverified`, and missing fields remain unknown. Aggregate CSV nutrients, photos and per-record modification dates are omitted; no FSSAI eligibility or allergy safety is concluded.

Local ASGI checks against the actual index returned found200, absent404, invalid422 and enabled metadata without any provider call. Measurements are local source/store/ASGI evidence, not network/device/serverless performance. Peak acquisition memory was not reliably captured; code budgets bound reads/output, not a measured peak-memory guarantee.

## Source review and checks

Independent final review read all backend application modules, tests, three tools, new contracts and active documentation. Both confirmed source findings were rechecked with five focused regressions passing; remaining P3 active status/route-count drift was corrected before the push. Historical v0.1.0/v0.2.0 OpenAPI/product schemas and frontend source/version stayed unchanged.

Resolved confirmed findings:

- Default CSV quoting misread the official nightly TSV: primary-source dialect verification plus literal-quote regression.
- Bare legacy allergens could omit ingredient-derived tags: canonical column required; otherwise unknown.
- Acquisition could overwrite competing artifacts: exclusive lock, staged metadata and exclusive publication, with race regression.
- Two concurrent index builders could both report publication: exclusive owned import lock through replacement; busy/crash locks require operator review.
- Malformed Unicode in stored warning text could cause serialization500: model bounds reject it and API returns unavailable503.
- OpenAPI 422 differed from the custom error/middleware body: shared strict redacted schema and raw-number/truncation regressions.
- Whole-index integrity validation per lookup would scale with dataset size: verify/cached store at startup, short indexed transactions afterward.

Local verification: full backend **199 tests passed**, existing Starlette/HTTPX TestClient deprecation warning only. Ruff/source formatting and dependency consistency passed; current contracts generated from models and four synthetic examples validated. All **51 Markdown files / 180 relative links** were checked with zero missing targets; current OpenAPI and three new standalone schemas exactly match the application/models. Secrets/local projection/SQLite are confirmed Git-ignored. Flutter analyze and three widget tests passed during baseline review; no mobile build or feature change. Public deployment verification is recorded below when performed.

## Production gate

Pending source push/automatic deployment verification. The hosted index is intentionally inactive: `storage/runtime/` is ignored/excluded, and no full corpus acquisition occurs inside API requests or deployment builds. Production must keep existing live APIs ready and report catalogue inactive. A successful local import does not establish cloud artifact distribution.

## Remaining work

v0.2.2: explain coverage gap, select richer fields/provenance and implement reproducible free artifact packaging/distribution with actual hosted checksum/read proof. Thereafter implement the planned reviewed FSSAI subset, glossary/Hindi and neutral comparison. Frontend scanner/client/cache belongs to the teammate. Refresh policy is now **nine months** (target around July2027 for this source); no recurring job was scheduled and regulatory freshness is independent.
