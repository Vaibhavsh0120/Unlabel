# Community Product Catalogue

The current backend retains the structured observation/resolution contracts;
the frontend integrates qualified capture, separate acceptance and automatic
confirmed intake. Versions come from the component manifests. The
[Google compatibility patch](../planning/BACKEND_V0_12_1_REVIEW.md) changes only the
verified provider allowlist. Machine extraction has its own private staging,
without automatic public promotion. [Current data flow](DATA_FLOW.md) ·
[AI boundaries](AI_ROUTING.md).

## Historical introduction — backend v0.4.0

**7 October 2026:** v0.4.0 was independently reviewed, pushed, hosted-verified and
published as a source-only release at `d793f628581f509481d6dc60a82afe59ca013439`.
[Sixteen hosted checks](../research/BACKEND_V0_4_0_PRODUCTION.json) matched the
unchanged OFF/claim receipts and cleaned synthetic records. Firebase **Unlabel**
has its first Standard database **`unlabel`** in Mumbai (`asia-south1`), free tier
and no linked billing. Anonymous Auth, deny-all client rules and dedicated
credentials are configured. [Review](../planning/BACKEND_V0_4_0_REVIEW.md) records
local, emulator, live Firebase and hosted evidence separately.

## Automatic observations

The API accepts bounded structured package observations without a separate Share
flag. The client integrates corrected confirmed intake after separate acceptance
of qualified captured fields. Anonymous Firebase authentication supplies ownership
without interactive login; Google/password scanners use their existing session. Useful
analysis remains available when authentication/quota/storage prevents saving.
There is no persisted generic public outbox or automatic uncertain-write replay;
immutable submission identity protects retries of the same submitted observation.

Identity, exact barcode when known, ordered ingredient/declaration text, front
claims and nutrient rows retain units, bases, preparation, completeness and date.
Photos, raw OCR dumps, profiles, location and private history are not accepted.
Provisional or barcode-less observations remain private, expire after seven days
and never appear in public lookup. Cleanup is a bounded credential-only command;
no paid TTL or background Functions are used.

A confirmed exact-barcode observation needs explicit confirmed front identity,
back facts and same-product pairing, independently transcribed package origin,
CC0 factual-data licensing and valid server normalization. Compatible facts can
become a public **submitter-confirmed; not moderator-reviewed** candidate.
Conflicts, changed identity or incompatible revision evidence remain pending for
review. Confirmation and review never prove allergy safety or the current
caller's packet. Unconfirmed extraction cannot become selected public facts.

The app has only scanner/client identities. There are no admin or reviewer app
accounts, role claims or dashboard. Guests use automatic anonymous scanner
authentication; optional Google/password accounts use their existing SDK session
for public writes. Separate private account sync derives ownership from verified
non-anonymous supported-provider tokens and never exposes
personal libraries through public facts. [Private account architecture](PRIVATE_ACCOUNT_SYNC.md). The dedicated service account is a backend machine
credential, not a person/user login. Existing exact-hash CLI operations are manual
maintenance; ordinary compatible facts qualify without a central reviewer queue.
Known conflicts remain unresolved until explicit maintenance or better evidence.

## Deduplication and review

Server content hashes preserve the full bounded observation. A separate factual
fingerprint excludes transport UUIDs, capture dates and opaque row/table IDs while
preserving table context. Identical retries return their receipt; changed content
under the same owned UUID conflicts. Identical active facts reuse the assertion
without making a new public revision or accuracy vote. Receipt/admission updates
remain bounded and transactional. A superseded or rejected revision cannot be
silently revived by rescanning an old formulation.

Conservative admission limits are ten new submissions per subject/day, 200/day
globally, 10,000 lifetime admissions and ten staged records per subject. At most
eight public candidate/approved revisions are active per barcode. Public lookup
uses no per-read write counter. These controls are not provider quota meters;
free service can become unavailable without any paid fallback.

