# Backend v0.7.0 — Optional Scanner Sync

Implementation and independent source review passed. Source
`9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0` is pushed on `main` and reached
READY on backend deployment `dpl_5TNPc4yuis3tdLJ114jacroGvbvh` at
[unlabel-api.vercel.app](https://unlabel-api.vercel.app). Eighteen hosted synthetic
checks passed; GitHub publication and the documentation closure remain pending.
This version adds optional private scanner account sync while preserving
guest workflows and the separate automatic public product catalogue.

## Implemented scope

One additive `/v1/account/sync` resource provides GET and POST. Twenty route
paths retain all nineteen v0.6 paths and their response components unchanged.
`personal-sync-v1` uses a bounded strict profile/saved/history snapshot, verified
password-provider Firebase ID tokens and domain-separated owner HMACs. Anonymous
tokens remain accepted for public product observations and cannot access private
snapshots. There is no reviewer/admin account, permission claim or dashboard.

The existing named `unlabel` database, backend credentials and deny-all client
rules are reused. `ACCOUNT_SYNC_ENABLED=false` is the clean-clone default.
Public product reads and local app data require no personal login.

Compare-and-swap revisions, canonical data hashes, exact latest-mutation retry,
transactional admission, byte/count budgets and retained empty-snapshot revisions
protect against lost updates, duplicate writes, partial saves and deletion
resurrection. See the complete [private sync contract and recovery policy](../architecture/PRIVATE_ACCOUNT_SYNC.md).

## Implementation evidence

- The implementation's complete backend suite passed **931 tests**, with five emulator-only
  skips, in 24.80 seconds. The schema/store/HTTP/auth/contract checks exercise
  actual pinned SDK transaction code through a synthetic external
  RPC boundary, simultaneous devices, latest-mutation retry, owner isolation,
  corrupt provider data, real byte/count budgets, admission, revocation/project
  checks, sanitized query/body/number errors and unchanged old OpenAPI components.
- Both acquisition-script User-Agent values now identify 0.7. Their existing
  source/overwrite/locking tests pass with the version update.
- Pyright after the new route response-map annotation reports **0 errors and
  0 warnings**. Ruff checks and formatting pass for the affected implementation.
- Exporter produces a new v0.7.0 OpenAPI, three additive personal-sync schemas,
  three owned synthetic sync examples and **27** total validated examples.
  Historical OpenAPI files remain intact; current report examples identify 0.7.
- Fresh closure validation on 7 October independently passed **931 tests with
  five emulator-only skips** in **25.47 seconds**. Ruff is clean; root-configured
  Pyright reports **0 errors and 0 warnings**. Root script compilation, Git
  whitespace checks and **756 local Markdown links** also passed. This rerun
  preserves the earlier implementation evidence and does not claim emulator or
  physical-device execution.

## Hosted evidence and cleanup

Completed before the implementation push: independent review passed with 86 focused
tests, and local API checks against real Firebase passed 18 synthetic checks.
The separate [hosted production receipt](../research/BACKEND_V0_7_0_PRODUCTION.json),
dated 2026-10-07T11:42:22.263810Z, records another 18 checks against the production API.
They cover two password identities and one anonymous identity, owner isolation,
no-store, exact retries, revision conflicts, clear/delete protection and prohibited
personal fields. All temporary SDK identities were deleted and the synthetic
personal report snapshots were cleared. Empty revision-protection documents and
bounded counters remain to prevent stale resurrection; this is not deletion of
all Firestore documents. No real profile or scans were used. Email/password and anonymous providers
were enabled with the official Firebase CLI in the existing free project.
Local `.env` settings and authenticated `.env.age` ciphertext were refreshed;
production `ACCOUNT_SYNC_ENABLED` and public User-Agent were set for this deployment.

Read-only hosted rechecks confirm v0.7.0 health/meta, ready private-sync/catalogue
capabilities, exact agreement with the tracked twenty-path/twenty-one-operation
OpenAPI, preservation of all nineteen v0.6 paths and components, unauthenticated
private rejection with no-store responses, frontend-origin GET/POST preflight and
unchanged reviewed knowledge receipt hashes. Health readiness still reports external
provider connectivity as `not_checked`; it is not a generic live-provider guarantee.

## Remaining publication gates

- Complete the production receipt with the original implementation SHA,
  exact deployment identity and read-only recheck evidence. Keep tokens, passwords
  and private IDs out of tracked proof.
- Push documentation closure independently on `main`. Record its own commit/deployment
  and verify any replacement deployment; do not rewrite historical implementation proof.
- Publish backend source release separately from frontend. Do not rebuild
  Android/iOS binaries for this backend version.

Frontend v0.2.0 release work resumes only after this backend publication. Its
four-tab bottom bar is Home/Scan/Compare/Saved; Profile stays at the top right.

Camera/OCR, additional glossary evidence, universal scores, new data-source
acquisition, Gemini and model training are not part of this backend release.
Frontend comparison can compare compatible numeric facts without making a
universal health ranking. Native/mobile and real camera proof remain separate.
