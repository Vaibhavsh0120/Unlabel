# Backend 0.13.0 — owner account deletion and retry protection

Checkpoint: **13 October 2026, Asia/Calcutta**. This is an additive minor release:
`DELETE /v1/account/sync` adds account cleanup beyond the preceding Google-provider
compatibility patch. Canonical version is project.version in
[pyproject.toml](../../backend/pyproject.toml). The preceding
[0.12.1 review](BACKEND_V0_12_1_REVIEW.md) retains its own evidence; the current
[frontend release](FRONTEND_V0_9_0_REVIEW.md) has independent UI/provider checks.

## Contract and storage behavior

- The new DELETE operation requires a verified password/Google owner with recent
  authentication. Ownership comes from the verified UID and the existing
  domain-separated HMAC key. No caller UID, query parameters or request body are
  accepted. Responses remain private/no-store; failure details stay sanitized.
- One Firestore transaction replaces the bounded private library with a minimal
  permanent deletion marker, creates an owner profile-deletion marker, removes
  profile media and clears the reusable owner write counter. Stale or concurrent
  library uploads cannot recreate deleted content. Profile-media rules deny
  reads/writes after the marker; collection listing remains denied.
- Retrying a completed deletion performs no further document writes. A
  never-synced UID still needs markers to reject late uploads and consumes one
  slot in the same **512 lifetime-owner admission** budget. Existing admitted
  owners can always purge their stored data; tombstones do not reclaim admission.
  This bounds marker growth without adding TTL, backups, paid storage or billing.
- The frontend calls private cleanup before deleting Firebase Auth and only
  purges its verified owner-local namespace after confirmed Auth deletion. If
  Auth deletion fails after cloud cleanup, the private marker remains and a
  retry can finish; old client data must not re-upload into the deleted library.
- Existing GET/POST snapshots, CAS revisions, mutation retry identity and
  `personal-sync-v1` wire schemas remain unchanged. The actual account request
  body limit stays 512 KiB; library data stays 384 KiB, 50 saved/100 history.
  Verified Google compatibility, all catalogue records, research observations,
  image descriptors and report/extraction semantics remain intact.

Current OpenAPI adds one operation on the existing path: **27 paths / 29
operations**. The prior exports remain immutable. Capability metadata advertises
account deletion only with configured account-sync readiness; configuration
readiness does not establish live provider health.

## Verification and release boundaries

Local checks on **14 October 2026**: **1,420 passed / 5 optional emulator
checks skipped** in the full backend suite; all **35** runner/transport tests
passed. Ruff, Pyright (zero errors/warnings) and installed dependency checks passed. Six private-profile rules
checks passed on the loopback emulator, including deletion-marker isolation.
The complete suite passed again after script reorganization (1,420 passed); all
five optional community transaction tests also passed separately on the local
Firestore emulator. The current OpenAPI export matches the running application schema. The single warning is upstream Starlette/httpx deprecation,
not an application test failure. Existing contract and workspace checks passed.

Source `bd06bfb9dbf7307c9ccf6e9f2402a13ec3419084` was pushed and passed
[repository CI](https://github.com/Vaibhavsh0120/Unlabel/actions/runs/38512047538).
Production deployment `dpl_CXjqjPgTUtiE5ubHRQmWLxfeUa59` completed from that SHA.
The [hosted receipt](../research/RELEASE_2026_10_14_PRODUCTION.json) includes
version 0.13.0, matching OpenAPI, Google/password capability metadata, no-store
unauthenticated DELETE rejection and frontend DELETE preflight. It also verifies
unchanged catalogue counts and both claim-knowledge source hashes.
[Backend v0.13.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.13.0)
was published from the same source. No real account was deleted during verification;
provider consent and physical-device acceptance remain separate.

[Private sync contract](../architecture/PRIVATE_ACCOUNT_SYNC.md) ·
[Account/profile contract](../architecture/ACCOUNT_PROFILE.md) ·
[Release ledger](CONTROLLED_RELEASES.md).
