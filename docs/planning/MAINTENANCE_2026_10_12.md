# Maintenance audit — 12 October 2026

Scope: repair documentation, setup/release scripts, GitHub configuration and
native builds. Keep frontend 0.7.0+11 and backend 0.12.0. No feature work.
Work on main, preserve source bundles and historical release identities.

| Finding | Evidence | Action and verification |
| --- | --- | --- |
| F-01: Android release timed out | Run 38044207593: checks/iOS succeeded; Android stopped during assembleRelease. Pasted log includes in-build NDK download and filesystem-watcher diagnostic. Full archived logs are unavailable. | Explicit toolchain preparation, dependency caching, bounded build logging and CI watcher configuration; verify with a fresh native workflow run. |
| F-02: repeated version edits | Pubspec, Dart fallback and workflow defaults repeat frontend version; pyproject and backend runtime repeat backend version. | Read the two canonical component files; test default and override metadata and ensure deployment inputs agree. |
| F-03: stale active docs | Architecture/index/setup docs still name older current releases, 21-path API or planned OCR; runtime exports 27 paths/28 operations. | Correct active docs, preserve dated reviews/receipts, run Markdown/link/schema/script validation. |
| F-04: incomplete GitHub releases | Source releases stop at backend 0.7/frontend 0.3; a mobile draft uses an explicit source/version override. | Publish missing already-reviewed source identities, label components and historical override accurately, preserve old tags/assets. Verify remote release targets. |
| F-05: unused scaffolding/assets | Import graphs retain every runtime module; two decorative images and Cupertino dependency have no callers; empty placeholders describe obsolete architecture. | Remove only demonstrably unused content, retain platform stubs and historical asset evidence; run app analysis/tests/build and source checks. |
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

Native CI and LiveContainer source publication are pending the fresh dispatched
workflow. Physical iPhone import/launch remains a separate acceptance gate.
[Machine receipt](../research/MAINTENANCE_2026_10_12.json).
