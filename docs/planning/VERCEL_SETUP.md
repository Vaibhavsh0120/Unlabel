# Vercel projects and public URLs

Configured on 5 October 2026. Both existing projects stay connected to `Vaibhavsh0120/Unlabel` on GitHub. Production follows `main`; each new push triggers Vercel's Git integration for both projects. The native APK/unsigned-IPA workflow remains manual.

| Part | Project | Public production URL | Root |
| --- | --- | --- | --- |
| Website | `unlabel-frontend` | [unlabel-india.vercel.app](https://unlabel-india.vercel.app) | `frontend` |
| Backend | `unlabel-backend` | [unlabel-api.vercel.app](https://unlabel-api.vercel.app) | `backend` |

The new `vercel.app` domains are verified free aliases, not purchased domains. Existing aliases remain attached, including `unlabel-frontend.vercel.app` and `unlabel-backend-pied.vercel.app`. Vercel Authentication protects preview deployments; production is public so ordinary browser/native requests do not require a Vercel account. AI remains disabled.

## Website settings

- Framework: **Other**; install command skipped.
- Build: `bash tool/vercel-build.sh`; output: `build/web`.
- The tracked build script supplies Flutter **3.47.4** from the official SDK Git tag, checks that version, uses the tracked dependency lockfile and builds web in **release** mode.
- Public `BACKEND_BASE_URL=https://unlabel-api.vercel.app` is supplied through `--dart-define`. Version/build come from `pubspec.yaml`, currently **0.0.0+1**; Vercel supplies the source commit SHA. The starter does not consume `BuildInfo` yet, so release tree shaking can remove unused constants; no API client or visible version panel is claimed.
- `frontend/vercel.json` stores reproducible build settings. SDK/build output stays ignored. Hash routing uses the existing starter; no blanket rewrite turns missing assets into successful HTML responses.

The starter contains no product API request yet. Passing the URL config prepares the teammate's future API adapter; it does not implement scanning or analysis.

## Backend settings

- Framework: **FastAPI**, Python **3.12**, entrypoint `app.main:app`.
- Vercel installs the declared Python runtime dependencies. `[tool.vercel.scripts]` in `backend/pyproject.toml` then runs `python build_catalogue.py`; project-level build overrides must not suppress this hook. It generates verified catalogue SQLite/receipt and approved claim JSON/receipt before the application is packaged as one Function. Stdout is one JSON object with `catalogue` and `claims_knowledge` receipts.
- `backend/vercel.json` limits this Function to 60 seconds; OFF lookup has its own 8-second deadline and 512 KiB decoded response budget.
- `backend/.vercelignore` and Function `excludeFiles` exclude env files, development environments/tests/caches and private runtime storage. Generated `app/catalogue/data/` and `app/claims/data/` are ignored by Git but retained for validated function packaging.
- CORS allowlist: `https://unlabel-india.vercel.app` and the existing `https://unlabel-frontend.vercel.app`. Native clients can call the same public API. CORS is not authentication.
- The local v0.5.0 target environment uses `OFF_USER_AGENT=Unlabel/0.5.0 (https://github.com/Vaibhavsh0120/Unlabel)`, `OFF_TIMEOUT_SECONDS=8`, `OFF_MAX_RESPONSE_BYTES=524288`, `CORS_ORIGINS` and `AI_PROVIDER=disabled`. Hosted catalogue settings are `CATALOGUE_DIRECTORY=app/catalogue/data` and `CATALOGUE_REQUIRE_RECEIPT=true`. Public OFF reads and catalogue builds require no key. No Gemini key is configured or required.

No live FSSAI request or writable cloud database is required for existing OFF/normalization/claims; v0.4.0 community observations use separately configured free Firestore. Confirmed nutrition and claim POSTs have a 32 KiB actual body cap and work without OFF connectivity; exact-origin CORS permits GET/POST, Content-Type and Authorization. The current catalogue build reads only the tracked public source: it performs no acquisition, env decryption or world download. New hosted settings activate only after deployment. Never run bulk import inside a scan request. [Nine-calendar-month source/deployment replacement](../architecture/CATALOGUE.md).

## Push and verification

Update docs and run relevant checks before each push. Both projects use their own root-level config files; no repository-root `vercel.json` competes with them. Unaffected-project skipping is disabled to match the requested every-push deployment behavior. Free build/hosting allowances remain finite.

After pushing, match each deployment's Git SHA to the intended commit. Check the website, `/v1/health`, `/v1/meta`, `/openapi.json`, `/v1/catalogue`, representative found/absent catalogue identity/facts codes, facts capability/availability/image attribution, one bounded live product/nutrition lookup, confirmed normalization, exact-origin CORS/preflight and invalid input. Check source date/hash/counts and the receipt-verified artifact summary, and confirm env/database paths are not served publicly. A READY build alone is not endpoint evidence.

Initial imports deployed the foundation commit without the new service/build script. The first corrected push, `0c10e0b807948d70d3327517387f1db8cddc52c7`, automatically produced READY production deployments for both projects:

- Website: `dpl_in9NzBZaSEsZdSfT8XVFoQmWcfK2`; pinned SDK/lockfile and release web compilation succeeded. The public page and JavaScript returned 200, and Chrome rendered the Flutter starter. Unpublished source/environment and missing JavaScript paths returned 404.
- Backend: `dpl_6uCtKb2CbnMtFWu6U35jLarubt3R`; public health/meta/OpenAPI returned 200, live schema matched the export, invalid barcode returned 422, and a live OFF lookup returned 200/found. Exact frontend CORS and preflight passed; an unrelated origin was not allowed.

These HTTP checks used no Vercel login cookie or bypass token. This verifies initial production deployment and provider connectivity, not future scanner/analysis behavior or Indian-market coverage. Later docs-only pushes redeploy the same service/frontend source. See [v0.1.0 historical validation](BACKEND_V0_1_0_REVIEW.md) and [v0.2.0 validation](BACKEND_V0_2_0_REVIEW.md) for version-specific gates.

Backend v0.2.0 source commit `2d6763674f737b3b171e207b915f24f1ee33a227` also automatically produced READY deployments: backend `dpl_Dc6jieG7Z1ARefhDF4aXFyhUUznR`, website `dpl_67K6LAYYWGxBNk8uTYHLuZdPQGXZ`. Public health/meta/OpenAPI, nutrition/legacy product reads, confirmed POST, POST preflight, sanitized 422/413 and website assets passed. [Detailed release evidence](BACKEND_V0_2_0_REVIEW.md). A later documentation-only commit uses the same application source; no mobile action was dispatched.

References: [Vercel monorepos](https://vercel.com/docs/monorepos), [FastAPI deployment](https://vercel.com/docs/frameworks/backend/fastapi), [Python runtime/version](https://vercel.com/docs/functions/runtimes/python), [Flutter web release](https://docs.flutter.dev/deployment/web), [Vercel Authentication](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication).

## Historical backend v0.2.1 configuration

At v0.2.1, the backend used Unlabel/0.2.1 and an explicitly empty hosted `CATALOGUE_DIRECTORY`; snapshot lookup remained inactive. The public source was tracked for clone recovery while generated local SQLite stayed excluded from Git deployments. [Historical recovery guide/review](RECOVERABLE_WORKSPACE_REVIEW.md).

## Historical backend v0.2.2 catalogue configuration

The new backend build reads tracked `data/catalogue/` through outside-root build access, validates the gzip/metadata and writes `app/catalogue/data/catalogue.sqlite3` plus `receipt.json`. Startup requires receipt/hash/manifest/integrity/count validation before enabling catalogue reads. The published source date remains 2026-10-05T12:19:34Z; rebuilding does not reset its nine-calendar-month age or resolve unverified coverage. Failure leaves catalogue unavailable while health/meta/live adapters remain usable.

Implementation commit `2df4fb9be0d1cca4440ad659c677250dacd379e5` automatically produced READY backend `dpl_898Km4txv66J7GA5bRTCFrPmrRrd` and frontend `dpl_8aTkrJancwVP4i9P22fEBx9b9drf`. Backend logs confirm the build hook; its emitted SQLite receipt agrees with public status. Catalogue found/404/422, source date/hash/counts, live APIs/normalization, CORS, current OpenAPI and excluded URL paths passed. [Full v0.2.2 review](BACKEND_V0_2_2_REVIEW.md) · [Dated HTTP/build evidence](../research/BACKEND_V0_2_2_PRODUCTION.json).

A source refresh creates a new immutable deployment; failed builds must not be promoted and rollback restores the prior deployment with matching source/configuration. This release did not perform a production failure/rollback drill. No runtime file replacement, automatic refresh schedule or upstream bulk download runs on a push. Plaintext credentials/private identities/scans stay outside Git; `.env.age` is clone recovery ciphertext and is excluded from the function. [Catalogue guide](../architecture/CATALOGUE.md) · [Local restore/run](LOCAL_DEVELOPMENT.md).

## Backend v0.2.3 rich-facts gate

The same build/receipt settings package the validated India source with optional rich facts. No full JSONL acquisition or image download runs in Vercel. `catalogue_facts` activates only after a facts-enabled index passes startup validation; the separate facts response preserves direct-table community provenance, tag availability, optional record dates and official image attribution. Claims remained disabled in this independently released v0.2.3 slice.

Complete JSONL acquisition has validated EOF and measured counts/hashes; source **2026-10-06T06:53:46Z** is due **2027-07-06T06:53:46Z**. The tracked replacement and all 24,641 facts validate; its local SQLite/receipt verifies at 62,472,192 bytes. Implementation `56064d7fd13d585c949eb2d31a53eb3884a5d520` independently produced READY backend `dpl_HgRKWoonZJSoGRr1ZaoHDwThSbrF` and frontend `dpl_64ccpc7XUCW8CkCEpChAk1SR1kSe`. The actual build receipt matches the public 62,472,192-byte SQLite, hash `fb194302905d55d182572988d894ca86d5653d6b9c623c880d99325ecafea165` and snapshot `eea89670-b5e7-4980-b49c-d5e49eaebdb1`. Source/count/date/facts/identity/OpenAPI/normalization/CORS/excluded-file checks and website bootstrap passed. [Dated 20-check production report](../research/BACKEND_V0_2_3_PRODUCTION.json) · [Full v0.2.3 review](BACKEND_V0_2_3_REVIEW.md). Source-only tag `v0.2.3` points to this tested implementation; proceed to v0.3.0 separately.

## Backend v0.3.0 reviewed-claims gate

The combined network-free build validates and packages exactly the seven-rule JSON and three-source registry with a strict hash/length receipt under `app/claims/data/`. `VERCEL=1` requires receipt verification even when `CLAIMS_KNOWLEDGE_DIRECTORY` explicitly overrides the location; no source fallback is allowed for missing or invalid hosted knowledge. Metadata reports `claim_checks`, `claims-2026-10-06.1` and a verified `knowledge_artifact` summary. Claim failure isolates only claim/rule/evidence access. No regulator PDF, provider call, writable cloud database or new account is required.

The final network-free two-bundle build, noninteractive backend setup, **543-test suite**, **59-file static check** and **150-test independent review** passed with no remaining findings; all Markdown/scripts and syntax/artifact boundaries were reviewed. Implementation `ba44cbd26cf3c5ee306449c28fbb0c40dea0ba2e` independently reached READY on backend `dpl_7mE2QodTDT6NicE3gz1K7yuWuFqH` and frontend `dpl_CpKhKmJ3qDSBZqRqqsx1iyp2UmAg`. **72 public HTTP checks passed**, matching both actual hosted build receipts to public catalogue/knowledge metadata and confirming all reviewed claim thresholds, insufficient/conflicting/context cases, evidence records, old APIs, OpenAPI, POST validation/body limits, CORS and excluded package/private URLs. [Dated production evidence](../research/BACKEND_V0_3_0_PRODUCTION.json) · [Full v0.3.0 review and published source tag](BACKEND_V0_3_0_REVIEW.md). Future pushes still require their own build/endpoint checks; frontend integration remains pending.

## Backend v0.4.0 community deployment gate

Released v0.4.0 implements fifteen routes. Firebase Unlabel/project
`unlabel-india-catalogue` has its first Standard database `unlabel` in Mumbai with
free tier/no linked billing, anonymous Auth, deny-all client rules and dedicated
backend IAM. Set the explicit community enabled/project/database and secret
service-account/actor-key settings through hosted environment controls; never
publish those secrets. Safe clones default to disabled storage. No paid services,
TTL, backups or billing upgrade are permitted. Firestore RPCs have bounded
three-second deadlines/three transaction attempts, and public lookup performs no
per-read writes; OFF keeps its independent eight-second default timeout.

Source commit `d793f628581f509481d6dc60a82afe59ca013439` independently reached READY
on backend `dpl_8oGRZz2v6WZgnkQkBi9ShrAkdWNB` and frontend
`dpl_DrcUBiaR7s3e9uRTpo2owuF1vjZG`. Sixteen hosted HTTP checks verified v0.4.0,
metadata readiness, source-qualified lookup, anonymous write/own receipt/retry,
old APIs, strict failures and matching OFF/claim receipts. Synthetic records and
anonymous identities were removed. Source-only v0.4.0 was published separately.
[Dated production proof](../research/BACKEND_V0_4_0_PRODUCTION.json)
· [Published v0.4.0 review](BACKEND_V0_4_0_REVIEW.md)
· [Community configuration](../architecture/COMMUNITY_CATALOGUE.md).

## Local v0.5.0 report deployment gate

Local source mounts eighteen routes, adding current-label reports, read-only
historical barcode reports and the three-entry reviewed glossary. Focused
API/contracts pass; full review, push and hosted verification remain pending,
with production still v0.4.0. No new provider, secret, billing account or service
is required. The bounded tracked glossary projection is packaged with application
source, independently of unchanged OFF/claim build receipts.

After the separate push, verify the intended Git SHA, eighteen-route OpenAPI,
report/glossary metadata and artifact, corrected barcode-less report, original
12 g/40 g sugar producing approximately three cubes, historical read-only
evidence, automatic saving and its independent failure outcomes. Recheck old
APIs/receipts, strict bodies/redacted failures, exact-origin CORS and excluded
private/source URLs. A READY deployment alone does not close these gates.
[Report contract](../architecture/LABEL_REPORT.md).
