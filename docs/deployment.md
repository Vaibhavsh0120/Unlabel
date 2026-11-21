# Deployment

The Vercel frontend is being connected to the Oracle/Coolify API while the
legacy Vercel backend remains available as a rollback target. The Oracle
replacement is not fully accepted: account/profile, recovery, worker and other
hosted/device flows remain outstanding. Keep the legacy backend and Firebase
resources until replacement verification and client acceptance pass. Track
remaining work in [the roadmap](roadmap.md).

## Endpoints and ownership

| Surface | Address or configuration |
| --- | --- |
| Public frontend | [unlabel-india.vercel.app](https://unlabel-india.vercel.app) |
| Legacy production API | [unlabel-api.vercel.app](https://unlabel-api.vercel.app) |
| New backend domain | [unlabel.duckdns.org](https://unlabel.duckdns.org), configured for the Coolify replacement; public TLS, API dependency health and identity health returned 200 on 16 November 2026 |
| Coolify project canvas | [Volcanica dashboard](https://volcanica-oracle.duckdns.org/dashboard/canvas) |
| Infrastructure resource references | [production resources](../infrastructure/production/resources.json) |

Resource UUIDs and public domains are identifiers, not credentials. Private
connection strings, SMTP keys, signing identities and machine credentials remain
in protected local files and the encrypted secret backup.

## Coolify target

The [production infrastructure guide](../infrastructure/production/README.md)
records provisioned resources and current deployment limits. The intended layout
uses separately named services within the Unlabel project and a private Docker
network:

| Component | Responsibility |
| --- | --- |
| Python API | Validated public reads, authenticated account operations and admission |
| Identity service | Email/Google sign-in, anonymous sessions and token management |
| Worker and scheduler | Durable leased jobs, notification delivery and maintenance |
| PostgreSQL | Separate app/identity databases and restricted roles, private sync, catalogue projections and durable outbox |
| MongoDB | Immutable source evidence and observations |
| Redis | Bounded disposable public cache and rate-limit counters |

PostgreSQL is the durable job authority; a separate Redis queue is unnecessary
for this design. Database ports stay private. API, worker, importer and identity
roles receive only their required grants. A single VM and a shared PostgreSQL
server remain shared failure domains; extra containers alone do not provide
high availability.

Coolify canvas connections should describe actual runtime dependencies. Keep
service names and descriptions understandable, and verify service health and
database access before treating a displayed edge as integration proof.

The Coolify resource is named **Sign-in service**. `unlabel-identity` is its
private Docker DNS alias for API-to-identity traffic, not a separate Unlabel
product or project. Logs showed startup crashes when PostgreSQL refused
connections; the container hit its five-restart cap. On 16 November, its restart
limit was disabled (`max_restart_count=0`) and a restart-only rollout rebuilt
the current image, passed the `/health` check and completed with zero restarts.
Current logs contain only GoTrue JWT-group deprecation warnings. This verifies
container recovery, not an end-to-end account sign-in.

## Configuration and secrets

Restore and verify [the encrypted inventory](../secrets/README.md) locally before
installing service-specific environment values. Runtime applications must not use
bootstrap database-owner credentials. Keep service secrets out of build arguments,
client defines, images and logs. After any local credential change, refresh and
verify the backup with `secrets/secrets.ps1` before pushing ciphertext.

Brevo supplies SMTP for the replacement identity service. A successful SMTP login
does not prove verification/reset mail delivery or link completion; test those
flows separately. The current operator-provided key has no configured expiry and
needs deliberate rotation when replaced. Never publish it in a handoff note.

The frontend embeds a public `BACKEND_BASE_URL`, never a shared backend secret.
The Vercel production target is Oracle with `UNLABEL_SELF_HOSTED_AUTH=true`.
Builds fail closed unless `/health/dependencies` reports PostgreSQL, MongoDB,
Redis and identity ready. The `/v1/platform` `cutover_ready` field remains
informational and does not block a build or client target; it currently reports
false, while hosted account/profile and other client acceptance flows remain
unverified. Coolify reports the API resource healthy on source commit
`7168f9c5208ccdb8d537e7b8ce4d4335ab3a93c6`. Public checks return ready for all
four dependencies and GoTrue over verified TLS. Live OpenAPI is version `1.0.0`,
and its 40 route/method pairs match the committed self-hosted contract. The
catalogue summary matches the tracked source SHA and counts (24,641 products,
243 observations). Keep the legacy Vercel API and Firebase resources available
for rollback until hosted account/profile, recovery and client acceptance flows
are verified. Retain legacy configuration and OAuth assets until ownership and
redirect behavior are verified.

## Remote development and recovery

Use the configured SSH host for the Volcanica VM. Coolify-generated application
configuration is under `/data/coolify/applications/<resource-uuid>` and database
configuration under `/data/coolify/databases/<resource-uuid>`. Docker volumes contain
runtime data. These locations are generated deployment state, not authoritative
source workspaces. In VS Code Remote SSH, connect to `Volcanica` and open
`/home/ubuntu/projects/Unlabel`. Edit the Git checkout, push
reviewed source and redeploy; do not rely on edits inside running containers.

Deploy exact source identities with bounded CPU/memory, health checks and reviewed
images. Confirm dependencies from inside the private network and inspect sanitized
logs on failure. Test database backup restoration into an isolated environment.
An age backup of credentials and a database Docker volume are not independent
backups of application data.

Run `python infrastructure/production/backup_platform.py --destination PATH`
from the operator's machine to create an off-VM age backup. Use a private folder
outside the checkout. The command streams both PostgreSQL databases, their role
definitions and MongoDB evidence through SSH. Only a set containing
`complete.json` has finished. Redis cache entries are disposable. See the
[production guide](../infrastructure/production/README.md) for verification and
the recurring backup gate.

## Cutover and retirement

The authentication correction requires profile migration `0008`, the patched
identity image `v2.197.0-unlabel.2`, API rollout, then frontend rollout. Follow
the ordered [authentication corrections](roadmap.md#authentication-corrections-being-verified).
The identity service needs `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED=true` and
`GOTRUE_EXPERIMENTAL_CREATE_EMAIL_IDENTITY_ON_PASSWORD_SET_ENABLED=true`.
Configure `GOTRUE_EXTERNAL_GOOGLE_SECRET` with the web client's existing secret;
keep it out of Flutter, build arguments and logs. Google's authorized redirect
must exactly match `https://unlabel.duckdns.org/auth/v1/callback`.

New client builds require the `selfhost-account-v2` dependency-health contract.
The API emits it only after checking the profile column and `.2` identity health.
Pushing source before this staged rollout therefore leaves the previous frontend
live; retry the frontend deployment after the backend passes that contract. This
checks account compatibility without asserting that overall cutover is accepted.

`/auth-callback.html` returns only a one-time code to its same-origin initiating
window. S256 PKCE binds the exchange to that window. `/account-recovery.html`
consumes the identity recovery grant, clears the URL before further requests,
updates the password through Oracle and ends the recovery session. Native email
links also finish in this web form. The Flutter app then requires a normal
sign-in. These pages have no-store, referrer and CSP headers.

Email signup/change links finish on `account-confirmation.html`; that page
discards the confirmation grant and returns to sign-in without activating an
account. Existing Firebase credentials are not imported into GoTrue.

The private `migration-runner` Docker target is a single-use operator process,
not an API or a schedule. It accepts only the recorded app database/migrator
destination, applies checksum-verified migrations and holds a health marker for
at most ten minutes. Remove its temporary Coolify resource and generated
configuration after checking migration/API health. Never install its owner DSN
into API, identity, notification or scheduler resources.

`python -m app.selfhost.acceptance --allow-synthetic-production-check` is an
explicit operator-only check inside the API container. It creates and removes
synthetic identities/private profiles, sends no email and makes no public
observations. It does not prove Google consent, SMTP delivery or device behavior.

Before changing the client endpoint, verify source-import parity, account isolation,
Google/email/reset flows, profile and sync behavior, notification delivery and
unsubscribe, guest expiry, background retry behavior, restart persistence and
backup restoration. Keep device-local guest data and public licensed sources intact.

The user permits discarding existing Firebase account/application data, but the
replacement must work first. After the new frontend/native release and hosted
checks pass, remove unused legacy Vercel backend resources, Firebase resources and
stale configuration. Keep the frontend deployment, necessary OAuth credentials,
source evidence and release assets. Review actual remaining dependencies before
deleting shared provider resources or changing other Coolify projects.
