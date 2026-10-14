# Account sign-in and private profile media

Current versions come from [frontend pubspec](../../frontend/pubspec.yaml) and
[backend pyproject](../../backend/pyproject.toml). The [frontend update](../planning/FRONTEND_V0_9_0_REVIEW.md)
and [backend deletion release](../planning/BACKEND_V0_13_0_REVIEW.md) are authorized
for completion/push from main. The preceding
[frontend source scope](../planning/FRONTEND_V0_8_0_REVIEW.md) and unchanged
[backend compatibility review](../planning/BACKEND_V0_12_1_REVIEW.md) retain separate
implementation, provider, hosted and device evidence.

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

Disconnecting a provider requires another enabled method and reauthentication
with the method that will remain. Switching Google first proves password access;
if replacement fails, the password and UID/library remain available. Email
change uses Firebase verification before update; password change proves the
current credential. No provider toggle can leave an account with zero methods.

## Account deletion

Delete account requires explicit confirmation and recent Firebase authentication.
The app calls the owner-only backend DELETE operation before deleting Firebase
Auth, and removes only that owner's local namespace after confirmed Auth deletion.
Backend cleanup transactionally removes library content, profile media and the
owner write counter while preserving minimal permanent library/profile-deletion
markers. Late cloud writes and direct profile-media access are denied thereafter.
Completed cleanup retries are idempotent. If Auth deletion fails, the screen
explains the incomplete result and permits a reauthenticated retry; it does not
claim success or re-upload the deleted library. Guest records and immutable public
package observations retain their separate scope. [Deletion/retry contract](PRIVATE_ACCOUNT_SYNC.md).

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
and all remaining collections are denied. A permanent backend-owned
`profile_deletions/{uid}` marker also denies profile-media access after deletion.
Backend library/public/AI collections
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

## Firebase-hosted password reset

The app keeps four states: sign-in, signup, forgot password and
neutral link-sent confirmation. The outer auth viewport stays fixed. Desktop uses
equal non-scrolling cards; phone and portrait iPad move the entire card over fixed
artwork, without nested scrolling. Keyboard opening lifts the card and closing
restores its prior position. Enlarged text uses a compact header and wraps.
Phone login/signup opened from Profile show a left arrow returning directly to Profile; Welcome-origin login/signup show no back arrow. Signup and provider linking share the
app's new-password policy; legacy sign-in does not apply that policy to existing
credentials. Firebase's hosted reset uses the project's configured password policy.

The SDK sends a reset request with `ActionCodeSettings(handleCodeInApp: false,
url: 'https://unlabel-india.vercel.app/#/account-signin')`. The return origin is in
Firebase's authorized domains. Firebase's existing `/__/auth/action` page owns code
validation, new-password entry and success; its Continue action returns to that
fixed web sign-in destination. The app does not receive/verify a reset code or
claim a completed password change. Resetting a password does not sign the user in.
This is a web return, not proof of a native-app deep link.

Both API and Console rejected a custom action URL with
`EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`. The supported flow deliberately retains
Firebase's working reserved handler, so it needs no custom email-template update,
alternate email service, new database or billing upgrade. The earlier public
[bridge](../../firebase/auth-bridge/account-action.js) forwards all supported account
actions to Firebase's same-project reserved handler with the fixed Unlabel sign-in
return; it no longer forwards reset codes into a custom app password screen. Its
current source still needs its own verification and exact-source deployment evidence.

The two unused custom new-password/success illustrations are removed from the
runtime bundle. Login/signup share one generated packet panel per theme;
illustration badges are decorative, not product evidence. Current SDK/route/bridge tests
and synthetic link verification are recorded in the
[frontend review](../planning/FRONTEND_V0_9_0_REVIEW.md) after they run. Generating
a synthetic link sends no email and cannot prove inbox delivery. Real Google
consent, reset-email delivery, exact-source hosted/native behavior and physical
LiveContainer launch remain separate gates.

The flow follows Firebase's official
[email-action state documentation](https://firebase.google.com/docs/auth/web/passing-state-in-email-actions):
`handleCodeInApp:false` completes the web action before a Continue return.
