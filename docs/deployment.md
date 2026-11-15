# Deployment

The currently serving application still uses the Vercel backend and Firebase.
The Oracle/Coolify replacement is incomplete and has not completed client cutover.
Vercel will continue hosting the frontend after the backend migration. Do not
remove the legacy backend or Firebase resources until replacement verification
and the client release have passed. Track remaining work in [the roadmap](roadmap.md).

## Endpoints and ownership

| Surface | Address or configuration |
| --- | --- |
| Public frontend | [unlabel-india.vercel.app](https://unlabel-india.vercel.app) |
| Legacy production API | [unlabel-api.vercel.app](https://unlabel-api.vercel.app) |
| New backend domain | [unlabel.duckdns.org](https://unlabel.duckdns.org), reserved for the Coolify replacement |
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
Update the actual Vercel build configuration, local runner and native workflow
endpoint selection together only when the replacement is ready. Legacy Firebase
configuration is under `infrastructure/firebase`; retain Google OAuth assets still
needed by the replacement until their ownership and redirect behavior are verified.

## Remote development and recovery

Use the configured SSH host for the Volcanica VM. Coolify-generated application
configuration is under `/data/coolify/applications/<resource-uuid>` and database
configuration under `/data/coolify/databases/<resource-uuid>`. Docker volumes contain
runtime data. These locations are generated deployment state, not authoritative
source workspaces. Edit a user-owned Git checkout through VS Code Remote SSH, push
reviewed source and redeploy; do not rely on edits inside running containers.

Deploy exact source identities with bounded CPU/memory, health checks and reviewed
images. Confirm dependencies from inside the private network and inspect sanitized
logs on failure. Test database backup restoration into an isolated environment.
An age backup of credentials and a database Docker volume are not independent
backups of application data.

## Cutover and retirement

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
