# Unlabel on Oracle and Coolify

Project `Unlabel` and its production environment are on the Volcanica Oracle VM.
The backend domain is `https://unlabel.duckdns.org`. DNS resolves to the correct
VM. Resource identities are recorded in [resources.json](resources.json).

The private `unlabel` Docker destination isolates application data services from
the old shared destination. No database ports are published on the VM. Each
store has its own credentials, named resource and purpose in the Coolify canvas:

| Resource | Purpose |
| --- | --- |
| PostgreSQL app | Accounts, profiles, private sync, searchable catalogue and durable outbox |
| PostgreSQL auth | Self-hosted identity/session storage with separate ownership |
| MongoDB evidence | Immutable original/research document observations and receipts |
| Redis cache | Bounded expiring public cache and rate-limit counters, LRU eviction |
| Redis jobs | Streams transport, no eviction, AOF; durable intent stays in PostgreSQL |

All five stores reached healthy status on 14 November 2026. Creating containers
does not establish domain integration or cutover readiness. API/auth/worker
integration, importer parity, recovery and client acceptance remain required.
The existing production Vercel/Firebase release remains active until then.

## Secrets

Production credentials are generated locally under `.secrets/`, installed into
Coolify and backed up in the root age workflow. Never commit plaintext. Run
`secrets.ps1 encrypt` and `verify` after changing or adding credentials, and push
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
