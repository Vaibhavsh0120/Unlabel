# Remaining work

The Vercel frontend is being switched to the Oracle/Coolify API and its
self-hosted identity service. The legacy Vercel API and Firebase resources remain
available for rollback while hosted account/profile, recovery and other client
acceptance work is completed. A container or image build alone is not a
completed hosting migration.

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
| API | All eight Coolify resources are healthy. Public TLS, API dependency health and GoTrue health returned 200. Coolify reports source commit `7168f9c5208ccdb8d537e7b8ce4d4335ab3a93c6`; live OpenAPI is 1.0.0 and its 40 route/method pairs match the self-hosted contract. The catalogue summary matches the tracked source SHA, 24,641 products and 243 observations. `/v1/platform` still reports `cutover_ready: false`; hosted account/profile behavior remains unverified. This flag no longer blocks client builds. |
| Community/AI | Replace legacy and unfinished persistence adapters. Preserve admission, conflicts, immutable receipts, consent, quotas and provider boundaries. |
| Clients | Replace Firebase auth/profile access. Test web/native Google/email signup, linking collisions, recovery/expiry, sign-out, deletion and guest renewal. |
| Reminders | Deploy the Oracle scheduler/worker. Test leases, deduplication, retry, failed jobs and unsubscribe. No app schedules in GitHub Actions. |
| Canvas | Add actual API/worker/scheduler resources and labelled runtime connections with descriptions. |
| Security | Review auth dependencies, effective firewall, grants, request limits and redacted logs. Keep unfinished services private. |
| Recovery | Configure a recurring off-VM destination and repeat the verified restore process from that destination. |
| Performance | Measure queries, pools, concurrency, queue recovery, memory and disk. One VM is one failure domain. |
| UI | Ship prepared bell, recent-scan, Insights-height and sidebar fixes. Recheck themes, enlarged text and phone/tablet/desktop layouts. |
| Release | Canonical versions/contracts are now 1.0; web builds require healthy API dependencies but do not gate on `cutover_ready`. Complete hosted flows and device acceptance; keep source, artifact and physical-device proof separate. |
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
