# Backend v0.4.0 review: Community Product Catalogue

Reviewed on **7 October 2026**. This version makes useful public package facts
durable and reusable. Flutter remains **0.0.0+1**. Publication and hosted checks
are recorded separately below; local validation is not deployment proof.

## Implemented boundaries

- Four additive routes save automatic observations, retrieve owned receipts,
  read qualified exact-barcode facts and resolve compatible sourced fields.
- Confirmed original package facts can qualify as explicitly unreviewed
  candidates. Provisional/unmatched data stays private and expires from staging
  after seven days. No photos, raw OCR, personal history or profiles are accepted.
- Semantic hashes exclude transport UUIDs, row IDs and observation dates.
  Immutable retry receipts remain private; A → B → A requires a new revision
  association. Conflicting candidates are withdrawn until explicit review.
- Whole ordered ingredient/declaration sections and original nutrition tables
  remain intact. Selected fields carry source, dates, evidence and alternatives.
  Unknown reformulation cannot synthesize a complete cross-source panel.
- OFF origin/license remains separate from original CC0 package assertions.
  A historical candidate never confirms the current caller's package for claims.
- Intake uses verified anonymous Firebase tokens, HMAC ownership, a 32 KiB actual
  body limit, strict numeric parsing and bounded redacted errors. Provider calls
  use deadlines and bounded retries; no per-read write counter is used.
- Admission is limited to ten new receipts per actor/day, 200 globally/day and
  10,000 lifetime; staging allows ten per actor. These limits are application
  controls, not billing meters or a promise of uninterrupted free availability.

## Firebase and credential evidence

Project **Unlabel** (`unlabel-india-catalogue`), first Standard database
**unlabel**, location **asia-south1**, was provisioned with `freeTier: true`.
Cloud Billing reported `billingEnabled: false` and no linked billing account.
Anonymous Auth, deny-all direct-client Firestore rules and blob index exemptions
were deployed. No Storage bucket, Functions, TTL, PITR or paid backup was added.

The dedicated backend service account has `roles/datastore.user` and
`roles/firebaseauth.viewer`. Its private credential and ownership secret are in
ignored `backend/.env`, encrypted into tracked `backend/.env.age`, and configured
as sensitive production environment variables. Public Firebase client settings
are tracked separately. Plaintext credentials are never exported in contracts.

Live synthetic checks verified anonymous token validation, explicit database
write/read/delete, immutable retry, candidate lookup and exact-hash approval.
Authenticated direct-client Firestore GET/PATCH both returned 403. Owned synthetic
records were removed; aggregate admission counters remain. These checks establish
this project's behavior, not Indian-market coverage or transcription accuracy.

## Local verification

- Full backend suite after review fixes: **701 passed, five emulator-only cases
  skipped**; the five real emulator cases passed separately.
- Five real Firestore emulator cases passed separately: concurrent retry and
  restart, review/supersession, cross-actor deduplication/private receipts,
  conflicting candidates and expired staging cleanup.
- Pyright 1.1.414 over maintained backend, tests and scripts: **zero errors and
  warnings**. Ruff/format, dependency consistency and whitespace checks passed.
- Actual backend setup restored locked dependencies and reused the verified
  24,641-product index with measured progress bars. Networkless build verified
  the existing OFF source and both canonical reviewed-claim files.
- Contracts export 15 routes, five community schemas and six new synthetic
  examples while preserving historical OpenAPI and identity contracts.
- Independent review repaired candidate re-entry after conflict, derived-snapshot
  storage bounds, provider-dependent immutable retries and OFF-only resolution
  during community outages. All current Markdown/scripts are reviewed against
  implementation; historical review evidence stays dated.
- Flutter analysis found no issues and all three existing tests passed.
- Parsed all 75 maintained Python files and 65 JSON files; Markdown links and
  both PowerShell entry points passed validation. No dead-code removal was
  justified beyond replacing the superseded opt-in/prototype behavior.

## Hosted verification and publication

Implementation **d793f628581f509481d6dc60a82afe59ca013439** was pushed separately.
Backend deployment **dpl_8oGRZz2v6WZgnkQkBi9ShrAkdWNB** and frontend deployment
**dpl_DrcUBiaR7s3e9uRTpo2owuF1vjZG** reached READY for that exact commit.
**16 hosted HTTP checks passed**: version/metadata/OpenAPI, existing source
receipts, automatic candidate saving, immutable retry, own receipt isolation,
public sourced resolution, review and semantic deduplication. Both canonical
claim files matched the hosted receipt; the catalogue retained its validated
source hash and 24,641 products. Synthetic product records and Auth users were
removed after testing; aggregate admission counters were retained.
[Dated hosted evidence](../research/BACKEND_V0_4_0_PRODUCTION.json).

The separate [source-only v0.4.0 release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.4.0)
targets the tested implementation. No APK/IPA was rebuilt and historical tags
were preserved. Frontend capture, source views and background saving remain
integration work. Proceed to v0.5.0 as a separate useful report version.

[Release notes](BACKEND_V0_4_0_RELEASE.md) ·
[Architecture](../architecture/COMMUNITY_CATALOGUE.md) ·
[Master plan](MASTER_PLAN.md) · [Feature tracker](FEATURE_TRACKER.md).
