# Account identity and private profile

The self-hosted implementation is being verified. Its rollout and outstanding
production gates are in [the roadmap](../roadmap.md). Source implementation,
hosted behavior and native-device execution are separate evidence. The legacy
Firebase source remains for historical compatibility; the old Vercel API is retired.

## One identity, multiple sign-in methods

Google and email/password are optional methods for the same scanner account.
Guests retain useful local workflows and a separate device library. The API
derives account ownership from a verified, revocation-checked subject; clients
cannot choose an owner by submitting an email, name, avatar or UID.

GoTrue owns password verifiers and sessions in its isolated identity database.
The application database owns private profiles and libraries. Runtime app roles
cannot read password hashes. Native refresh credentials use platform secure
storage; web credentials use the existing secure session-storage adapter.

Ordinary web Google login redirects the current tab to Google. A five-minute
PKCE verifier stays in tab-scoped session storage. The same-origin callback
clears its URL, stores the one-time bound code and returns to Unlabel, which
exchanges it and restores the account. This login opens no popup. Explicit
provider linking and Google proof for sensitive account operations retain their
owner-checked popup flow. Native Google sign-in uses the platform SDK's ID token.
Only identity scopes are requested; Google gender is never requested or inferred.

The `.2` identity policy rejects automatic linking based on equal emails.
Explicit linking requires the authenticated owner and retains that owner's UID
and library. A credential owned by another user is a conflict, never permission
to merge accounts. Disconnecting a method requires another remaining method and
fresh authentication. Disconnecting email also clears its password verifier.
Changing Google links the replacement before removing the prior identity.

Email and password changes prove the current credential. Email changes remain
pending until GoTrue completes its verification. Authentication mutations are
single-flight; restoring or refreshing a session cannot select another owner.

## Email signup

New email/password accounts sign in immediately without a confirmation email.
GoTrue enables email signup and auto-confirmation. The API sends a separate
welcome email after a successful new non-guest signup, with bounded SMTP retries.
Welcome delivery is best effort and never gates use of the account. Duplicate or
failed signup and anonymous sessions do not send welcome mail. This activation
policy follows the operator's college-project requirements; it does not prove
that the person controls the supplied inbox. Email changes and password recovery
retain their secure confirmation links.

## Profile media

Signed-in profiles use owner-only `GET`/`PUT /v1/account/profile`, backed by
PostgreSQL. Writes include the last observed revision; conflicts require a fresh
read rather than silently replacing another device's profile. Migration `0008`
stores avatar preference separately from thumbnail origin.

| Choice | Behavior |
| --- | --- |
| Automatic | Available Google photo, otherwise the chosen default |
| Google photo | HTTPS Google provider photo, with a default while unavailable |
| Default avatar | Approved male art for unset/male, separate female art for female |
| Custom photo | Gallery crop, explicit save, private 192×192 PNG of at most 96 KiB |

Gender is optional and user-selected. Choosing a fallback does not infer gender.
Custom thumbnails are re-encoded pixels; original gallery images and EXIF are
not stored. Profile data never enters public product observations. Guest profile
appearance stays on the device, and guests cannot upload custom thumbnails.

## Recovery and deletion

The forgot-password form has a neutral link-sent state. GoTrue sends the recovery
email through Brevo. `account-recovery.html` clears the grant from the address bar,
verifies it with Oracle and accepts a new password. It ends the recovery session
and returns to ordinary sign-in; it never activates a scanner account. Invalid,
expired and revoked grants cannot open the form. Actual inbox delivery remains a
hosted acceptance test. Native email links also complete in this web form.

Account deletion requires confirmation and recent authentication. The backend
commits a permanent private deletion marker before removing library, profile and
push data and deleting the identity. The client removes only that owner's local
namespace after confirmed cloud deletion. Failures preserve local data and do
not permit automatic library recreation. Guest data, public observations and
licensed source evidence remain outside account deletion.

The rollback Firebase helper/rules remain under `infrastructure/firebase` until
retirement. Abandoned custom email-template proposals were removed; the live
legacy handler does not depend on them. Historical Firebase behavior and release
evidence remain in Git history and the [release ledger](../../contracts/versioning/releases.json).
