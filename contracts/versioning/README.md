# Contract and component versions

Checkpoint **12 October 2026**: backend **0.12.0** exports **27 paths / 28
operations** and **30 validated synthetic examples**. API major/schema, adapter,
normalization, report and knowledge identities stay independent of product SemVer.
Frontend and backend each have one canonical version file. See
[release/versioning](../../docs/planning/RELEASE_VERSIONING.md) and the historical
[source ledger](releases.json).

Older contract notes below refer to their named releases.


Reserve the shared API-major/contract-schema definitions and release-manifest schemas here. The connected Flutter client declares `0.2.0+3` in `frontend/pubspec.yaml`; this version is locally validated with hosted verification/publication pending. The independently published frontend v0.1.0+2 remains its historical release. The manual release workflow injects the selected product version, build number and source commit into both mobile artifacts and records them in `build-manifest.json`.

Released production backend **v0.7.0** preserves API major 1, contract schema 1, product adapter 1 and the strict product/catalogue identity v1 responses. Its independent review, push, hosted verification and publication follow v0.6.0 discovery. The v0.7.0 export has **20 paths / 21 operations** and **27 validated synthetic examples**. Private account sync adds a separate capability and strict request/snapshot/failure models; it preserves existing public routes/components. Nutrition lookup and confirmed-row normalization retain their separate contracts and version metadata. Catalogue status/identity and the separate rich-facts response use a validated read-only SQLite snapshot; hosted activation also requires a verified build receipt. The `catalogue_facts` capability requires a facts-enabled store, while an older identity-only store remains readable without enabling facts. Live OFF product/nutrition reads remain separate from snapshot lookup.

Snapshot metadata records source format, export/index dates, hash, counts and coverage state. The current JSONL snapshot has **24,641 supported records**, with direct nutrition availability, canonical tag availability, record dates and attributed official image URL descriptors in its separate facts contract. An imported India-tagged source is not proof of every product sold in India or current package facts. Historical v0.1.0 through v0.6.0 OpenAPI files remain release records. Valid loaded claim knowledge reports `claims-2026-10-06.1` and enables the separate `claim_checks` capability. A verified bundle exposes its two-file `knowledge_artifact` receipt summary; direct canonical local loading has no artifact receipt. Released v0.5.0 enables `nutrition_analysis`/`label_reports` with `label-report-v1`; ingredient explanations depend on the bounded three-entry `ingredients-2026-10-07.1` glossary and its separate artifact. Backend comparison and AI stay disabled; frontend v0.2.0+3 supplies a conservative client-side comparison view. Confirmed claim assessments retain their selected table/context, input references, numerical-only scope and claim-specific statutory conversion metadata; normalization-v1 remains unchanged. Frontend source/web gates remain separate from native artifacts. [Current contracts](../README.md), [current v0.7.0 gates](../../docs/planning/BACKEND_V0_7_0_REVIEW.md), [frontend v0.2.0+3 checks](../../docs/planning/FRONTEND_V0_2_0_REVIEW.md) and [release/versioning](../../docs/planning/RELEASE_VERSIONING.md) distinguish completed backend checks from pending client publication and compatibility work.

v0.4.0 adds separate strict community/resolved models and four routes. Existing
product/claim/normalization contracts retain their versions. Public candidate
state is qualified evidence, not current-package confirmation. Regenerate actual
exports after changes; its hosted publication passed the separate
[v0.4.0 gate](../../docs/planning/BACKEND_V0_4_0_REVIEW.md).

v0.5.0 adds separate report/glossary models and three routes, leaving released
models intact. `user_confirmed_label` and `catalogue_historical` reports cannot be
substituted for each other. Sugar approximation `sugar-cubes-4g-v1` preserves the
original basis and never infers a serving. Glossary function metadata is partial
coverage, separate from claim knowledge and any health/allergy/compliance verdict.

v0.7.0 adds GET/POST `/v1/account/sync` for password-owned bounded private
display name/saved/history snapshots. The private-sync v1 models retain complete
historical report versions and expose explicit CAS conflicts and idempotent UUID
retries. Guests keep personal data locally; current public observations remain
automatic and distinct. Photos/raw OCR, UID/email and health preferences are not
sync data. Implementation source `9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0` and
later documentation-only closure `ec70568` remain separate release evidence.
