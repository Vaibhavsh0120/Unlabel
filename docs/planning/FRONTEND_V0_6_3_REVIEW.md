# Frontend v0.6.3+10: insight artwork across themes

Release candidate, 9 October 2026. Source is prepared for the independent main
push. Hosted proof remains pending; preceding v0.6.2 is the verified production
checkpoint. The user requested that work stop immediately after this push.

The desktop insight image previously rendered an opaque pale rectangular banner
inside a charcoal card. Fresh project-authored ImageGen artwork replaces it with
a 3:1 transparent bowl-and-leaf composition. The old art-only gradient layer is
removed. The whole illustration uses contain fit and inner padding, so the bowl
and leaves are fully visible and the card supplies its own light/dark background.

Live copy retains its separate space. Compact phone illustrations, manual swipe,
keyboard/screen-reader navigation, card actions and enlarged-text stacking are
preserved. No product facts, backend behavior, keys, OCR or personal records change.

## Verification

The full Flutter suite passed **240 tests**; analysis reported no issues and the
release web build passed. Three new regressions decode the actual bitmap alpha
and exercise the insight card at 320/390/768/1024/1440/1728 px, both themes and
1x/2x text. They verify transparent image corners, an opaque bowl sample, art
boundaries and separation from copy across 24 layout configurations. The corner
check accepts alpha up to 1/255, retaining the generated edge transparency.
Contain-fit choice follows the installed Flutter widget API and the current
bundled-image docs fetched through Context7.

Actual local release-web screenshots were reviewed in the Codex in-app browser
in light and dark at 390×844, 768×942, 1440×730 and 1728×942. The new desktop
cutout keeps the bowl whole inside its 132 px image height and padded slot; the
opaque rectangular tile is gone. Normal-size dark renders showed no obvious edge
halo after source review flagged fringes in the enlarged asset preview. Mobile
retains its compact bowl illustration. These observations do not certify pixel
equality or the absence of every image-edge artifact.

Better Design UI/UX guidance and source review were completed. Final copy
comprehension passes after treating the ordinary uppercase words `LABEL TIP` as
known terms. Final spacing inspection reports **100/100 with no findings** for
the affected insight-card bounds at 390/1440/1728 in both themes. Tablet screenshots
were visually reviewed separately; the spacing result covers only those six
phone/desktop card states, not the whole Home screen. Screenshot review and
semantic geometry remain separate evidence, with no persistent screenshot files.
[Render receipt](../research/FRONTEND_V0_6_3_RENDER.json).

Browser appearance was temporarily switched to Dark and restored to its original
Light setting. Preference and allergen selections were never changed. This
correction supplies no new native-camera, OCR-accuracy, recognition-latency or
backend/provider proof.

The manual APK/unsigned-IPA workflow now defaults to version `0.6.3` and build
`10`, matching pubspec. Its inputs remain editable and its manual-only trigger,
checks, signing status and publication behavior are preserved. Workflow syntax,
input defaults and embedded Python are checked locally; no native build run or
new mobile release is established by this update. The app's uninjected build
metadata fallback also matches `0.6.3+10`, so direct local builds do not report
the preceding `0.6.0+7` identity in About.

## Production

Hosted verification is pending and will not run after this push, as requested by
the user. No v0.6.3 READY deployment or hosted-check result is claimed. The backend
runtime remains v0.12.0; preceding frontend/backend production receipts stay
separate from this locally verified correction.

[Artwork provenance, hash and exact generation prompt](../../frontend/assets/artwork/README.md) ·
[Preceding frontend review](FRONTEND_V0_6_2_REVIEW.md) ·
[Backend review](BACKEND_V0_12_0_REVIEW.md).