The operator CLI lists pending records, inspects a revision, reviews an exact
expected content hash, optionally supersedes same-barcode revisions and cleans
expired staging. A moderator only reviews the structured assertion available;
photos are not retained for independent verification. Ownership hashes, tokens
and private receipt details never enter public responses.

## Sources and resolved fields

These four contracts were introduced alongside the eleven historical v0.3.0 APIs; they remain compatible in the current 27-path/28-operation API:

| Route | Behavior |
| --- | --- |
| `POST /v1/community/contributions` | Authenticated automatic provisional/confirmed intake and private receipt |
| `GET /v1/community/contributions/{submission_id}` | Authenticated caller-owned receipt; another owner receives 404 |
| `GET /v1/community/products/{barcode}` | Exact public candidate/approved assertions; provisional/pending/rejected records excluded |
| `GET /v1/products/{barcode}/resolved` | Separate OFF/community originals, typed usable fields, alternatives and conflicts |

Resolved fields retain source IDs, evidence state, completeness, package
observation dates or OFF modification dates and original table/row lineage.
Compatible missing identity/ingredient fields may complement one another.
Ingredient sections stay ordered and whole. Nutrition selection requires matching
basis/preparation and sufficiently known revision compatibility. Unknown
cross-source nutrition revision stays unselected with
`revision_compatibility_unknown`; disagreements never get averaged or selected by
first arrival. Complete original source groups and alternatives remain available.
An OFF snapshot can remain usable during a community outage or when storage is disabled, marked as partial
source availability. Neither source available returns 503.

Intake permits independently transcribed package sections and nutrition only.
Provider-prefilled OFF data uses validated references to an existing exact
snapshot for new records, retaining OFF attribution/license; identical immutable
retries remain valid after snapshot rotation or temporary unavailability.
Confirmation cannot relabel OFF data as CC0. Live OFF and the snapshot share one upstream origin. The separate research catalogue now includes qualified manufacturer/retailer website observations; these are not automatic confirmed contributions. USDA Branded integration remains future work. Generic IFCT/INDB/USDA foods
never supply missing branded-packet values. FSSAI supplies reviewed criteria,
not product facts. Current-label claim checks still require the caller's explicit
confirmed table and applicability context.

## Configuration and free operation

Project ID is `unlabel-india-catalogue`; display name is **Unlabel**. Clean clones
default to `COMMUNITY_ENABLED=false`. Enabling needs the exact project, database
`unlabel`, explicit backend service-account JSON and an ownership-hash secret of
at least 32 characters. Credentials stay in ignored/encrypted local settings or
hosted secrets; public web config is not an admin credential. No implicit ambient
credentials or auth/storage emulator shortcuts are accepted in production runtime.

Direct Firestore access to community and machine collections is denied, including
authenticated users. The separate [profile-media owner exception](ACCOUNT_PROFILE.md)
does not grant access to observations or library snapshots. Backend Admin access
uses dedicated least-privilege credentials and verifies anonymous/password/Google scanner tokens,
project/issuer/expiry and revocation. Sync SDK operations use worker threads;
runtime resources close on shutdown. Intake has an actual 32 KiB body limit,
strict raw JSON numbers and bounded redacted errors. Safe typed failures distinguish
401 authentication, 409 content conflict, 429 admission and 503 unavailability.
`/v1/meta` reports configured capability readiness with connectivity `not_checked`.

Keep Spark/no card/no billing, and do not enable paid Storage, Functions, TTL,
backups or PITR. [Firebase plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
and [Firestore pricing](https://firebase.google.com/docs/firestore/pricing) explain
free-tier boundaries. Live synthetic create/read/retry/review/cleanup and direct
REST denial were verified separately from hosted API deployment; see the review
for exact evidence and remaining gates.

[Master plan](../planning/MASTER_PLAN.md) · [Design](../superpowers/specs/2026-10-07-community-catalogue-design.md)
· [Implementation checklist](../superpowers/plans/2026-10-07-backend-v0.4.0.md)
· [Coverage strategy](../research/INDIAN_FOOD_COVERAGE.md) · [Operator commands](../../scripts/README.md)
