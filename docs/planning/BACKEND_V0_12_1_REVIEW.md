# Backend 0.12.1 — Google account compatibility

The frontend's new Google sign-in needs both scanner/public and private-library
APIs to accept verified Google sessions. The verifier now accepts `google.com`
alongside `anonymous`/`password` for scanner APIs and `password` for private
library APIs. Private APIs continue to reject anonymous
sessions. UID, project, issuer, expiry, revocation and all existing identity checks
remain in place; names, photos and email addresses never establish ownership.

No catalogue, source, database migration, extraction or report semantics change.
The six reviewed glossary entries, bulk records, immutable observations and
separate sourced image descriptors remain intact.

Targeted authentication/private-sync checks: **70 passed**, including provider
allowlists, wrong project/issuer, expiry, anonymous private access, revocation and
linked metadata/UID ownership. The final full suite passed **1,371 tests** with
five explicit emulator/provider skips; Ruff passed. The current OpenAPI export
and thirty synthetic examples were regenerated and validated. Hosted evidence is
recorded separately in the [auth/profile receipt](../research/AUTH_PROFILE_2026_10_13.json). Final exact-source
hosted verification and source publication remain pending. Frontend profile-media
rules are a separate [owner-only storage contract](../architecture/ACCOUNT_PROFILE.md),
with no change to backend library/public collection access.
