# Maintenance audit — 12 October 2026

Scope: repair documentation, setup/release scripts, GitHub configuration and
native builds. The initial repairs kept frontend 0.7.0+11 and backend 0.12.0.
The intermediate UI patch targeted frontend 0.7.1+12. On 13 October the user
expanded scope to auth, linked sign-in, profile media and optional gender, with
version bumps to frontend 0.8.0+12/backend 0.12.1. The intermediate native run was
cancelled before publication. Current [frontend](FRONTEND_V0_8_0_REVIEW.md) and
[backend](BACKEND_V0_12_1_REVIEW.md) reviews supersede that release target; final
exact-source hosted/native publication is pending. Work on main and preserve
source bundles, historical identities and the dated evidence below.

| Finding | Evidence | Action and verification |
| --- | --- | --- |
| F-01: Android release timed out | Run 38044207593: checks/iOS succeeded; Android stopped during assembleRelease. Pasted log includes in-build NDK download and filesystem-watcher diagnostic. Full archived logs are unavailable. | Explicit toolchain preparation, dependency caching, bounded build logging and CI watcher configuration; verify with a fresh native workflow run. |
| F-02: repeated version edits | Pubspec, Dart fallback and workflow defaults repeat frontend version; pyproject and backend runtime repeat backend version. | Read the two canonical component files; test default and override metadata and ensure deployment inputs agree. |
| F-03: stale active docs | Architecture/index/setup docs still name older current releases, 21-path API or planned OCR; runtime exports 27 paths/28 operations. | Correct active docs, preserve dated reviews/receipts, run Markdown/link/schema/script validation. |
| F-04: incomplete GitHub releases | Source releases stop at backend 0.7/frontend 0.3; a mobile draft uses an explicit source/version override. | Publish missing already-reviewed source identities, label components and historical override accurately, preserve old tags/assets. Verify remote release targets. |
| F-05: unused scaffolding/assets | Import graphs retain every runtime module; two decorative images have no callers; empty placeholders describe obsolete architecture. Adaptive glyphs still use Cupertino's font. | Remove demonstrably unused content; retain Cupertino, platform stubs and historical asset evidence. Run app analysis/tests/build and source checks. |
| F-06: LiveContainer source missing | User confirmed a hosted source URL. | Generate AltStore-compatible source from a verified published iPhoneOS IPA manifest; publish a stable source asset and verify its public URL. Device import/execution remains a physical-device gate. |

Implementation ownership: native workflows/packaging, version/setup tooling,
architecture docs, and root release/docs cleanup run independently. Root reviews
their integration before committing, pushing and dispatching native builds.
Local tests, published source, native build, hosted app and device execution
are separate evidence gates. Results are recorded in the maintenance receipt.

## Local verification and source publication

- Backend full suite: 1,343 passed, five explicit provider/emulator skips. Later
  feed-permission regressions passed in the 13-test source subset.
- Flutter: 268 tests, clean analysis and production release web build. Six browser
  OCR bridge tests pass. Cupertino dependency retained after build evidence showed
  adaptive glyphs still use its font; no dependency upgrades.
- Ten native publication guard tests, Ruff, Pyright (zero errors/warnings), both
  actionlint workflows, 30 synthetic schema examples and three source build
  receipts pass. All 42 icon and 21 OCR assets verify. Compiled web secret scan:
  zero configured-secret matches.
- Workspace: 147 Python, 154 JSON, one TOML, 118 Markdown and 700 local links
  checked without errors. Removed 64 redundant .gitkeep files, 45 verified empty
  scaffold directories and two unreferenced decorative images. No runtime modules,
  private data, source bundles or historical receipt assets removed.
- Twelve missing reviewed source releases published. All original published tags
  and all original release assets/digests preserved; old mobile draft remains a
  clearly labeled draft with its effective version override.
- Independent review's P2 feed permission-history finding is fixed: older version/
  build input fails before changing the source's current permission declaration.

## Published native build and source

