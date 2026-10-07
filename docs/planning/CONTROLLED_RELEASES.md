# Controlled Unlabel releases

Accepted 7 October 2026. Work directly on **main only**. One release is active;
finish its checks, documentation, push, hosted verification and publication before
implementing the next. Preserve existing source and historical tags.

## Recovery

- All 65 originally changed files were copied and SHA-256 verified in the local
  Git-directory recovery snapshot `.git/unlabel-recovery/2026-10-07/`. Its
  manifest records the original source SHA, file hashes and version assignment;
  a binary patch preserves tracked changes. The snapshot is never published.
- The unused managed worktree was archived after the user's main-only correction.
- Backend source `9d9a9b64a735bd1ad6fdd606c82e0a34412dd6f0` already matches
  remote main. The original backlog was uncommitted files, not unpushed commits.
- Capture modules, web capture bridge and Ingredient Insights belong to v0.3.0.
  Split capture dependencies and mixed tests out of v0.2.0 before its checks.
  Restore them from the verified snapshot when v0.3.0 becomes active.

## Release ledger

| Release | Goal | Current stage |
| --- | --- | --- |
| Backend v0.7.0 | Close Private Account Sync independently | Hosted verified; documentation/static/test refresh and publication active |
| Frontend v0.2.0+3 | Welcome, Home, four-tab shell, optional account sync, artwork/motion/haptics | Implemented partially; release validation pending |
| Frontend v0.3.0+4 | Capture/OCR and remaining reference-style screens | Planned; preserve existing fragments until v0.2.0 is published |

Stages: **Planned → Implemented → Tested → Visually verified → Pushed →
Hosted verified → Published**. Backend visual verification is not applicable.
Failing gates keep the current release active. Do not stage an entire mixed tree.

## Frontend v0.2.0 acceptance

- [ ] Persist first-use Welcome completion; returning users enter Home; no login wall.
- [ ] Reference-style Home and supporting destinations, white/forest/mint light
  and charcoal dark; light is the initial default.
- [ ] Home / Scan / Compare / Saved mobile navigation; Profile top right on main screens.
- [ ] Filled leaf/Unlabel branding throughout Welcome/header/About; native light/dark
  icon masters remain the existing authored assets with separate device proof.
- [ ] Large cute corner artwork: reserved art space, deliberate rounded-card edge
  cropping, no obscured text/actions; five distinct decorative assets with provenance.
- [ ] Gentle artwork motion and short interaction transitions; reduced-motion,
  offscreen/background and touch/semantics controls.
- [ ] Navigation/capture/confirmed-save haptics with harmless unsupported-platform fallback.
- [ ] Guests remain local; optional password accounts have isolated private saved/history
  and explicit cloud/device conflict choices. Public package facts remain separate.
- [ ] Every visible Home/library/account/insight/source action works. Existing manual
  Scan and actual-product Compare stay useful until their v0.3.0 redesign.
- [ ] Analysis/tests/build, scripts/docs/secrets/dead-code review, responsive light/dark
  screenshots, enlarged text, first/return use and account isolation pass.
- [ ] Independently push; verify exact hosted source/flows/assets; publish source release.

## Frontend v0.3.0 acceptance and order

Finish, review and commit each screen in order: **Scan → Analysis Results →
Ingredient Insights → Compare**. Reuse the established v0.2.0 visual system.

- [ ] Scan: front/back/barcode, camera/gallery/manual routes, permissions/retry/cancel,
  local OCR and normalized captured-image text regions, editable review and explicit confirmation.
- [ ] Connect a reviewed capture draft to existing manual input and the report API;
  raw OCR is never silently confirmed. Configure web runtime/languages and native permissions.
- [ ] Results: actual product photo/fallback, sourced evidence and reasons, claims,
  nutrition snapshot, original-basis approximate 4 g sugar cubes, save/source actions.
- [ ] Ingredients: integrated navigation, real identified claims, scoped outcomes,
  three reviewed bilingual functions, allergen availability and expandable sources.
- [ ] Compare: actual product cards, compatible units/bases/preparation, source/date
  and useful unknown/incompatible states; no invented universal health winner.
- [ ] End-to-end corrected scan/report, all actions and responsive appearance checks;
  separately push, hosted-verify and publish against the validated SHA.

## Shared release and evidence rules

- Source/frontend tags and manual `mobile-vVERSION+BUILD` tags remain separate.
  Mobile artifacts are frontend-only. An unsigned IPA does not prove installation.
- Validate 320/390 px, tablet portrait/landscape and desktop, enlarged text, loading,
  errors, missing images and reduced motion. Record DOM measurement limits honestly.
- Preserve actual OFF image descriptors/provenance and report evidence; decorative
  generated artwork never supplies fictional product records or health scores.
- No backend v0.8.0 is needed for this milestone. Keep ₹0/no card, local OCR,
  existing free services and disabled Gemini/training.
- Broader ingredient knowledge, personalized suitability and continuous live-camera
  highlights remain explicit future goals. Native camera/icon/haptic proof stays separate.

Authoritative order: [master plan](MASTER_PLAN.md). Current evidence:
[feature tracker](FEATURE_TRACKER.md). [Account/screen checklist](ACCOUNT_SYNC_SCREEN_PLAN.md).
