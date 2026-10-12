# Optional scanner account sync

Current backend **v0.12.0** and frontend **v0.7.0+11** preserve the account
contract introduced in backend v0.7.0/frontend v0.2.0. Device-wide dietary/allergen
reminders, appearance, Welcome completion and Insight bookmarks are outside this
snapshot and stay separate from scanner account namespaces.

Backend v0.7.0 adds `personal-sync-v1`. Guest product lookup, manual label analysis,
public product observations and local libraries keep working without a personal
account. A scanner may sign in with Firebase email/password to sync a private
profile, saved reports and history. There is one scanner role and no admin or
reviewer login. Email/password credentials stay with Firebase Authentication;
the API never accepts passwords or stores email in its profile document.

The `ACCOUNT_SYNC_ENABLED` flag defaults to false and requires the existing
configured Firebase runtime. `/v1/meta` advertises readiness, version and limits.
A ready flag means configuration loaded, not that a live provider was checked.
Anonymous Firebase identities remain valid for automatic public observations,
but cannot read or write personal snapshots. Password identities can do both.

## API and client recovery

`GET /v1/account/sync` requires a bearer ID token. There is no UID path/query
parameter. The backend checks signature, project/audience/issuer, subject,
expiry, disabled/revoked state and `sign_in_provider: password`, then derives a
domain-separated HMAC document key from the verified UID. Private and public
ownership hashes differ. Responses always use `Cache-Control: no-store`.
The existing ownership secret must remain stable; rotating it requires a planned
private-owner migration or old snapshots will no longer be addressable. Never
rotate it as routine setup work.

The response has `schema_version: "1"`, `sync_version: "personal-sync-v1"`,
`revision`, `updated_at` and `data`. An account with no snapshot returns revision
zero, null update time, an empty profile and empty libraries. `data` contains:

- `profile: {display_name: null | string}`; visible text, 1–80 characters.
- `saved`: at most 50 records.
- `history`: at most 100 records.

Each record has a UUID `entry_id`, timezone-aware ISO `recorded_at` and a complete
strict `label-report-v1` document. Report source/basis/unknown/conflict information
is retained. This is storage of a user library, not a new verified product source.
Captured photos/image bytes, raw OCR, passwords, tokens, arbitrary metadata and
unmodeled fields are not accepted. Existing validated official product-image URL
descriptors inside historical report sources retain their original contract.
Generated report ingredient/allergen text is part of the private
food report; it never becomes an allergy-safe verdict.

`POST /v1/account/sync` replaces the complete snapshot with
`{schema_version: "1", expected_revision, mutation_id, data}`. All reads happen
before writes in one Firestore transaction. A successful changed snapshot
increments revision. The latest identical mutation ID, expected revision and
canonical data retry returns the same result. Reusing that mutation with changed
data conflicts. Sending unchanged data with the current revision returns the
existing snapshot without document writes. Only the latest mutation receipt is
retained; an older retry after a newer change conflicts safely.

On HTTP 409, the client receives `account_revision_conflict` and
`current_revision`, without the other snapshot's personal data. It must fetch the
latest snapshot and let the scanner choose the remote data or explicitly replace
it with local data using that fetched revision. Never silently merge whole
snapshots. If another device changes it again, the retry conflicts again.
Uncertain timeouts keep the same mutation ID and payload until reconciled.

Deleting the cloud library means replacing it with an empty `data` snapshot and
a current revision. The revision/idempotency metadata stays, so a stale device
cannot recreate deleted entries automatically. Clearing only local data must not
silently clear another device's cloud library. Local libraries must be scoped by
account; signing out returns to guest data without exposing the previous user's
private reports. Guest records are never silently imported after login. Any future guest-import flow would require a separate explicit choice.

## Bounds and free-tier protection

The canonical UTF-8 `data` budget is **384 KiB**; the entire actual HTTP body is
limited to **512 KiB**, including chunked input. Existing analysis/contribution
paths keep their 32 KiB limit. Oversized or invalid snapshots return sanitized
422/413 failures and are never partly stored. The client keeps its local data and
explains the limit; it must not silently drop history to fit.

The dedicated `unlabel_private_accounts` collection stores one bounded document
per HMAC owner, below Firestore's 1 MiB document limit. A checksum and strict
schema/canonical-form checks fail closed on corrupt provider records.
`unlabel_private_limits` enforces, transactionally, 512 admitted account snapshots,
500 changed snapshots per UTC day globally and 60 per account per UTC day. Owner
daily counters reuse a fixed document. At the admission limit existing owners
can still update within daily budgets. These conservative payload/admission
bounds are not a measurement of all project storage or a service-availability
guarantee. Reads and authentication checks still consume provider quotas.

429 means `account_sync_limit`; keep the local library usable and retry after
the daily quota resets. 401 means `account_authentication_required`; ask the
scanner to sign in again. 503 means `account_sync_unavailable`; preserve local
work. Provider details, credentials, submitted values and arbitrary extra-field
names are excluded from errors. Query parameters and GET bodies are rejected.

The existing named Standard database `unlabel` remains behind deny-all direct
client rules and a backend machine credential. No new IAM role, client database
write rule, Storage bucket, Cloud Function, TTL, backup, PITR or billing link is
required. Keep Spark/no card. Exhausted quotas may stop sync; they do not gate
guest/local reading or justify upgrading billing automatically.

## Implementation references

- [Strict models](../../backend/app/accounts/models.py)
- [Owner and transactional store](../../backend/app/accounts/store.py)
- [HTTP routes](../../backend/app/api/v1/accounts.py)
- [Request schema](../../contracts/schemas/personal-sync-request-v1.schema.json)
- [Response schema](../../contracts/schemas/personal-sync-snapshot-v1.schema.json)
- [Failure schema](../../contracts/schemas/personal-sync-failure-v1.schema.json)

The original SDK implementation decisions were checked against the official
[Firebase Admin Python token verifier](https://github.com/firebase/firebase-admin-python/blob/main/_autodocs/api-reference/auth.md)
and [Firestore Python transaction implementation](https://github.com/googleapis/python-firestore/blob/main/google/cloud/firestore_v1/transaction.py)
through Context7. The reviewed existing transaction helper supplies explicit
three-second RPC deadlines and at most three contention attempts; failures never
fall back to local server files. UI/client timeouts can be shorter than a
contended server operation, which is why mutation retry identity matters.
