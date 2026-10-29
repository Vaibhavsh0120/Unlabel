# Web Google authentication repair — 29 October 2026

The reported web error maps to Firebase's `popup-blocked` code. That code does
not establish that the user's browser blocks every site's popups. The existing
Dart sign-in path already avoids an asynchronous hop after account startup.
Firebase's web popup implementation additionally initializes its auth helper
iframe before opening the popup; desktop Chrome can defer that initialization
until the first sign-in attempt. The user's exact browser failure was not traced
to a particular browser setting.

## Repair

Google sign-in retains its popup flow and recovers from `popup-blocked` with
Firebase's full-page redirect flow. Provider cancellation is not retried. Startup
consumes the redirect result; provider linking retains the existing Firebase UID.
Returning from Google never automatically resumes account deletion or another
sensitive mutation.

Production uses `unlabel-india.vercel.app` as its auth helper domain. Vercel
transparently proxies `/__/auth/*` and `/__/firebase/init.json` to the existing
Firebase project, with caching disabled. Localhost and unknown preview hosts
retain the existing Firebase helper domain. Public Firebase IDs, native signing,
password-reset ownership, app versions and Google scopes are unchanged.

This follows [Firebase's reverse-proxy guidance](https://firebase.google.com/docs/auth/web/redirect-best-practices)
and [Vercel external rewrites](https://vercel.com/docs/routing/rewrites).

## Live cloud audit

Read-only authenticated Firebase/API checks confirmed:

- Google, email/password and anonymous providers are enabled.
- The configured web OAuth client matches the frontend's public client ID.
- Authorized domains already include `unlabel-india.vercel.app`, both existing
  Firebase hosts, `localhost` and `127.0.0.1`.
- Billing is disabled and no billing account is attached.
- Both Android SHA-1 fingerprints are registered.

There are four necessary OAuth clients for three platforms. Android requires
separate client identities for its two package/certificate pairs:

| Client | Certificate or purpose |
| --- | --- |
| Android local debug | `6D:C1:EA:A0:19:AF:38:37:CF:C4:6B:E5:37:65:47:78:4F:E4:B0:EA` |
| Android published demo APK | `3E:7F:9E:3A:26:DC:4E:A8:0C:85:8A:48:12:BC:59:C7:2D:5F:D8:0A` |
| iOS | Existing `in.unlabel.unlabel` bundle/client |
| Web | Existing Firebase Google provider/client |

The first fingerprint was also checked against the local debug keystore; the
second matches the release workflow's enforced certificate. Neither Android
client is redundant, so no OAuth client was deleted. See
[Google's certificate guidance](https://developers.google.com/android/guides/client-auth).

The web client's unused
`https://unlabel-india.vercel.app/api/v1/auth/google/callback` redirect was replaced
with `https://unlabel-india.vercel.app/__/auth/handler`. The original Firebase
handler remains authorized. Independent HTTP requests to Google's authorization
endpoint verified the new URI reaches the login challenge, while both the
removed URI and an invalid control URI report `redirect_uri_mismatch`. These
requests did not submit credentials or complete user sign-in.

## Verification boundary

Validation results:

- Account authentication and web recovery regression suites: 55 passed. Coverage
  includes popup success, cancellation, blocked-popup recovery, same-UID linking,
  collision recovery, owner retention and disposal during redirect restoration.
- Production/local/preview auth helper configuration: 2 passed.
- `flutter analyze --no-pub --fatal-infos`: no issues.
- `flutter build web --release --no-pub`: passed against the final source.
  The optional Wasm dry run retains an upstream Google interop warning; the
  JavaScript release build completed successfully.
- Firebase password-reset bridge: 11 passed; existing web runtime tests: 21 passed.
- `python scripts/release/validate_workspace.py`: no syntax, local-link or
  private-key boundary errors.
- `git diff --check`: passed.

Browser automation stopped during the audit, so a
completed real-account Google login and post-deployment browser interaction are
not claimed. Cloud configuration acceptance, source verification and deployment
are separate from that end-to-end check.