[Run 38250931887](https://github.com/Vaibhavsh0120/Unlabel/actions/runs/38250931887)
passes checks, Android, iOS and release publication from maintenance source
`6fe7037a12b9d595c98a85c94f6b9e8b4fbfc01e`. Android completes in 7m16s
with explicit SDK/NDK preparation; iOS completes in 16m51s on the standard Intel
runner. The old ARM capacity message was informational.

[Native frontend 0.7.0+11](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.7.0%2B11)
contains the demo APK, unsigned IPA and five verified metadata/checksum files.
The [LiveContainer source](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json)
returns HTTP 200. Downloaded IPA bytes (34,769,249) and SHA-256 agree with the
feed, GitHub asset digest, manifest and SHA256SUMS. The actual package is arm64
iPhoneOS, bundle `in.unlabel.unlabel`, version 0.7.0/build 11, minimum iOS 15.0;
privacy declarations and entitlements agree with the feed. Latest GitHub release
remains the reviewed frontend source release, not the feed or backend.
Physical iPhone import/launch remains a separate acceptance gate.

## README and website maintenance

User follow-up adds README redesign, link/metadata repairs, a branded 404 inside
the existing shell, clickable Home logos, persistent desktop shell for History
and saved Insight readers, and faster image delivery. These repairs preserve
existing data/flows. Their original maintenance evidence below predates the
later auth/profile scope and independent component bumps.

- README uses authored desktop/phone SVG banners, platform-first links, a
  copyable working source URL, quick starts and linked detailed documentation.
  Complete before/after GitHub Markdown previews were reviewed at 390/1440/1728
  in light/dark; all images and five anchors work, with no viewport overflow.
  Better Design comprehension passes; measured spacing has no critical/serious
  findings. Moderate advisories concern inherited GitHub styling.
- Bounded external audit checked 67 current public links with HEAD/GET fallback
  and one retry, separately from all tracked local links. Updated moved Firebase/
  Firestore references and API documentation entry links. The unavailable upstream
  LiveContainer link is replaced by internal verified-feed instructions. All six
  current Insight primary sources work. Historical deployment links are dated
  evidence and are not rewritten into current production claims.
- 30 preceding illustrations still used by screens use sized WebP: 20 retain
  identical lossless RGBA pixels; ten decorations preserve exact resized alpha
  and complete silhouettes. Total bytes drop from 15,806,186 to 2,875,132 (81.81%).
  Platform icons stay PNG; original artwork and generation provenance remain
  recoverable from Git history. Current hashes are in the
  [optimization manifest](../../frontend/assets/artwork/optimized-assets.json).
- Eleven new illustrations are dedicated to History, Saved, Recent scans, 404
  and seven Sources slots. The new Recent scans botanical SVG is exclusive to
  that card. Four unused images and the banned branch are removed; historical bytes remain recoverable.
- Desktop History/Sources switch content in the fixed header/sidebar shell.
  Desktop readers have no whole-shell transition. The 404 loading fallback ends
  at a first frame that already has navigation; early recovery survives delayed
  restore and account changes. Logo hover grows slightly without a tooltip.
- Recent scans uses a 208 px natural minimum, dot trailing spacing is
  removed, and supporting Insight cards center image/copy above bottom badges.
  Large text can grow all cards. Existing phone navigation and real actions remain.
- Sources has a single desktop heading inside its illustrated intro, with no
  separate Back/title row. Phone cards have larger icons/art, no chevrons and
  concise summaries. Each whole card opens the complete source explanation.
- Web/app integration and final hosted checks are recorded in the receipt below;
  they are separate from the earlier immutable native artifact build.

## Auth/profile follow-up — 13 October

The current scope adds six reference auth states with exclusive fresh illustrations,
Google/password linking under one verified UID, optional gender/default avatars and
a bounded private thumbnail in the existing Firestore database. Unset gender uses
the user-approved male avatar; Google gender is not requested or inferred. Label
photos/raw OCR remain outside library/profile sync. The sole new direct-client
access is strict owner-only `profile_media/{uid}`; public/library/AI collections
remain denied. Sources and Profile detail windows, three-second Home rotation and
phone History/Saved alignment are included. The filled brand leaf and no-scroll
single-screen auth composition must pass rendered review before reference acceptance.

[Account/profile contract](../architecture/ACCOUNT_PROFILE.md) records configuration,
thumbnail bounds and signing/email-handler gates. Local checks, provider configuration,
actual hosted behavior, native publication and physical-device acceptance remain
separate. Final totals/identities belong to the maintenance receipt after verification.

## Vercel Git retrieval recovery

The backend deployment `dpl_4knV7cBZ88WGpQFdjDY8ZmmV63LC` failed with
`git_info_fail` before a build started (no build events). The following Git push
retried normally: backend `dpl_2jrYwftiptFZJHbBFgV1Lt9bWJ6B` and frontend
`dpl_3fNTz3WwYZFoqAsj5QDDnNGj3o3C` are READY from `6475094`. Public backend
health/meta return 200 with version 0.12.0 and the preserved catalogue/research
counts. No backend dependency or Vercel configuration change was necessary for
that transient Git retrieval failure.

[Machine receipt](../research/MAINTENANCE_2026_10_12.json).
