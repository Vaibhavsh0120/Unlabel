# Manual mobile release workflow

[manual-release.yml](manual-release.yml) is executable after it is committed to
the repository's default branch. It runs only through **Run workflow** in the
GitHub Actions tab (`workflow_dispatch`); pushes and tags do not trigger it.
Remote build and release results are recorded by the action run and manifest.

Inputs are `source_ref` (default `main`), `release_version` (`0.6.3`),
`build_number` (`10`), `backend_url` (`https://unlabel-api.vercel.app`), and
`publish_release` (default `true`; select `false` to retain a draft).
The version/build defaults match the current `frontend/pubspec.yaml` value,
`0.6.3+10`. Both inputs remain editable for the selected source reference and
override the pubspec value for both mobile builds.
Increase the build number for a new build and choose an unused release version.
The source must contain the same workflow files as the default branch for the
automatic GitHub token's release authorization.

The workflow pins Flutter 3.47.4 and action revisions. It resolves one commit,
runs Flutter analysis/tests, builds a demo APK on Linux and an unsigned device
IPA on macOS, then attaches both assets, toolchain records, SHA-256 checksums,
and a build manifest to a **draft prerelease**. All required jobs must succeed.
Only after uploaded asset names, sizes, states, and available remote digests
are verified does `publish_release: true` publish it. Select `false` for manual
draft review. Existing tags/releases are not overwritten. Failed upload or
verification leaves the release draft for review.

The APK uses the generated Android debug key as a demo signing identity;
it is installable for testing but does not provide a stable production update
identity. The IPA contains the iPhoneOS device app and preserves symlinks, but
is **unsigned and not directly installable**. No Apple credentials are needed
to build this artifact; actual device installation requires valid signing.

Standard hosted runners can run without a card within GitHub's applicable
free allowances; private repository quotas can block runs when exhausted.
The workflow uses short intermediate-artifact retention and no paid runners.
It only needs the automatic `GITHUB_TOKEN`; `contents: write` is limited to
the release job. Provider keys must never be supplied as `backend_url`.

Native artifacts use separate `mobile-vVERSION+BUILD` tags. The backend and website
are independently deployed through their Git-connected Vercel projects; this
workflow builds only frontend mobile artifacts.
See [release/versioning](../../docs/planning/RELEASE_VERSIONING.md) and
[deployment](../../docs/architecture/DEPLOYMENT_PLAN.md).
