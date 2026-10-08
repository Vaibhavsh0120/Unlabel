# Release and versioning plan

Status: connected Flutter client and manual mobile release workflow implemented;
production signing remains future work. Separate Git-connected Vercel projects are configured for automatic website/backend deployment; see [settings and URLs](VERCEL_SETUP.md). Remote native build results
are recorded by GitHub Actions and the resulting release manifest.
Official documentation checked: 2026-10-09 (Asia/Calcutta), with Context7 used
for Flutter and GitHub Actions documentation.

## Targets and current boundary

Plan one product with Android APK, iOS, and website targets.
Hosting uses two Vercel projects: backend and web, with independent frontend/backend versions.
Native artifacts are handled by
[manual-release.yml](../../.github/workflows/manual-release.yml), which runs
only through a manual dispatch after being committed to the default branch.
It creates a draft prerelease, verifies all remote assets, then publishes when
the manual `publish_release` input is true (the default). False retains a draft.

An iOS build artifact and an installable iPhone distribution are different
deliverables. The strict zero-cost, no-card requirement limits the initial
iOS release commitment as described below.

## Version identities

Current frontend candidate: **v0.6.3+10 / backend v0.12.0**. Independent source and
production verification are recorded in [the current frontend review](FRONTEND_V0_6_3_REVIEW.md)
and [backend review](BACKEND_V0_12_0_REVIEW.md). Manual mobile workflow defaults
now match frontend 0.6.3 and build 10. Updating these defaults does not run the
workflow or publish new native artifacts. Older slices below are historical.

