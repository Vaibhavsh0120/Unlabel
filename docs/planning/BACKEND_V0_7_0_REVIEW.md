# Backend v0.7.0 — Optional Scanner Sync

Implementation and independent source review passed. The production settings are configured;
the exact pushed deployment and publication remain pending. This version adds optional private scanner account sync while preserving
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

## Local evidence

- Final complete backend suite passed **931 tests**, with five emulator-only
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

## Required publication gates

Completed before the version push: independent review passed with 86 focused tests;
local API checks against real Firebase passed 18 synthetic checks for two password
identities and one anonymous identity, owner isolation, no-store, exact retries,
revision conflicts, clear/delete protection and prohibited personal fields. All
temporary SDK identities were deleted and the synthetic personal snapshot was
cleared. No real profile or scans were used. Email/password and anonymous providers
were enabled with the official Firebase CLI in the existing free project.
Local `.env` settings and authenticated `.env.age` ciphertext were refreshed;
production `ACCOUNT_SYNC_ENABLED` and public User-Agent were set for this deployment.

- Complete final backend suite/static/docs/scripts/contract/secret review.
- Update local encrypted environment and production flag deliberately; never
  commit plaintext credentials or a real scanner profile/history.
- Confirm Firebase email/password provider configuration using existing project
  access, without enabling billing or creating extra account roles.
- Run a scoped synthetic live check with two owned account identities and exact
  cleanup of test data/accounts; keep tokens, passwords and private IDs out of
  tracked proof. Local tests are not live Firestore evidence.
- Verify the exact pushed Vercel deployment's version/meta, original route
  contracts, unauthenticated/anonymous private rejection, owner isolation,
  latest-mutation retry, conflict/deletion behavior and client CORS.
- Publish backend source release separately from frontend. Do not rebuild
  Android/iOS binaries for this backend version.

Camera/OCR, additional glossary evidence, universal scores, new data-source
acquisition, Gemini and model training are not part of this backend release.
Frontend comparison can compare compatible numeric facts without making a
universal health ranking. Native/mobile and real camera proof remain separate.
