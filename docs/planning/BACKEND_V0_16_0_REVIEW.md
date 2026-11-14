# Backend 0.16.0 — browser notifications

14 November 2026. Canonical version: `backend/pyproject.toml`.

## Scope

Adds the bounded public `/v1/notifications` announcement feed and private
subscription/test endpoints. `/v1/notifications/push-config` reports initialized
availability and exposes only the public VAPID key. The scheduler dispatch route
requires a constant-time checked server secret and is excluded from OpenAPI.
The existing product, scanner, account and evidence APIs remain compatible.

Browser subscriptions are opt-in, authenticated using the existing scanner
identity boundary and stored in a backend-only Firestore document. Endpoint keys
authorize removal after an identity change. Capacity is 128 subscriptions, three
per actor, with bounded global writes and test-send frequency. No photos, product
details or passwords enter this store. Existing direct-client Firestore rules
need no exception. Unsubscribe removes the subscription; expired push endpoints
are removed after provider 404/410 responses.

Only established browser push-service hosts are accepted. HTTPS is required,
credentials/custom ports/fragments are rejected, outbound redirects are disabled,
request timeouts are bounded and each send uses encrypted Web Push with VAPID.
Daily delivery uses transactional leases, daily deduplication, bounded concurrency
and recoverable failed claims. Push transport acceptance is not device-delivery
confirmation. The Vercel Hobby schedule is daily with an hour-wide dispatch
window; the frontend describes that timing honestly.

Configuration is `WEB_PUSH_PRIVATE_KEY`, `WEB_PUSH_PUBLIC_KEY` and `CRON_SECRET`.
The key-pair setup utility never prints secrets. Production configuration was
added to the existing backend project, and authenticated `backend/.env.age` was
refreshed. No plaintext environment or private key is committed.

## Evidence

Full backend suite: **1,503 passed, 5 skipped**. Skips retain the existing external
integration gates. Targeted notification checks cover authenticated registration,
idempotency, unsubscribe after identity changes, capacity, SSRF destinations,
test rate limits, leases and duplicate daily dispatch. Public contracts are
exported in `contracts/schemas/backend-v0.16.0.openapi.json` and the notification
schemas; historical exports are preserved. The development proxy allowlist
includes the public notification operations and excludes the secret dispatcher.

Current hosting remains Vercel/Firebase. Full replacement with Coolify,
PostgreSQL/MongoDB/Redis and self-hosted authentication is a separate next major
version. This release neither imports nor discards existing Firebase data.
