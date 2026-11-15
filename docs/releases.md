# Releases

Release from a reviewed source commit on `main`. Complete the relevant
[verification](verification.md) first. Source push, deployment, native publication
and physical-device acceptance are separate results.

## Canonical metadata

| Value | Source |
| --- | --- |
| Frontend version and build number | [frontend/pubspec.yaml](../frontend/pubspec.yaml) |
| Backend version | [backend/pyproject.toml](../backend/pyproject.toml) |
| Flutter toolchain | [scripts/config/workspace.json](../scripts/config/workspace.json) |
| API and stored-data contracts | [contracts](../contracts/README.md) |

Inspect versions without copying defaults into scripts or workflows:

```powershell
python scripts/release/version_metadata.py --component frontend --format json
python scripts/release/version_metadata.py --component backend --format json
```

Each new distributable frontend update needs a higher build number. Product
versions, API compatibility, stored-data schemas and knowledge versions remain
independent. Export and review backend schemas when contracts change; preserve
historical contract fixtures and published tags.

## GitHub Actions

Workflows are event-driven or manually dispatched. Do not add GitHub Actions cron
schedules for reminders, maintenance or polling. Application background work runs
in the hosted worker/scheduler services.

| Workflow | Trigger and responsibility |
| --- | --- |
| [Build and tests](../.github/workflows/maintenance-ci.yml) | Main pushes, pull requests and manual dispatch run repository/backend/frontend checks and isolated guest-lifecycle tests |
| [Frontend APK and IPA](../.github/workflows/frontend-release.yml) | A canonical frontend version/build increase triggers native packaging; manual dispatch supports controlled retries and drafts |
| [Release organization](../.github/workflows/release-organization.yml) | Release/workflow events or manual dispatch classify releases and select the verified app release as Latest |

The native workflow resolves one source SHA, restores locked dependencies,
checks source assets and tests, then builds the Android demo APK and unsigned
iPhoneOS IPA. Its backend-origin input must match the endpoint actually verified
for that client. Backend-only changes do not require new native artifacts unless
the client or selected endpoint changes.

Publication stages assets as a draft, verifies metadata and uploaded hashes, then
publishes when requested. Incomplete uploads remain drafts. Published assets are
immutable; do not overwrite or relabel an old binary as a new build. Build reports
belong in CI artifacts rather than the public app-download list.

## Tags, downloads and iOS feed

New source tags identify the component, such as `backend-vVERSION` and
`frontend-vVERSION`. Native frontend tags also include `+BUILD`. Preserve older
tag naming and existing releases. Historical verification is available from
[GitHub releases](https://github.com/Vaibhavsh0120/Unlabel/releases), their source
tags and commit history; old checkpoints are not current runtime instructions.

GitHub Latest belongs to the newest verified frontend app release. Backend and
source-only releases must not displace it. The organization workflow verifies the
successful publishing run, source identity, asset ownership and feed integrity
before promotion.

The stable [LiveContainer source](https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json)
is updated only from a verified published frontend IPA and its manifest. Preserve
previous feed versions and the stable URL. Feed delivery proves distribution,
not successful import or execution on an iPhone.

Android demo signing and an unsigned IPA are development distribution modes.
Production signing, store distribution and physical-device acceptance require
their own verification. Signing identities and private keys stay outside Git and
outside compiled application assets.

Deployment and legacy-service retirement follow [the deployment guide](deployment.md).
