# Frontend 0.8.0+12 — authentication, profile and UI maintenance

The user expanded the maintenance task on 13 October to include complete
desktop/mobile authentication screens, Google sign-in, linked sign-in methods,
profile photos and optional gender. This release includes the earlier
[navigation/artwork repairs](FRONTEND_V0_7_1_REVIEW.md); the intermediate patch's
native run was cancelled before publication. Canonical versions remain the
component manifests. Backend's accompanying compatibility patch is reviewed
[separately](BACKEND_V0_12_1_REVIEW.md).

The user's final instruction freezes auth styling and ships functional/backend
work now. Further reference matching and the centered mobile leaf-plus-wordmark
are deferred to a later auth UI bugfix. No final pixel-match acceptance is claimed.

## Delivered behavior

- Responsive sign-in, account creation, forgot-password, neutral reset-link
  confirmation, verified-code password reset and success screens follow the
  supplied forest/mint reference. The required composition uses the actual filled
  Unlabel BrandLeaf and fits each auth page in one viewport without horizontal or
  vertical page scrolling. Final rendered/reference acceptance remains a gate. Six
  fresh illustrations are exclusive to their state. Profile-origin phone auth has
  an X; guest entry stays available.
- Google supplies its SDK name and photo. Settings links Google or email/password
  to the same Firebase UID and library. Credential collisions never merge users
  or switch ownership. Signup/reset/linking share the eight-character,
  letter/number and common-password checks; legacy sign-in remains usable.
- Optional gender selects a male/female default avatar. The existing male artwork
  was retained at the user's explicit request; a matching female avatar is new.
  Gender is never inferred from a name/photo and no Google gender permission is
  requested. Unset/male uses the approved male default; female uses the new
  female default. Rendering the male fallback never records a gender choice. Users
  can select Google, a default or a custom photo; removing a custom photo restores
  the available Google photo or the selected default.
- A gallery photo has a pan/zoom crop preview and explicit Save. Only a bounded
  192×192 PNG thumbnail, at most 96 KiB, is stored in the existing named Firestore
  database at `profile_media/{uid}`. Original photo/EXIF are not saved. Signed-in photo/gender settings are
  owner-only and separate from public label observations and library sync.
  Guests keep only their optional gender/default selection on the device.
- Profile windows have scrollable bodies, pinned actions and clear dismissal.
  The duplicate Settings Allergens row is removed; allergen reminders remain in
  their own section. Clear account library describes its exact deletion scope.
- Home tips rotate every three seconds, with pause/resume and manual controls;
  interaction, scrolling, background/covered routes, reduced motion and accessible
  navigation pause rotation. History/Saved phone artwork sits between copy/action.

## Configuration and trade-offs

Firebase Google is enabled with the support email explicitly supplied by the
user. Authorized production/local domains retain the preceding Firebase domains.
Android demo builds restore a stable private Actions signing key registered with
Firebase; this remains demo signing. The iOS public OAuth ID and callback scheme
are registered. Native device/provider acceptance remains separate from builds.

Custom photos use the existing free Firestore database rather than paid Storage.
The 96 KiB thumbnail limit trades original-photo resolution for bounded document
size and quick avatar rendering. Firestore persistence is disabled for this data;
edits wait for a server snapshot, and an offline/error state cannot overwrite an
unread existing avatar. Account changes invalidate late reads/writes.

The exact reference's Google, sign-in, guest, forgot and signup actions are
preserved despite the design review's five-action density flag. Sign-in alone is
the solid primary action; contextual links and the tonal guest control remain
visually secondary. No invented legal promises or account-existence disclosure
are added.

The static Firebase email-action bridge is deployed and forwards reset envelopes
only to Unlabel's fixed reset fragment, preserving Firebase's reserved handler for
other supported actions. Auth Admin API and Console both reject saving its custom
callback with `EMAIL_TEMPLATE_UPDATE_NOT_ALLOWED`; actual reset emails still use
Firebase's existing `/__/auth/action` handler. Custom email routing and real delivery
remain unverified; the working reserved handler is retained without billing changes.
[Configuration and storage contract](../architecture/ACCOUNT_PROFILE.md).

## Evidence boundaries

SDK fake tests cover UID/provider/collision/timeout boundaries; responsive widget
tests cover narrow/large-text forms and dialog actions. Local Firestore emulator
tests verify owner, anonymous, non-owner, named-database, schema and size rules.
Final local checks passed: **417 Flutter tests**, clean analysis, a release web
build, **21 Node bridge tests**, ten native publication guard tests and both
workflow lint checks. All 48 raster artifacts have validated hashes and callers;
the retired outlined leaf asset is removed. The compiled web secret scan found
zero configured backend secret matches. Source, deploy and native/feed identities
are recorded in the [auth/profile receipt](../research/AUTH_PROFILE_2026_10_13.json).
Published artifacts, real Google consent, real reset-email
delivery and physical LiveContainer launch are distinct gates.
