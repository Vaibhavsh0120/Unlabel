# Remaining work

The frontend stays on Vercel. Oracle/Coolify runs the API, sign-in service,
workers and private stores. The operator deleted the old Vercel backend and
confirmed there are no real users to migrate. Preserve licensed source data,
historical releases and device-local libraries.

## Verified foundation

- One private PostgreSQL server, one MongoDB server and one Redis server remain.
  Redundant identity PostgreSQL and Redis queue resources were removed after
  checking they held no users or queued work.
- Application and identity databases have separate connect roles. MongoDB owns
  immutable source evidence; Redis owns expiring cache/rate limits. Durable jobs
  use PostgreSQL.
- Licensed catalogue and research inputs were imported directly with source
  hashes and record checks. The replacement has no SQLite runtime.
- Private auth passed anonymous signup, refresh, logout and revocation checks.
  Brevo SMTP authentication succeeded; end-user mail delivery is a separate gate.
- Guest retention is seven days of inactivity with a durable daily cleanup guard.
  Access JWTs expire after 15 minutes. Accounts and device-local data are protected.
- There is an encrypted off-VM backup. Disposable restore checks passed for both
  PostgreSQL databases and MongoDB. The Oracle firewall blocks direct admin ports.

## Before cutover

| Work | Current state and acceptance gate |
| --- | --- |
| API | Coolify API and all dependencies are healthy. Hosted guest sessions, password login, profile writes/conflicts, account isolation, library reads and deletion passed. See release evidence for source identities; broader cutover remains separate. |
| Community/AI | Replace legacy and unfinished persistence adapters. Preserve admission, conflicts, immutable receipts, consent, quotas and provider boundaries. |
| Clients | Replace Firebase auth/profile access. Test web/native Google/email signup, linking collisions, recovery/expiry, sign-out, deletion and guest renewal. |
| Reminders | Deploy the Oracle scheduler/worker. Test leases, deduplication, retry, failed jobs and unsubscribe. No app schedules in GitHub Actions. |
| Canvas | Add actual API/worker/scheduler resources and labelled runtime connections with descriptions. |
| Security | Review auth dependencies, effective firewall, grants, request limits and redacted logs. Keep unfinished services private. |
| Recovery | Configure a recurring off-VM destination and repeat the verified restore process from that destination. |
| Performance | Measure queries, pools, concurrency, queue recovery, memory and disk. One VM is one failure domain. |
| UI | Ship prepared bell, recent-scan, Insights-height and sidebar fixes. Recheck themes, enlarged text and phone/tablet/desktop layouts. |
| Release | Prepare v1.1.1 from canonical component manifests. Web builds require healthy API dependencies. Complete hosted flows and device acceptance before release; keep source, artifact and physical-device proof separate. |
| Retirement | After tested cutover and recovery proof, remove the old Vercel backend, Firebase resources/adapters and stale configuration. Preserve the frontend and required Google OAuth clients. |

## Account deployment

The app uses one self-hosted account path. Email/password signup immediately
signs in: `GOTRUE_EXTERNAL_EMAIL_ENABLED=true` and
`GOTRUE_MAILER_AUTOCONFIRM=true`. The API sends a separate welcome email through
Brevo after successful signup. Mail failure does not block account activation.
Password recovery and email changes still use their own secure links.

Web Google uses the web OAuth client secret in the sign-in service, with
`https://unlabel.duckdns.org/auth/v1/callback` as its exact Google callback.
A browser API key and a client ID cannot replace that secret. Keep explicit
provider linking and the pinned `.2` identity policy.

Schema updates through `0010_ai_persistence.sql` were applied with transaction,
lock and checksum checks on 21 November. The stopped **Account migration -
temporary** resource was deleted. This was database preparation, not migration
of existing users. Future schema updates use the existing one-shot operator
runner; do not keep a migration service running.

Deploy API changes before the frontend, check dependency health, then check
signup, Google, recovery and profiles. Frontend builds check live dependencies;
they no longer require the redundant account-migration marker. Other production
gates below remain independent of that build check.

The Google Cloud project also owns the required OAuth clients. Retain those
clients when removing Firebase-specific resources.

## Acceptance limits

The v1.1.1 source update is being verified; the version number does not certify
deployment or retirement. Its release requires successful CI, the ordered hosted
account rollout above and the remaining cutover gates. The first disposable
PostgreSQL run found missing outbox conflict-key SELECT grants; migration 0009
repairs this without exposing job payloads. The frontend build failure came from an old deployed API and a redundant
account-contract marker check. Deploy the current API before publishing clients.

GitGuardian incident 40814799 identified a synthetic password in a fully mocked
recovery test. It was never a service credential. Recovery and password-change
test inputs are now generated at runtime; the historical incident needs to be
classified as a test fixture/false positive in GitGuardian.

Camera accuracy and OS notification delivery require physical devices. Chromium
viewports do not establish Safari, Apple camera or LiveContainer acceptance.
External provider coverage is not proved by an installed key. An unavailable
Better Design quota is not a design approval. Keep release evidence in GitHub
releases, rather than accumulating dated plans/reviews in the maintained tree.
