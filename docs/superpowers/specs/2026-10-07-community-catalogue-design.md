# Backend v0.4.0: Community Product Catalogue

**Final implemented design, 7 October 2026.** Local source/API checks and live
Firebase synthetic checks are recorded in the [release review](../../planning/BACKEND_V0_4_0_REVIEW.md).
Push, hosted verification and publication remain separate pending gates. This
replaces the earlier per-scan consent/accepted-only prototype. The
[master plan](../../planning/MASTER_PLAN.md) retains the complete product direction.

## Goal and boundaries

Link exact barcode, confirmed front identity and corrected back-label public
facts so Indian packaged-product coverage improves through use. Structured
observations save automatically without a separate Share action. Anonymous write
authentication is behind the scenes. Camera/OCR/correction, client scheduling and
reports remain frontend/later-version work. No photos, raw OCR, profiles,
location or private history enter shared storage.

Preserve all eleven existing routes, the immutable OFF snapshot, seven reviewed
numerical claim types and current-label confirmation. Community assertions stay
separate from OFF and FSSAI knowledge. No generic composition imputation, health
score, custom model/training, Gemini dependency or mobile build belongs here.

## Observation lifecycle

Strict bounded `ContributionRequest` supports provisional/confirmed state,
optional exact barcode, ordered complete/partial label sections, original
nutrient rows/bases/preparation, identity, front claims and observation date.
Unknown remains unknown. Independent package transcription and CC0 license are
explicit; provider-prefilled data is represented by validated exact OFF snapshot
references, never copied as original community content.

The server computes normalization, full content hash and semantic factual hash.
Provisional, incomplete-pairing or barcode-less observations remain private
staging. Seven-day expiry plus bounded operator cleanup avoids paid TTL.
Confirmed exact identity/front/back/pairing with valid normalization is eligible
for a qualified public candidate when it does not conflict with current community
or OFF baseline evidence. Known conflicts/identity mismatches await review.

Same owned UUID and identical content returns its receipt; changed content
conflicts. Semantic duplicates reuse active facts without another public
revision or trust vote. Facts exclude UUID/date/opaque row IDs from their
fingerprint while retaining identity and table/revision context. Rejected or
superseded content is not automatically revived. Admission and receipt updates
are transactional: ten new submissions/subject/day, 200 globally/day, 10,000
lifetime admissions, ten staged records/subject and eight public revisions/barcode.
Lookup requires no write-based quota counter. Admission cannot guarantee provider
availability or unlimited free requests.

Authenticated owned receipts are private. Public lookup returns candidate and
approved assertions with `submitter_confirmed_not_moderator_reviewed` or
`moderator_accepted_community_assertion` evidence. Pending/provisional/rejected
records and ownership hashes are excluded. Credential-only CLI review targets an
exact content hash and explicit same-barcode supersession. Review is not current
packet verification or an allergy/compliance guarantee.

## Resolution and API

`resolve_product` retains OFF/community originals, comparisons and typed
`fields` with selected value or unknown/conflict, source IDs, evidence state,
completeness, source dates and alternatives. Keep ordered ingredient sections
whole. Nutrition cells require compatible basis, preparation and known revision;
unknown cross-source revision stays unselected. No average, first-arrival winner,
implicit density or provider score replaces evidence. Generic IFCT/INDB/USDA food
composition cannot fill packet gaps. Available OFF facts remain accessible during
a community outage with explicit source unavailability.

| Endpoint | Contract |
| --- | --- |
| `POST /v1/community/contributions` | Verified anonymous write; automatic provisional/confirmed observation and receipt |
| `GET /v1/community/contributions/{submission_id}` | Verified caller-owned receipt |
| `GET /v1/community/products/{barcode}` | Public exact candidate/approved facts |
| `GET /v1/products/{barcode}/resolved` | Typed derived fields plus whole source groups, conflicts and unknowns |

Actual 32 KiB JSON/chunk limits, strict numeric tokens, redacted 422 and no-store
responses apply. Typed failures cover 401, owned 404, 409, 429 and 503. Blocking
Firebase operations run in worker threads; lifespan closes the runtime.
`/v1/meta` exposes readiness capabilities with connectivity `not_checked`.

## Runtime and infrastructure

`Settings` uses `community_enabled` (default false), exact project ID, database
literal `unlabel`, secret service-account JSON and secret actor-hash key >=32
characters. `create_app` accepts typed runtime injection for tests; production
creates a dedicated runtime from explicit credentials. Tokens must be anonymous,
verified and not revoked. No implicit ADC/emulator shortcut is used.

Firebase display **Unlabel**, project `unlabel-india-catalogue`, first Standard
Firestore database **`unlabel`** in **Mumbai/asia-south1** is configured with
free-tier enabled and no linked billing. Anonymous Auth, deny-all client rules
and dedicated least-privilege backend access are configured. Track public web
config/rules/index exemptions; keep private credentials ignored/encrypted or in
hosted secrets. No paid Storage/Functions/TTL/backups/PITR or paid fallback.

## Validation and release

Contracts include v0.4.0 OpenAPI (15 routes), strict community/resolved schemas
and synthetic confirmed/provisional/receipt/lookup/failure/resolved examples.
Tests cover normalization, semantic dedup/retry/concurrency, private ownership,
moderation/supersession, quota, token/project/provider boundaries, source conflicts,
unknown revisions and partial outage behavior. Emulator and live synthetic
checks are separate evidence from mocks and hosted deployment.

Complete independent review, current Markdown/script/secret/static checks, then
push and verify exact hosted v0.4.0 and immutable source receipts before its
source-only publication. Preserve historical release tags and Flutter 0.0.0+1.
v0.5.0 Useful Label Report starts only after the v0.4.0 release boundary.

[Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
· [Firestore pricing](https://firebase.google.com/docs/firestore/pricing)
· [Community guide](../../architecture/COMMUNITY_CATALOGUE.md)
