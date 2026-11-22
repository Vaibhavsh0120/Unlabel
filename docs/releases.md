# Releases

## Label Studio and feature update

The current update redesigns product results with the approved forest/mint
identity band, pinned section navigation and responsive nutrition/ingredient/
evidence cards. It enables self-hosted AI and community persistence, deploys the
separate evidence archive worker, and adds a responsive HTML welcome email with
a plain-text alternative. Gemini's provider coordinates are converted explicitly
before strict validation. NutriGraph was removed completely after refreshed-key
failures, as requested by the operator. Reviewed packet research now has a
previewable, overridable current-snapshot import command; recovery history and
the original licensed source bundle remain intact. See
[Product Info](architecture/PRODUCT_INFO.md),
[optional sources](architecture/OPTIONAL_SOURCES.md) and
[research updates](architecture/CATALOGUE.md#reviewed-research-updates).

Opening a scan no longer creates a scan-ready inbox item. Previously stored
scan-ready activity entries are hidden on inbox load; saved-report notices,
reminders and app updates remain available. Local preview startup now reports
Flutter build progress before printing its ready URL.

Release from a reviewed source commit on `main`. Complete the relevant
[verification](verification.md) first. Source push, deployment, native publication
and physical-device acceptance are separate results.

The current repair is v1.1.1 (frontend build 22): immediate email signup,
separate welcome mail, corrected Google OAuth setup and popup-free login,
shared search/product navigation, sourced search thumbnails and a shorter web
deployment pipeline. Hosted signup/profile/isolation/deletion checks passed.
Google consent, inbox receipt and published native assets require their own
observed evidence; the version number alone does not establish them.

Build 22 includes the native Google nonce exchange and the first-password flow for
Google accounts. Account methods/password setup are pages; explicit Google
security actions use a normal tab with an opener-independent callback. The auth
review also adds owner checks on update responses, useful credential-conflict
messages and the backend's password byte limit in forms. Hosted synthetic checks
passed passwordless-session password setup, same-UID password login/change,
refresh, logout revocation and recovery. Device Google account selection and
inbox receipt remain separate from these automated checks.

This build also groups Clear all with the read controls below an aligned inbox
heading, shortens the
phone reminder card, and uses compact inbox rows. Clearing remains device-local,
preserves reminder settings/reports and keeps cleared app updates dismissed.
The API repair explicitly permits browser `PUT` preflights for password/profile
writes while retaining the exact allowed origin. Mobile checks wait for the real
PKCE redirect event instead of assuming cryptography finishes in one event-loop turn.

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