Backend **0.7.0 Private Account Sync** and frontend **0.2.0+3 Welcome, Home and
Optional Account** are independently published and hosted-verified. Earlier
backend v0.6.0/frontend v0.1.0 releases remain historical. Frontend **0.3.0+4 Visual
Label Reader** is independently published and hosted-verified from implementation
`3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`, READY deployment
`dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, with 49 hosted checks.
[Source release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0) ·
[Production receipt](../research/FRONTEND_V0_3_0_PRODUCTION.json).
Later docs-only closure commits do not replace its implementation identity.
Backend v0.8.0 was pushed from `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` and hosted-verified with 25 checks at READY deployment `dpl_651iY8R8Dj6wNEdVC71Kw3ZW4oig`; its source-release publication is not established by that receipt.
Historical implementation slices are **backend v0.9.0 Reviewed Ingredient Functions** and **frontend v0.4.0+5 Sourced Comparison and Ingredient Detail**. Each receives independent tests, review, documentation, push and exact-source hosted checks. See [the implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md).
The user authorizes implementation and independent pushes;
frontend v0.3.0 does not depend on the new comparison endpoint. Backend tags remain `vVERSION`; frontend source tags use `frontend-vVERSION`;
manual native artifacts use `mobile-vVERSION+BUILD`. This avoids the historical
backend `v0.1.0` tag collision. All older tags/assets remain preserved.
[Frontend review](FRONTEND_V0_3_0_REVIEW.md) · [Controlled releases](CONTROLLED_RELEASES.md)
· [Next versions](FRONTEND_BACKEND_NEXT_VERSIONS.md).

| Identity | Planned meaning | Compatibility rule |
| --- | --- | --- |
| Component release | Independent frontend/backend SemVer and unambiguous release title/tag | Identifies the released component and reviewed source commit |
| Android build | Increasing integer mapped to `versionCode`; product version maps to `versionName` | Preserve application ID and release signing identity for updates |
| iOS build | Increasing build identifier mapped to `CFBundleVersion`; product version maps to `CFBundleShortVersionString` | Preserve bundle ID and applicable signing/provisioning requirements |
| API major | Routes begin with `/v1` | Additive changes within the supported major; breaking changes require a new major |
| Contract schema | Independently recorded schema version | Preserve strict existing response shapes; new shapes use separate routes/models or a new schema |
| Knowledge version | Reviewed corpus/rule release identifier | Every analysis records the knowledge version used |
| Deployment commit | Full Git SHA for each backend/web deployment | Records running code independently of a native app's frozen build |

Flutter supports separate build-name and build-number overrides and the
platform mappings above. See the official
[Android release guide](https://docs.flutter.dev/deployment/android) and
[iOS release guide](https://docs.flutter.dev/deployment/ios).
Allocate a new mobile build number for a new distributable build; retain it
in the release manifest. Never silently replace a published artifact.

## Manual release workflow design

The release entry point is `workflow_dispatch`, with source reference,
frontend version (default `0.6.3`), mobile build number (default `10`), required
public backend URL, and a `publish_release` boolean (default true).
Python validates environment values without shell interpolation. Version and
build number override pubspec for both artifacts; the manifest records both.
The workflow uses a fixed unsigned iOS lane and a demo debug-signed APK lane.

GitHub requires the dispatch workflow to exist on the default branch and
requires write access to run it. A selected reference is allowed, but the
build plan must resolve that reference once to a full immutable commit SHA.
See [GitHub's manual workflow documentation](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

All jobs check out that same SHA. Do not let individual jobs follow a moving
branch or derive their code from independently selected references.
The manifest records workflow SHA as well. Flutter 3.47.4 and action commit
SHAs are pinned. Source workflow files must match the default branch, because
the automatic token cannot create releases for divergent workflow targets.

1. Validate reference, version, build number, URL, and tag uniqueness.
2. Resolve one commit SHA and expose it as the sole source for all jobs.
3. Run Flutter analysis and tests against that SHA. Backend/web contract
   checks are outside this mobile workflow; backend releases run their own tests and contract checks.
4. Build the demo APK on Linux and unsigned device IPA on macOS/Xcode.
   Backend/web builds and deployments are separate Git-triggered gates.
5. Check artifact presence, version metadata, signing status, and file format;
   generate SHA-256 checksums and a build manifest.
6. Create a draft GitHub Release targeting that SHA and attach verified assets.
7. Verify the complete uploaded asset set, sizes/states, and available remote
   hashes; publish only when requested by the manual input. Otherwise keep it
   draft. Failed builds create no release; upload failures can leave a draft.

A retry must use the original pinned SHA and compatible build identity, or
start a clearly identified new build. Concurrent runs must not publish or
overwrite the same version. Release publication is separate from a Vercel
deployment; a GitHub asset does not establish backend availability.

## Required gates and build manifest

Future gates include meaningful checks for extraction, uncertainty, evidence
references, and request/response contracts. Check both the new client and
supported older native client fixtures against the proposed backend.
The manual workflow checks Flutter tests/analysis and native builds; web CI separately checks analysis/tests before building.
Platform compilation alone does not establish camera or real-device behavior.

The manifest should identify:

- Product version/tag, full source SHA, workflow revision, run ID, and date.
- Flutter/Dart, Android, Xcode/macOS, backend, and web toolchain versions.
- Android/iOS build numbers and target architectures/operating systems.
- Contract schema, supported API major, and reviewed knowledge version.
- Environment name and non-secret backend base URL compiled into each client.
- Asset filenames, sizes, SHA-256 checksums, and test gate results.
- iOS signing/export mode, installation limitations, and any unavailable gate.
- Backend/web deployment SHAs and release-specific verification state.

Do not include keys, certificates, private provisioning material, or personal
profile data in artifacts, manifests, logs, or repository files.

## Honest iOS delivery under zero cost

[Flutter's iOS guide](https://docs.flutter.dev/deployment/ios) requires macOS
and Xcode for iOS builds. A successful signed export produces an IPA; an
`.xcarchive` is an archive used in that process, not proof of installation.

The no-card lane compiles an iPhoneOS device app with `--no-codesign`, then
packages `Payload/Runner.app` with symlinks preserved into a named unsigned
IPA. It checks platform/version metadata and absence of app code signing.
This is a device developer artifact, not an installable signed export.
No simulator test or physical-device test is claimed by this workflow.

Apple permits a free Personal Team to sign and test on personal devices using
Xcode, with periodic reprovisioning. It is not a general distribution path.
See [Apple's developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).
That local testing path also requires access to suitable Apple hardware.

Normal distribution membership costs USD 99 per year, subject to local prices.
An eligible educational institution can request a fee waiver; approval and
institutional signing access must be verified rather than assumed.
See [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/).
Installable IPA distribution remains conditional on a valid signing route.
An IPA attached to GitHub does not bypass device/profile installation rules.

Under the strict zero-cost scope, the required iOS gate is compilation and
clearly labeled development artifacts. The release manifest must say when a
signed installable IPA is unavailable; it must not advertise that gate as met.

The generated Android release configuration uses the debug key. The workflow
verifies that identity and labels the APK as a demo artifact. A stable private
release key and update-signature validation are required before production use.

## GitHub Actions budget boundary

Standard GitHub-hosted runners are free for public repositories, including
available standard macOS runners. Private repositories share plan allowances
for minutes/storage; macOS usage consumes that limited budget more quickly.
Larger runners are charged even for public repositories.
Without a payment method, GitHub blocks use after quota exhaustion.
See [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

Use standard runners, manual releases, short intermediate-artifact retention,
and bounded caches. Recheck repository visibility, current allowances, runner
availability, and account policy before implementation; do not promise an
unlimited private CI service. No card or paid runner is a prerequisite here.

Released v0.5.0 keeps API major/schema 1 and adds report/glossary models rather than
changing released identity/community shapes. Current-label reports and historical
read-only reports remain distinct; F08 stays partial at three reviewed functions.
No mobile build, new provider/key or AI activation is required.

## Client/backend compatibility and deployment order

Compile a stable production backend HTTPS base URL into production clients
through environment configuration. Preview clients use a separate preview
backend and must not silently redirect production apps to a preview deployment.
Provider keys remain on the backend. Native URL changes require a new build.

The implemented `/v1/meta` handshake exposes backend version, API/contract
compatibility, adapter/normalization versions, capabilities, and knowledge
version. It does not currently expose a deployment SHA; the Vercel deployment
record identifies that SHA. `/v1/health` stays separate from provider checks.
Clients use capabilities and schema compatibility, not an exact product-version
equality check. Unsupported functionality receives a clear fallback.

The MVP is online-first. Python owns reviewed rule evaluation; OFF's changing
provider schema remains behind a stable backend adapter. Offline saved reports
retain their original source, date and versions; viewing them does not refresh
criteria or compute new findings. No Dart rule engine/parity system is required.
Frontend v0.3.0's in-memory public-read caches additionally share identical requests
and expire search pages after 60 seconds/reports after five minutes; private account
data and confirmed-label POSTs are excluded. Local OCR keeps photos/raw extracted
text in the capture session, requires human correction/confirmation and preserves
manual entry. The app-only startup screen is excluded from the website.
Product/nutrition provider reads and confirmed-row normalization remain active
in published backend v0.4.0. Separate catalogue status/lookup uses an export-origin contract,
verified deployment receipt and nine-calendar-month source age. Its separate rich-facts route preserves direct-table nutrition, tag availability,
optional record dates and official image URL attribution; legacy aggregates and
missing fields stay unknown. Coverage is unverified; a snapshot miss makes no
OFF request. The separate confirmed-label numerical claim API uses reviewed knowledge `claims-2026-10-06.1`; metadata exposes actual claim readiness and a verified knowledge receipt summary when packaged. Affected unsupported/missing/conflicting/future-dated evidence stays insufficient. Released v0.5.0 adds current/historical reports and a partial three-entry glossary. Published frontend
v0.2.0 includes compatible-basis client comparison. Backend v0.8.0 locally adds
read-only comparison of exact sourced/confirmed tables; its hosted gate is still
pending, and frontend integration follows separately. AI and full ingredient
coverage remain future work.

The strict ProductLookup v1 model/route is unchanged by v0.2.0. Nutrition has
separate lookup/request/response schemas; historical v0.1.0 OpenAPI stays
available. Clients can enable `nutrition_lookup`/`nutrition_normalization`
through metadata and use the additive `catalogue_facts` capability for a
validated facts-enabled store. Released v0.5.0 additionally enables `nutrition_analysis`
and `label_reports`; ingredient explanations require valid glossary metadata. A complete
normalization result is not complete nutrient coverage or a health verdict.

Deploy additive backend dependencies first and verify old-client compatibility
before a frontend begins to require them. The current independent frontend v0.3.0
release uses published v0.7.0 APIs, so it may publish before backend v0.8.0. Source-aware
comparison integration must wait for the latter's hosted gate.

The four additive v0.4.0 routes implement automatic structured public observations,
semantic deduplication, private staging/receipts and typed sourced resolution.
Anonymous writes require verified tokens; tokens never authorize a claim verdict.
Compatible fields retain source/date/originals and conflicts; no generic packet
imputation or current-label confirmation is invented. Safe defaults disable
storage; resolved lookup can still serve available OFF facts. Check actual
capabilities before frontend integration. v0.4.0 hosted verification/publication
passed before v0.5.0 implementation; preserve old APIs through both releases.


Deploy the web project next. Native assets require a separate explicitly selected build/device gate against the stable URL.
Installed native apps remain frozen until users update, so keep supported old
contracts/routes operational. Rollback must pass the same compatibility checks;
do not roll back to a backend that cannot serve already released clients.
Defer breaking API removal until a documented migration and support decision.
