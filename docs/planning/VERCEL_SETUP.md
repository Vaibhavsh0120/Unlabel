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
- `backend/vercel.json` limits this Function to 15 seconds; OFF lookup has its own 8-second deadline and 512 KiB decoded response budget.
- `backend/.vercelignore` and Function `excludeFiles` exclude env files, development environments/tests/caches and private runtime storage. Generated `app/catalogue/data/` and `app/claims/data/` are ignored by Git but retained for validated function packaging.
- CORS allowlist: `https://unlabel-india.vercel.app` and the existing `https://unlabel-frontend.vercel.app`. Native clients can call the same public API. CORS is not authentication.
- The v0.3.0 target environment uses `OFF_USER_AGENT=Unlabel/0.3.0 (https://github.com/Vaibhavsh0120/Unlabel)`, `OFF_TIMEOUT_SECONDS=8`, `OFF_MAX_RESPONSE_BYTES=524288`, `CORS_ORIGINS` and `AI_PROVIDER=disabled`. Hosted catalogue settings are `CATALOGUE_DIRECTORY=app/catalogue/data` and `CATALOGUE_REQUIRE_RECEIPT=true`. Public OFF reads and catalogue builds require no key. No Gemini key is configured or required.

No live FSSAI requests, permanent writable cloud database or new subscription is required. Confirmed nutrition and claim POSTs have a 32 KiB actual body cap and work without OFF connectivity; exact-origin CORS permits GET/POST and Content-Type. The current catalogue build reads only the tracked public source: it performs no acquisition, env decryption or world download. New hosted settings activate only after deployment. Never run bulk import inside a scan request. [Nine-calendar-month source/deployment replacement](../architecture/CATALOGUE.md).

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

The final network-free two-bundle build, noninteractive backend setup, **543-test suite**, **59-file static check** and **150-test independent review** passed with no remaining findings; all Markdown/scripts and syntax/artifact boundaries were reviewed. Source push/exact-SHA hosted/source-only publication gates remain separate in the [v0.3.0 review](BACKEND_V0_3_0_REVIEW.md). Production verification must match both emitted build receipts to public catalogue/knowledge metadata, check supported/insufficient claims and three evidence records, unknown source 404, knowledge readiness, current eleven-route OpenAPI, POST numeric/body/error/CORS boundaries and preserved old APIs. Confirm generated knowledge JSON/receipt paths return 404 when requested as public URLs. Local success alone does not establish these hosted results.
