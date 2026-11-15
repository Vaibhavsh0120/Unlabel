# Remaining work

The published app still uses the existing Vercel API and Firebase identity/data
services. The Oracle/Coolify replacement is being implemented alongside it.
A container or image build alone is not a completed hosting migration.

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

## Before cutover

| Work | Current state and acceptance gate |
| --- | --- |
| API | Adapters in development. Finish endpoint parity, profile/sync CAS, owner isolation, real-store failure tests and HTTPS deployment. |
| Community/AI | Replace legacy and unfinished persistence adapters. Preserve admission, conflicts, immutable receipts, consent, quotas and provider boundaries. |
| Clients | Replace Firebase auth/profile access. Test web/native Google/email signup, linking collisions, recovery/expiry, sign-out, deletion and guest renewal. |
| Reminders | Deploy the Oracle scheduler/worker. Test leases, deduplication, retry, failed jobs and unsubscribe. No app schedules in GitHub Actions. |
| Canvas | Add actual API/worker/scheduler resources and labelled runtime connections with descriptions. |
| Security | Review auth dependencies, effective firewall, grants, request limits and redacted logs. Keep unfinished services private. |
| Recovery | Configure encrypted off-VM database backups and prove restoration. Encrypted credentials are not database backups. |
| Performance | Measure queries, pools, concurrency, queue recovery, memory and disk. One VM is one failure domain. |
| UI | Ship prepared bell, recent-scan, Insights-height and sidebar fixes. Recheck themes, enlarged text and phone/tablet/desktop layouts. |
| Release | Update canonical versions/contracts, publish web/APK/IPA and verify hosted flows. Separate source, artifact and physical-device proof. |
| Retirement | After tested cutover and recovery proof, remove the old Vercel backend, Firebase resources/adapters and stale configuration. Preserve the frontend and required Google OAuth clients. |

Existing Firebase accounts/data may be discarded at verified cutover. Public
source bundles, licenses, contract fixtures, historical tags and device-local
guest records are outside that scope.

## Acceptance limits

Camera accuracy and OS notification delivery require physical devices. Chromium
viewports do not establish Safari, Apple camera or LiveContainer acceptance.
External provider coverage is not proved by an installed key. An unavailable
Better Design quota is not a design approval. Keep release evidence in GitHub
releases, rather than accumulating dated plans/reviews in the maintained tree.
