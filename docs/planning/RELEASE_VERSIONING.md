# Release and versioning

Maintenance started at frontend **0.7.0+11** and backend
**0.12.0**. Components deploy independently. Historical reviews and manifests
remain bound to their source commits; a documentation change does not replace
that identity. See [release ledger](CONTROLLED_RELEASES.md).

## Canonical versions

| Component | Edit for a future version change | Consumers |
| --- | --- | --- |
| Frontend | `frontend/pubspec.yaml`: `version: SemVer+BUILD` | Flutter platform versioning, Dart build metadata, local/Vercel and automatic native builds |
| Backend | `backend/pyproject.toml`: project.version | Backend runtime/API and setup/acquisition metadata |
| Toolchain | `scripts/config/workspace.json` | Pinned Flutter used by setup and workflow metadata |

Use `python scripts/release/version_metadata.py --component frontend --format json`
or `--component backend` to inspect canonical values. Native builds read
the selected source's pubspec; there are no repeated version/build defaults to
edit in workflow YAML. Both platforms use the selected source's canonical version
and build number. Product version is not an API
major, schema or knowledge version. `/v1/meta` negotiates those independently.
Allocate a new build number for a new distributable update; published artifacts
are immutable. The 14 October release uses **frontend 0.9.0+13** and **backend
0.13.0**, replacing frontend 0.8.0+12/backend 0.12.1. Provider management/account
deletion and the additive DELETE endpoint justify minor versions. Native build
13 follows 12; snapshot schemas and API major remain unchanged. Source commit
`bd06bfb` passed repository CI and deployed to web/API. Publication and hosted
receipts are in the [release ledger](CONTROLLED_RELEASES.md), [frontend review](FRONTEND_V0_9_0_REVIEW.md)
and [backend review](BACKEND_V0_13_0_REVIEW.md). The superseded 0.8.1 working note
was never a release.

The preceding 15 October source checkpoint uses **frontend 0.10.0+14 / backend 0.14.0**.
The last published GitHub versions were checked directly before choosing this
increment. Scanner flows, unified Product Info and additive machine/live lookup
contracts justify minor versions; native build 14 follows 13. API major and
existing stored-report schemas stay unchanged. The same version increase triggers
the existing automatic APK/IPA publication and stable feed workflow.

The 26-27 October source task advances to **frontend 0.11.0+15 / backend 0.15.0**.
The compact Product Info redesign, free native/web barcode scanner and Safari
camera lifecycle fixes justify the frontend minor release; independently optional
sources and finite NutriGraph sandbox guards justify the backend minor release.
Native build 15 follows 14. The API major and saved-report schemas are unchanged.
Current local evidence and remaining hosted/provider/device gates belong to the
[frontend review](FRONTEND_V0_11_0_REVIEW.md) and
[backend review](BACKEND_V0_15_0_REVIEW.md). Add historical source-ledger records
only after an exact implementation SHA exists; do not invent source tags or
native-publication proof before the corresponding publication is verified.

Current-status docs are dated checkpoints. Write a future review/ledger entry
for a new release; do not rewrite old reviews, receipts or source references.

## Source and native identities

New source tags use `backend-vVERSION` and `frontend-vVERSION`. Earlier backend
`vVERSION` tags remain preserved. New mobile assets use
`frontend-vVERSION+BUILD`; existing `mobile-vVERSION+BUILD` and starter `v0.0.0`
remain historical. Release titles identify backend, frontend source or frontend
mobile artifacts explicitly. Source releases do not prove native installation.

[Release workflow](../../.github/workflows/frontend-release.yml) detects canonical
version/build increases on main and automatically builds a demo APK
on Linux and an unsigned iPhoneOS IPA on a standard Intel macOS runner. It
resolves one source SHA, checks lockfiles/icons/OCR/tests, prepares/cache-checks
toolchains and verifies artifact structure, versions and hashes. It creates a
draft, verifies uploaded assets, then publishes when `publish_release` is true.
Only APK, IPA and an apps.json snapshot are attached; build reports remain in CI
artifacts. The universal ios-source/apps.json subscription URL never changes.
Manual dispatch is retained for retries/drafts. An incomplete upload remains a draft. Existing release assets are not overwritten.

The manifest records source/workflow SHA, canonical and effective versions,
toolchains, endpoint, signing mode, tests and per-asset SHA-256. Secret keys,
private identities and scans are never compiled into assets. Flutter pins and
workflow action SHAs are deliberate; upgrades need separate validation.
[Workflow inputs and checks](../../.github/workflows/README.md).

## LiveContainer source

The hosted AltStore-compatible feed is
[apps.json](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json).
Add that URL in LiveContainer's source list, select Unlabel and import/download
the device IPA. The source has its own clearly labeled prerelease and is updated
only from a verified published frontend mobile manifest and IPA asset. It does
not pick backend releases or an unfinished draft. Release assets/version history
retain their identities when the feed is refreshed.

The IPA contains `Payload/Runner.app` for iPhoneOS and preserves symlinks. It is
unsigned. LiveContainer must already be installed/configured through a suitable
sideload route; actual import/execution and native services require device tests.
Publishing the feed does not establish App Store signing or physical accuracy.
The Android demo APK now uses a stable private Actions keystore registered with
Firebase, and publication verifies its certificate. Preserve that demo key for
future updates. Older APKs signed by disposable runner keys may need uninstalling
first; production signing remains a separate private-key setup.
[Account/native OAuth setup](../architecture/ACCOUNT_PROFILE.md).

## Build and deployment boundaries

Vercel deploys web and API separately from main. Local tests, successful native
builds, source publication, hosted API/web proof and physical-device behavior
are independent gates. Backend releases do not trigger native rebuilds. Native
apps retain their compiled HTTPS endpoint until updated; additive API contracts
and historical source responses remain compatible.

Use standard hosted runners. Public repository jobs use GitHub's applicable free
allowances; no larger paid runner or card is configured. A runner capacity notice
describes scheduling, not an iOS compilation failure. A build timeout requires
build-stage evidence and a fresh run after repair.

Official references: [Flutter Android](https://docs.flutter.dev/deployment/android),
[Flutter iOS](https://docs.flutter.dev/deployment/ios),
[GitHub manual runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow),
[standard runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Use the [LiveContainer source instructions](../../README.md#use-unlabel) for
Unlabel's verified hosted feed; the upstream project link was unavailable during
the 12 October link audit.
