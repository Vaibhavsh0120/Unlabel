# Account sign-in and private profile media

Current versions come from [frontend pubspec](../../frontend/pubspec.yaml) and
[backend pyproject](../../backend/pyproject.toml). The [frontend review](../planning/FRONTEND_V0_8_0_REVIEW.md)
and [backend compatibility review](../planning/BACKEND_V0_12_1_REVIEW.md) separate
implementation, provider configuration, hosted behavior and device acceptance.

## One identity, multiple sign-in methods

Google and email/password are optional scanner sign-in methods. Google supplies
the Firebase SDK display name and photo; no People API or gender permission is
requested. Profile → Settings → Sign-in methods adds the missing provider to the
current Firebase user. Linking must preserve its UID, private library and photo
settings. A credential already owned by another account reports a conflict; it
never signs into that account or merges libraries. Guest libraries remain separate.

The backend accepts verified `anonymous`, `password` and `google.com` scanner
tokens. Private library APIs accept only `password`/`google.com`; ownership always
comes from the verified subject, never email, name, photo or submitted UID. The
[library snapshot contract](PRIVATE_ACCOUNT_SYNC.md) and explicit cloud/device
conflict choices remain unchanged. Auth operations are single-flight; a response
timeout cannot start a second operation while the SDK's first operation is pending.

## Avatar choices and storage

| Choice | Behavior |
| --- | --- |
| Automatic | Available Google photo, otherwise the selected default |
| Google photo | SDK-provided HTTPS Google photo, with the default while loading/unavailable |
| Default avatar | Existing user-approved male art for unset/male; exclusive new female art for female |
| Custom photo | Gallery selection, pan/zoom crop preview and explicit Save |

Gender is optional: Prefer not to say, Male or Female. Displaying the male fallback
does not infer or record a gender choice. Changing gender preserves a selected
custom photo. Photo options can restore the Google/default image; removing a
custom image restores Automatic. Initials are only a technical fallback if the
bundled default image cannot render.

Signed-in settings use one private `profile_media/{uid}` document in the existing
named Standard Firestore database **`unlabel`**, Mumbai. Its strict fields are
`schema`, `gender`, `source`, server `updated_at` and, for Custom only, `avatar_png`
and `content_type`. The thumbnail is a **192×192 PNG, at most 96 KiB**. The app
decodes bounded input, crops and re-encodes pixels; the original photo and EXIF
are never stored. The binary field is exempt from indexing in
[firestore.indexes.json](../../firestore.indexes.json).

[Rules](../../firebase/firestore.rules) allow only a non-anonymous owner to get,
create, update or delete that exact document; listing, other owners, other databases
and all remaining collections are denied. Backend library/public/AI collections
retain their backend-only access. No second database, Storage bucket or Function
is needed. Keep the free tier with no billing/card or paid fallback.

The SDK's durable Firestore cache is disabled for profile media. Editing waits
for a server-confirmed initial snapshot; offline failures cannot replace an unread
avatar. Transactions require a connection instead of queuing a photo write across
account changes. Late reads/writes cannot update another owner's screen. Guests
persist only their optional gender/default selection locally and cannot upload
a custom photo. Profile thumbnails are never public facts, AI input or decorative
artwork warmup. Package photos/raw OCR remain excluded from profile/library sync.

Clear account library clears the bounded saved/history/display-name snapshot and
retains Firebase sign-in metadata, avatar and gender. Removing a custom photo is
a separate Photo options action; this is not account deletion.

## Public configuration and native signing

The existing Firebase project is `unlabel-india-catalogue`. Anonymous, password
and Google providers are enabled; Google's support contact is the user-supplied
`vaibhavsh0120@gmail.com`. Authorized domains include the two existing Firebase
hosts, `unlabel-india.vercel.app`, `localhost` and `127.0.0.1`. Public app/OAuth IDs
live in [firebase_options.dart](../../frontend/lib/app/firebase_options.dart).
They are client identifiers, not backend/admin credentials.

The Android package is `in.unlabel.unlabel`. Local and CI demo certificate SHA-1
values are registered with Firebase. The manual release job restores the stable
private `UNLABEL_ANDROID_DEMO_KEYSTORE` Actions secret and verifies the APK signing
certificate before publication. Keep that key outside Git and preserve it for
future demo updates; older APKs signed with a disposable runner key may require
uninstalling first. This is demo signing, not a production release key. iOS uses
the registered OAuth client and reversed callback scheme in
[Info.plist](../../frontend/ios/Runner/Info.plist); native Google acceptance still
requires device/provider checks.

## Password reset and the email-handler gate

Six fresh illustrations identify sign-in, signup, forgot password, reset-link
confirmation, new password and success. The UI contract uses the supplied exact
desktop/phone composition, filled Unlabel BrandLeaf and a single viewport without
horizontal or vertical page scrolling. Profile-origin phone auth has a top-left X.
New-password signup/reset/linking checks share the same policy; legacy sign-in does
not impose a new-password policy on existing credentials.

Reset email requests give a neutral result. A reset code must be verified by
Firebase before the password form is enabled, and confirmed by Firebase before
success. Codes stay in memory; the browser history URL is scrubbed. The static
[Hosting bridge](../../firebase/auth-bridge/account-action.js) is deployed at
`https://unlabel-india-catalogue.firebaseapp.com/account-action.html`. It forwards
only valid password-reset envelopes to the fixed Unlabel `#/account-reset`
fragment; other supported email actions retain Firebase's reserved handler.
The fragment keeps the reset code out of the frontend's HTTP request URL.

**Provider configuration gate:** Auth still uses its existing `/__/auth/action`
email URL. Both Auth Admin API and Firebase Console reject saving the custom
callback with `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`. The deployed bridge and local
custom reset flow do not prove emails land in that flow. Keep Firebase's working
reserved handler until the custom URL can be saved and independently verified;
no billing upgrade or alternate mail service is introduced. Firebase's
[custom-handler documentation](https://firebase.google.com/docs/auth/custom-email-handler)
requires changing the email-template action URL as a separate step.

SDK fake, responsive widget, bridge and local rules-emulator checks are recorded
in the release review/maintenance receipt. Final exact-source hosted/native checks,
real Google consent, real reset-email delivery and physical LiveContainer launch
remain distinct acceptance gates.
