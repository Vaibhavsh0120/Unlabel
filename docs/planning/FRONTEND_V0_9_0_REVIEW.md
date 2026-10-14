# Frontend 0.9.0+13 — reference authentication and account controls

Checkpoint: **13 October 2026, Asia/Calcutta**. The user authorized completion and
push from main, superseding the earlier local auth-repair hold. This is a minor
release because provider management and account deletion add user-visible
capabilities beyond the preceding auth styling/reset patch. The canonical
product/build version remains [pubspec.yaml](../../frontend/pubspec.yaml).

The last verified remote source checkpoint is `3e67f13`, whose manifests identify
frontend 0.8.0+12/backend 0.12.1. Their [frontend](FRONTEND_V0_8_0_REVIEW.md) and
[backend](BACKEND_V0_12_1_REVIEW.md) reviews retain their dated evidence. The
unshipped [0.8.1 working note](FRONTEND_V0_8_1_REVIEW.md) is superseded development
history, not a separately published release. Backend's additive deletion contract
has its [own review](BACKEND_V0_13_0_REVIEW.md).

## Delivered scope

- Login/signup reproduce the supplied cream/forest and charcoal/green compositions
  using rounded live form cards and layered, animated mascot/sprout/garden assets.
  The outer viewport is fixed. Desktop cards have identical width, centered in the
  right section, narrowed by the latest 15% request, with no scrolling. Signup's
  hero phrase stays on one line; headline scale matches login. Decorative cards
  retain a visible gap; copy and character respect available window height.
- On phones and portrait iPads, artwork/card fill the width. The whole card moves
  over fixed artwork, not inside a separate scroll area. No scrollbar is shown.
  A small horizontal drag handle marks every movable card.
  Keyboard opening lifts the card; closing restores its prior position. Landscape
  iPad uses two columns where height allows. Enlarged text uses a compact header.
  Full name, email, password and confirmation stay in one signup form. The redundant
  email-option button is removed; validation and provider operations remain real.
  Profile-origin screens show a back arrow; Welcome-origin screens do not.
- Entrance, breathing, blinking, leaf sway, independently floating badges/hearts and
  button feedback respect reduced motion and lifecycle. Celebration occurs only
  after controller success. Asset reconstructions are approximate, never claimed
  to be exact originals; decorative labels never enter product evidence.
- Sign-in methods use the supplied Google/email card composition with real
  connected/enabled state, provider controls, a last-method explanation and a
  separate account-deletion action. Linking preserves UID/library; collisions
  never merge accounts. Removing a method proves access to the remaining method.
  Google switching keeps verified password access if replacement is cancelled
  or fails. Email change uses Firebase verification; password change reauthenticates.
- Account deletion requires explicit confirmation and recent Firebase
  authentication. The backend clears private library/profile media and blocks
  late writes before Firebase sign-in deletion; owner-local data is removed only
  after confirmed Auth deletion. A partial failure remains recoverable and is
  never presented as completed deletion. Guest libraries and public observations
  remain separate.
- Firebase's supported `/__/auth/action` page owns reset-code validation, the
  new password and success. SDK requests use `handleCodeInApp:false` and the fixed
  `https://unlabel-india.vercel.app/#/account-signin` Continue destination. The
  app retains sign-in, signup, forgot-password and neutral link-sent states.
- Private thumbnails and optional gender preserve their owner-only named
  Firestore contract. Unset/male uses the approved male default, female its own
  artwork; no Google gender is requested or inferred.

## Development and release tooling

The local runner now offers PC-local Flutter/API, local Flutter/production API,
and HTTPS local-network Flutter/API through Caddy. TLS and the same-origin API
proxy were exercised locally with a synthetic server and CA verification. Caddy
is under ignored scripts/tools/caddy; generated config/CA keys stay under ignored
output/local-network. No automatic trust-store/firewall changes are made. Root
setup/run/env commands remain stable; helpers use shallow dev/release/data/ai/config
folders. Imports, CI, tests and documentation use the relocated paths.

Main pushes that increase the canonical frontend version/build automatically
build and verify native artifacts. Public attachments are only APK, IPA and an
apps.json snapshot; build reports are retained as CI evidence. The subscription
URL remains the universal ios-source/apps.json, refreshed only after verified
publication. Historical releases/assets remain intact.

## Verification and release boundaries

Local verification on **14 October 2026**:

- Full Flutter suite: **465 passed**. After expanding legal-link hit areas and
  correcting reset-copy encoding, all **55 auth tests** passed again. Analysis
  and final release-web compilation passed. Workspace validation, Ruff and
  Pyright passed after the script moves (zero type errors/warnings).
- Node web/auth bridge: **22 passed**; script/release guards: **16 passed**.
- Desktop, phone and both iPad orientations were rendered in Chromium. Portrait
  is edge-to-edge; landscape title is one line. Rotation retains entered fields.
  Widget checks cover large text, errors, whole-card travel and keyboard restore.
- Better Design geometry measured at 390/1440/1728: no serious visible overflow
  after excluding Flutter's intentionally offscreen accessibility announcers.
  Legal hit targets were expanded after its moderate findings. Its copy-density
  heuristic is acknowledged: the user-requested signup requirements and legal
  copy remain together, with Google/signup/sign-in choices visible.
- 42 authored icons and 21 OCR files passed their manifest checks. Generated
  illustration and font provenance remain tracked. Rendered reconstructions are
  approximate; this is not a pixel-equality or physical 60fps certification.
- Six private-profile rules tests passed in the loopback Firestore emulator.
  Updated rules and the fallback auth bridge deployed to the existing Firebase
  project. The supported reserved Firebase reset handler remains unchanged.

The developer-only [account preview](../../frontend/tool/account_visual_preview.dart)
uses synthetic memory-only identity/preferences with disabled network mutations.
Browser layouts and local tests do not establish real provider consent, inbox
reset delivery, or physical LiveContainer/device acceptance.

Source `bd06bfb9dbf7307c9ccf6e9f2402a13ec3419084` passed repository CI and
deployed to Vercel on 14 October. Thirteen [hosted checks](../research/RELEASE_2026_10_14_PRODUCTION.json)
passed. The automatic [native release workflow](https://github.com/Vaibhavsh0120/Unlabel/actions/runs/38512047557)
published frontend-v0.9.0+13 with APK, unsigned device IPA and apps.json only.
Public artifact bytes matched GitHub hashes/sizes; the [native receipt](../research/FRONTEND_V0_9_0_NATIVE.json)
also verifies the IPA version/platform and stable feed, retaining prior versions.
Physical execution remains unverified.

Subsequent user feedback identifies a short-viewport Safari auth header regression
and requests a new scanner/account update. Those repairs are separate from this
published artifact and must not be described as included in 0.9.0+13.

[Account/profile contract](../architecture/ACCOUNT_PROFILE.md) ·
[Versioning](RELEASE_VERSIONING.md) · [Release ledger](CONTROLLED_RELEASES.md).
