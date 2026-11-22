# Deployment

Vercel hosts the Flutter frontend; Oracle/Coolify hosts the API, sign-in service,
background work and private stores. The operator deleted the old Vercel backend.
There are no real accounts to migrate. Keep public source data, historical
releases, required Google OAuth clients and device-local libraries intact.

## Endpoints and ownership

| Surface | Address or configuration |
| --- | --- |
| Frontend | [unlabel-india.vercel.app](https://unlabel-india.vercel.app) |
| API and API docs | [unlabel.duckdns.org](https://unlabel.duckdns.org/docs) |
| Coolify | [Volcanica dashboard](https://volcanica-oracle.duckdns.org/dashboard/canvas) |
| Service identifiers | [production resources](../infrastructure/production/resources.json) |

Use `main` for changes. Update relevant docs, run affected checks, push, deploy
API changes before the frontend, and check the deployed commit and public flows.
Resource UUIDs are identifiers, not credentials.

The Coolify API tracks `main` with `git_commit_sha=HEAD`. Check the resolved SHA
in each deployment: pinning an older SHA makes redeploy reuse the old image even
after source changes have been pushed. Rollbacks are separate deliberate actions.

Browser access permits only the configured frontend origin. Keep `GET`, `POST`,
`PUT` and `DELETE` in the API CORS method list: web password/profile updates use
`PUT` and require an unauthenticated preflight with Authorization/Content-Type.
Direct API tests alone do not prove the browser can send those updates.

## Active services

| Component | Responsibility |
| --- | --- |
| Python API | Product reads, account/profile/sync operations and admission |
| Sign-in service | Email/Google login, anonymous sessions, recovery and tokens |
| Worker and scheduler | Durable notifications and periodic work |
| Guest cleanup | Seven-day inactive anonymous-session retention |
| PostgreSQL | Isolated app/identity databases, catalogue projections and durable jobs |
| MongoDB | Immutable source observations and evidence |
| Redis | Disposable cache and rate limits |

Keep one instance of each existing resource; no separate Redis queue or migration
service is needed. The stopped **Account migration - temporary** resource was
removed after applying the required schema updates. The reusable migration runner
is an operator command, not a permanent application. Database ports stay private;
application containers never receive the database-owner credential.

## Sign-in and mail

| Sign-in service variable | Value or purpose |
| --- | --- |
| `GOTRUE_EXTERNAL_EMAIL_ENABLED` | `true` |
| `GOTRUE_MAILER_AUTOCONFIRM` | `true`: immediate email/password signup |
| `GOTRUE_JWT_DEFAULT_GROUP_NAME` | `authenticated`: required scanner token role |
| `GOTRUE_EXTERNAL_GOOGLE_ENABLED` | `true` |
| `GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID` | Existing web client first, then native audiences |
| `GOTRUE_EXTERNAL_GOOGLE_SECRET` | Web OAuth client secret; runtime only |
| `GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI` | `https://unlabel.duckdns.org/auth/v1/callback` |
| `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED` | `true`: explicit owner linking |
| `GOTRUE_EXPERIMENTAL_CREATE_EMAIL_IDENTITY_ON_PASSWORD_SET_ENABLED` | `true` |

Google's authorized redirect must exactly match the callback above. A client ID
or Browser API key is not an OAuth client secret. Ordinary web login uses a same-tab Google redirect and S256 PKCE, with a
five-minute verifier in session storage. Its callback clears the code from the
URL before returning to Unlabel. Native Google uses the platform SDK's ID token.
Retain the pinned `.2` identity policy that prevents automatic email-based merges.

Email signup immediately activates the account and sends no verification email.
The API sends a separate **Welcome to Unlabel** message after successful new
email signup. Configure its runtime-only `UNLABEL_SMTP_HOST`, `UNLABEL_SMTP_PORT`,
`UNLABEL_SMTP_USER`, `UNLABEL_SMTP_PASSWORD` and `UNLABEL_SMTP_SENDER` with the
existing Brevo settings. Sending happens after the response, retries once and
logs only status. Delivery is best effort and never blocks account use.
GoTrue retains its SMTP configuration for password recovery and email changes.

`account-recovery.html` clears the grant, accepts a new password, ends the recovery
session and returns to ordinary sign-in. `account-confirmation.html` remains for
verified email changes and older links. Existing Firebase passwords are not
imported. See [account ownership](architecture/ACCOUNT_PROFILE.md).

## Build and rollout

The frontend embeds the public `BACKEND_BASE_URL=https://unlabel.duckdns.org` and
`UNLABEL_SELF_HOSTED_AUTH=true`; it embeds no shared backend secret. The build
checks that `/health/dependencies` reports PostgreSQL, MongoDB, Redis and identity
ready. It does not depend on a temporary migration app or an account-migration
marker. Runtime health checks still verify the actual profile schema and identity
policy. `/v1/platform` records broader acceptance separately.

Vercel restores pinned dependencies, checks bundled assets, analyzes and compiles.
Full browser-script/Flutter suites belong to the existing maintenance/release CI
and affected local checks, avoiding a duplicate full test run on each deploy.

Schema updates through `0010_ai_persistence.sql` were applied on 21 November with
transaction, advisory-lock and checksum verification. Future schema updates use
the existing checksum runner once; do not leave an operator process running.

After deploy, check public dependency health, immediate signup/password login,
Google redirect and completion, recovery, profile/sync ownership, search and
product images. Container health, SMTP acceptance, inbox delivery and native
device behavior are separate evidence. Remaining work is in [the roadmap](roadmap.md).

## Secrets and recovery

Recover and refresh credentials through [the encrypted inventory](../secrets/README.md).
Keep SMTP/OAuth/database secrets out of client defines, build arguments and logs.
Run `secrets/secrets.ps1 encrypt` after local secret changes and verify the backup.

For remote maintenance, SSH to `Volcanica`. Coolify-generated files are under
`/data/coolify/applications/<uuid>` and `/data/coolify/databases/<uuid>`; these
are generated state, not the source checkout. Source changes belong in Git.

Create an off-VM encrypted backup with
`python infrastructure/production/backup_platform.py --destination PATH`.
Only a set with `complete.json` has finished. Verify restoration in isolation.
A Docker volume is not an independent backup. The VM remains one failure domain.

Check remaining Firebase dependencies before retirement. Preserve necessary
Google clients, public licenses/evidence and published native assets.

The auth proxy accepts Google's `iss=https://accounts.google.com` callback
parameter and rejects another issuer. Google now returns this parameter during
web authorization; omitting it from the query allowlist produces `invalid_query`.
