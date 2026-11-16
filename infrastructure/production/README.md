# Unlabel on Oracle and Coolify

Project `Unlabel` and its production environment are on the Volcanica Oracle VM.
The backend domain is `https://unlabel.duckdns.org`. DNS resolves to the correct
VM. Resource identities are recorded in [resources.json](resources.json).
These identifiers are public resource references, not credentials. GitGuardian
incident 40084626 was confirmed to match the identity database UUID and marked
Not a secret (false positive). Credential values remain in the age backup only.

The private `unlabel` Docker destination isolates application data services from
the old shared destination. No database ports are published on the VM. Each
store has its own credentials, named resource and purpose in the Coolify canvas:

| Resource | Purpose |
| --- | --- |
| PostgreSQL - app and sign-in | One server, isolated `unlabel_app` and `unlabel_auth` databases and login roles. App data, catalogue, durable outbox and identity/session storage |
| MongoDB evidence | Immutable original/research document observations and receipts |
| Redis cache | Bounded expiring public cache and rate-limit counters, LRU eviction |
| Sign-in service | Private GoTrue identity API. Google, email and anonymous sign-in. Verified Brevo SMTP configuration |
| Guest cleanup - 7d retention | Private worker calling a fixed-policy, execute-only PostgreSQL function once a day |
| Unlabel API | Private staging API for catalogue, research, profiles and private sync |
| Web Push worker | Claims leased outbox jobs and delivers opted-in reminders |
| Reminder scheduler | Queues daily reminders on Oracle using a restricted PostgreSQL role |

The original five stores reached healthy status on 14 November 2026. After
consolidation, three database servers remain. The old identity PostgreSQL had
zero users and no other client connections; the old Redis queue had zero keys.
Both redundant resources were deleted after the shared identity database passed
actual anonymous sign-in, refresh and revocation checks and a healthy redeploy.
Jobs use PostgreSQL's durable leased outbox directly, so Redis is only for cache
and rate limits. App and identity roles were verified unable to connect to each
other's logical database. One PostgreSQL server remains a shared failure domain.

The existing production Vercel/Firebase release remains active while the
replacement completes the [cutover gates](../../docs/roadmap.md).

The initial GoTrue bootstrap wrote embedded migration receipts in `public`
before its role search path was installed. The version-specific alignment
migration moved the verified 75 receipts into `auth` and removed the duplicate
receipt table. A subsequent deployment passed its health check. This is recorded
separately from the application's own checksum-verified migration history.

See [guest lifecycle](../../docs/architecture/GUEST_SESSION_LIFECYCLE.md) for
seven-day inactive-guest retention and daily cleanup, account-conversion protection, permissions and test evidence.
The SMTP credential has no configured expiry and is recovered through the age
backup. Explicit credential rotation is still required when replacing it.

## Secrets

Production credentials are generated locally under `.secrets/`, installed into
Coolify and backed up in the root age workflow. Never commit plaintext. Run
`secrets/secrets.ps1 encrypt` and `verify` after changing or adding credentials, and push
the updated encrypted bundle/index. Resources were created with the local
passwords before first startup. Runtime roles and grants are a separate migration
step; bootstrap owners must not be used as API credentials.

## VM capacity and ownership

SSH checks found ARM64 Ubuntu, two CPUs, roughly 12GB RAM (10GB available), and
31GB free disk before the new stores started. Containers are bounded individually.
One VM remains one failure domain. Database backup/restore proof must precede
cutover; a local Docker volume is not an independent backup.

The retired `coolify-test-app` project was explicitly deleted at the user's
request, including its app, PostgreSQL database, exact volume and deployment
configuration directories. CrossWire remains a separate, running project.

## Backups and direct port access

The operator tool [backup_platform.py](backup_platform.py) streams encrypted
off-VM backup sets. A restore drill loaded both PostgreSQL dumps and MongoDB
evidence into disposable databases, compared row and collection counts to the
live stores, and removed the scratch databases. The role archive also decrypted
successfully. Set up a recurring off-VM destination and verify restoration from
it before switching public clients.

[close-direct-admin-ports.sh](close-direct-admin-ports.sh) restricts external
access to TCP 6001, 6002, 8000 and 8080 for both host and Docker traffic. The
Oracle systemd unit `unlabel-close-coolify-ports.service` reapplies the rules
when Docker starts. External checks verified SSH and HTTPS access, with the
direct admin ports closed. Coolify's HTTPS dashboard and CrossWire stayed healthy.
