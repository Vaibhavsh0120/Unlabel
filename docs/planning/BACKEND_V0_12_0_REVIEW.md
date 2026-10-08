# Backend v0.12.0: private proposals and richer researched lookup

Local implementation checkpoint, 8 October 2026. Source review is complete
on `main`. The user authorized independent publication after review/docs.
Hosted v0.12 verification is recorded below only after the deployment is observed.
The preceding v0.11.0 implementation remains
`578a9afebae8f77fe98344233cdc9155e82bb37a`, with observed READY deployment
`dpl_GYRcK2j22N2gY24Hsxk5pi8UH8rA` and 389 read-only public/API checks.
Its [production receipt](../research/BACKEND_V0_11_0_PRODUCTION.json) excludes
authenticated AI generation/failover, local v0.12.0 and native-device evidence.

## Private extraction proposals

`POST /v1/ai/extract` keeps the existing scanner authentication, consent, strict
photo/output validation and one globally active Gemini/OpenAI credential. The
response now includes an independent storage result. Literal structured facts,
unknowns and qualifiers may be saved as `private_unverified`; photos, geometry,
region text, raw OCR, prompts, provider envelopes and credentials are excluded.
This does not publish an observation or overwrite a canonical catalogue product.

Private `unlabel_machine_staging` uses 256 fixed actor-hash buckets, eight items
per bucket and at most 32 KiB of fact JSON per item. Identical actor/content
rescans deduplicate without changing the original timestamp. Seven-day expiry is
opportunistic on a later bucket write; old items are evicted when the bucket is
full. There is no paid TTL, scheduled retention guarantee, durable personal
library or public lookup API for these machine proposals. The fact payload bound
is approximately 64 MiB across all buckets, plus document metadata/overhead.

Authentication waits at most five seconds, extraction at most 48 seconds and the
private staging response at most three seconds. A timed-out idempotent staging
write may finish later. Staging failure or oversize yields `not_stored` with an
explicit reason while preserving useful extraction; it does not switch providers.
These bounds leave host response time and require separate hosted verification.

## Catalogue preservation and search

The original 24,641-product bulk SQLite and all 243 acquired research observations
remain preserved. The tracked research source bundle is unchanged. The derived
research search format is v3: ingredients, declarations and recorded front-label
claim/tag text join identity terms in the index. Search retrieves candidates; it
does not establish a verified claim, current formula, barcode or exact pack match.

The installed generated research bundle has 243 observations and byte-for-byte
unchanged original product rows. See the
[search preservation receipt](../research/RESEARCH_SEARCH_V3_PRESERVATION.json)
and [backup receipt](../research/CATALOGUE_PRESERVATION_2026_10_08.json).
SQLite remains the deployed read-only public catalogue. Validated source additions
and rebuilds change it; Vercel runtime filesystem writes cannot be the persistent
catalogue. Firestore retains mutable observations, account snapshots, global AI
selection and these bounded private proposals. No database migration or deletion
was performed.

## Real product-image descriptors

`app/research_catalogue/image_sources.json` adds separately validated source-image
descriptors to **120 of 243** research observations: 57 selected OFF front images
and 63 manufacturer/retailer listing images. **123 observations still have no
descriptor**. Exact observation/source/provider matching, reviewed HTTPS origins,
OFF canonical paths, raster content types and bounded source metadata protect
attachment. Immutable observation JSON is not rewritten; runtime reads metadata
and does not acquire image bytes.

The acquisition checked source association, HEAD 200, raster MIME and declared
size at most 2 MB. That dated check does not prove present remote availability,
current packaging or reuse rights. OFF descriptors retain CC-BY-SA-3.0 attribution;
other source owners retain image rights. Logos, SVGs, unreviewed origins and failed
checks were excluded. See the
[image receipt](../research/RESEARCH_PRODUCT_IMAGES_2026_10_08.json).

## Verification state

The full backend suite passed **1,319 tests with five explicit provider/emulator
skips**. The final runner/model-header suite passed **31 tests**, including one
additional inline-fetch regression added afterward. Ruff and Pyright are clean.
The contract exporter validated 30 synthetic examples. All tracked Python/JSON
and Markdown local links passed the workspace validator. The new OpenAPI snapshot remains at 27
paths/28 operations; the response/model changes must be exported together.

The existing owned Gemini synthetic check is separate from real-package
accuracy, OpenAI generation, native camera behavior and hosted v0.12.0 proof.
The user has authorized the reviewed component push. Hosted v0.12.0 proof is a
separate receipt; local checks alone do not establish that deployment.

See [AI architecture](../architecture/AI_ROUTING.md),
[frontend v0.6 local review](FRONTEND_V0_6_0_REVIEW.md) and
[privacy](../SAFETY_PRIVACY.md).

The source rebuild verifies both v2 and v3 generated receipts, backs up the
previous bundle by its hash, preserves every retained immutable observation and
rejects missing/changed rows, corruption or concurrent changes. Runtime still
requires v3. No user catalogue is discarded to make an upgrade pass.
