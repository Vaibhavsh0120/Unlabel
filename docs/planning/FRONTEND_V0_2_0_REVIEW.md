# Frontend v0.2.0+3 review

Checkpoint: 7 October 2026. Scope: Flutter client, platform permissions, artwork,
manual mobile workflow defaults and current documentation. Backend v0.7.0
remains independently published; no backend application change is in this release.

## Implemented and locally tested

- First-use Welcome, compact Home, contained themed hero art, short centered
  shortcuts, smaller Insight gap and manually swiped illustrated tips.
- Floating curved Home/Scan/Compare/Saved bar with hold/slide selection, keyboard,
  accessibility, safe-area and reduced-motion behavior.
- Optional password account/private sync, UID-specific local ownership, explicit
  cloud/device conflict choices, useful guest workflows and recoverable failures.
- Header product-name search with debounce, stale-response cancellation, bounded
  paging, actual photos/fallbacks and whole-result report navigation.
- Reference-style Analysis Results and paired Compare cards, original nutrition
  basis/preparation/source dates, unknown/conflicting evidence and approximate
  4 g sugar cubes. There is no invented 0–100 health score or universal winner.
- Non-scrolling Scan: centered back/title/gallery header, live camera box, three
  modes, tip and capture/review/gallery controls. Extra lookup links and obsolete
  future-camera text are removed. Rear camera is preferred and audio is disabled.
- Camera stops on route/background/disposal; late permission/capture completion
  cannot reopen a hidden page. Gallery cancellation resumes the camera. Android
  interrupted picker recovery is included. Photos remain in session memory and
  are never added to report/API/private-sync payloads. Manual confirmation remains.

## Fresh local evidence

- `flutter analyze`: no issues.
- `flutter test`: **135 passed**.
- `flutter build web --release`: passed, including Wasm dry run.
- `python scripts/release/generate_app_icons.py --check`: **42 assets verified** across
  authored masters, iOS, Android and web. Physical launcher appearance remains separate.
- Scan tests cover 320×568, 390×844, 844×390 and 320×844 at 2× text; no scrolling
  or overflow and all controls remain reachable. Report/Compare tests cover
  320/390/768/1440, both themes and enlarged text.

## Rendered browser checkpoint

The 390×844 local browser showed the compact contained Home artwork, short
shortcuts, manually swiped tips and floating navigation. Scan showed a playing,
muted 1280×720 camera feed; leaving Scan removed its video element. Its camera,
three modes, tip and capture/gallery controls fit without scrolling. Live
`aashirvaad` search returned ten results of 57 matches, replaced the normal header,
and tapping an actual product photo opened its dated Analysis Results report.

The completed Better Design measurement captured 390px Home semantics/host
bounds. Its two findings concern the browser's 2px range-input margin and a
3.15px clipped portion of offscreen scroll content. These do not measure the
Flutter-painted cards or full underlying touch targets. Desktop DOM measurements
remain uncollected; responsive themes/large text have widget coverage. The user
explicitly chose to perform further visual review personally and authorized push.
Exact release/hosted evidence is recorded after push.

The first local release preview used the production origin, whose allowlist
correctly rejected localhost CORS. A release build also rejects local HTTP by
design. The local preview was rebuilt in debug mode with the local API; no hosted
CORS or app HTTPS release protection was weakened. The selectable launcher
documents and tests the separate Local/Production development paths.

## Remaining boundaries

Automatic barcode reading, on-device OCR, extraction correction/highlight geometry
and the dedicated Ingredient Insights screen belong to frontend v0.3.0. This
release captures photos and displays them beside manual entry. Native camera,
picker interruption, haptics, icon selection and installation need real-device
checks. iOS artifacts remain unsigned; Android uses the documented demo key.
No Gemini, paid service, new account role or photo upload is introduced.

The user explicitly authorized updating docs, pushing and making the release on
7 October, superseding the earlier preview-before-push hold. Publication follows
successful local and hosted gates; native artifacts use their separate manual lane.

## Published receipt

Implementation source: `5f3e92fe58f87aeed6a78f989b3f9289233ca2f2`.
Hosted frontend deployment: `dpl_C67D8NT38YmhRXr2AsRoibKswaZy` (READY).
Source release: [frontend-v0.2.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.2.0).
The detailed asset/API receipt is [FRONTEND_V0_2_0_PRODUCTION.json](../research/FRONTEND_V0_2_0_PRODUCTION.json).
The separately dispatched native run builds the demo APK and unsigned IPA; its
artifacts do not change the source release or prove device installation.
