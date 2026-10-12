# Repository and mobile release workflows

[maintenance-ci.yml](maintenance-ci.yml) runs on main pushes, pull requests and
manual dispatch. It checks maintained scripts/Markdown/JSON, canonical metadata,
tracked OCR/icons, Python lint and release guard tests; rebuilds the read-only
backend bundles from committed public sources; runs synthetic backend tests; and
analyzes/tests/compiles the Flutter web client. It uses standard Ubuntu runners,
locked Python dependencies and the Flutter pin in `scripts/workspace.json`.
Provider credentials, Firebase deployment and native signing are outside CI.

[manual-release.yml](manual-release.yml) runs only through **Run workflow**.
Its inputs are `source_ref` (default `main`), `backend_url` (default
`https://unlabel-api.vercel.app`) and `publish_release` (default `true`).
`frontend/pubspec.yaml` supplies the version and build number; the same metadata
goes into Android, iOS, Dart runtime and the release manifest. There are no manual
version overrides or duplicated version defaults. The source must have the same
workflow/release helpers as the default branch for automatic token authorization.

The checks job resolves one source SHA, verifies OCR/icons and runs Flutter
analysis/tests. Android explicitly selects Java 17, resolves SDK/NDK requirements
from the pinned Flutter SDK, prepares them before Gradle, and restores Flutter,
NDK and Gradle caches. Disposable CI settings bound Gradle to a 4 GB heap and two
workers and disable filesystem watching. SDK preparation has a 20-minute limit;
APK compilation has a separate 35-minute limit within the 60-minute job.
Build/Gradle diagnostics are retained for three days even after a build failure.

The iOS job uses the standard `macos-15-intel` runner to avoid the reported macOS
ARM queue-capacity pool. This can still queue and does not guarantee capacity.
It builds a release **iPhoneOS device app**, verifies identity/version/arm64 and
unsigned status, then packages the IPA preserving symlinks. Intel host hardware
still cross-compiles an arm64 iPhone app; this is not a simulator package.

Both mobile builds must pass. Publication creates a **draft prerelease** tagged
`frontend-vVERSION+BUILD`, attaches APK/IPA, toolchain/package metadata, manifest
and SHA-256 checksums, then verifies uploaded names/sizes/states/digests before
publishing. Existing native tags/releases/assets are immutable. Historical
`mobile-vVERSION+BUILD` tags remain valid. Set `publish_release: false` for a draft;
a draft never updates the iOS source. Source-only `frontend-vVERSION` and backend
source releases remain separate. No component version is increased by this work.

The APK uses the generated Android demo debug key; upgrading older demos may
require uninstalling them. The IPA is unsigned. LiveContainer can import it and
provide host signing; normal device installation requires separate signing.
Actual iPhone launch, camera, authentication and LiveContainer compatibility
remain device checks. The original capacity notice was informational: that iOS
job succeeded, while Android timed out before the release job could run.

After a verified native release is published, `scripts/ios_source.py` generates
the AltStore-style listing from the actual IPA (bundle ID, version/build, minimum
iOS, size/hash and permissions). `scripts/mobile_release.py` updates only the
explicitly mutable `apps.json` asset in the dedicated `ios-source` prerelease,
after uploading/verifying its replacement. It retains published native assets and
version history. The source release is never marked GitHub's latest product release.

Add this stable URL in **LiveContainer → Sources → +**:

<https://github.com/Vaibhavsh0120/Unlabel/releases/download/ios-source/apps.json>

The URL becomes available after the first verified source publication. Use only
an [official LiveContainer build](https://github.com/LiveContainer/LiveContainer)
and its supported signing setup. The format follows
[AltStore's source documentation](https://faq.altstore.io/developers/make-a-source).

The repository is public; its standard hosted runners are free under GitHub's
[published runner policy](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
No paid runner or card is configured. Actions use pinned revisions, dependency
caches and short artifact retention. `contents: write` is limited to the release
job and uses only the automatic `GITHUB_TOKEN`; backend URLs contain no secrets.
Backend/website Vercel deployments, hosted health and real-device proof are
separate gates. See [release/versioning](../../docs/planning/RELEASE_VERSIONING.md).
