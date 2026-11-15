# Guest session lifecycle

This policy belongs to the next-major self-hosted identity service. The existing
Firebase release remains active until the complete backend cutover is verified.

Guest access JWTs expire after 900 seconds. The client may refresh while in use.
An anonymous account with no identity, email or phone is eligible for removal
after seven days without account or session activity. Activity includes creation,
sign-in, account updates and refresh activity across every session. Email/Google
accounts and guests in the process of linking a provider are protected.

The private maintenance scheduler runs once a day, removing at most
100 eligible accounts in one transaction. A durable database guard prevents an extra cleanup after process restarts. This is a bounded cleanup cadence,
not an exact-to-the-second promise. PostgreSQL cascading foreign keys delete
their sessions and refresh tokens. The API checks the upstream identity/session
for protected requests, so a deleted guest cannot keep using an unexpired JWT.
Inactive visitors receive a new guest session when they return. Device-local
scans, saved items, preferences and inbox records are not deleted by this job.

## Permission and concurrency boundaries

The `unlabel_guest_gc` login has CONNECT on the identity database, USAGE on the
private `auth_maintenance` schema and EXECUTE on two maintenance functions only.
It cannot read users, password hashes, sessions or token tables and cannot choose
an arbitrary user or shorten the seven-day period. The fixed-policy cleanup is a
SECURITY DEFINER function owned by the non-superuser identity owner, with a
fixed search path and PUBLIC access revoked. The health function exposes only
a boolean indicating a successful run in the preceding 26 hours.

One transaction advisory lock prevents overlapping scheduler runs. Candidate
user locks skip a concurrent conversion or sign-in. Existing sessions are locked
without waiting; an active refresh causes that guest to be skipped. Activity
and conversion guards are checked again before deletion. A five-second statement
timeout bounds database work. Errors preserve transactional state and retry on
the next scheduled run. Logs contain only counts or a generic failure message.

## Setup and verification

After GoTrue has initialized its schema, run
`python infrastructure/production/configure_guest_cleanup.py` using the existing
loopback PostgreSQL SSH tunnel on port 15432. The helper applies checksum-recorded
identity migrations and installs the restricted login. Its random credential is
stored only in the ignored production secret inventory. Run `secrets/secrets.ps1 encrypt`
and `verify` before publishing the updated encrypted backup. Runtime deployment
uses `infrastructure/docker/guest-cleanup.Dockerfile`, a digest-pinned Python base,
hash-locked dependencies, a non-root user and a database-backed health check.

The real PostgreSQL integration cases cover expired-user/session/token
deletion, recent guests, recent refresh activity, converted accounts, partially
linked identities, 100-row bounds, execute-only privileges, competing user/session
locks and overlapping schedulers. Tests create a disposable database and role;
set `UNLABEL_TEST_POSTGRES_ADMIN_DSN` explicitly to run them. No existing identity
database is used as the test fixture.

An additional 14 November 2026 initial-policy smoke test exercised the actual private GoTrue
service: a synthetic guest received a 900-second JWT, was aged beyond its then-configured 24-hour retention,
was cleaned up, and then failed both `/user` and refresh-token requests. A fresh
guest remained usable and refreshed successfully. Both synthetic fixtures were
removed afterward. Local device data and physical-device guest recovery were
not exercised by this server test.
