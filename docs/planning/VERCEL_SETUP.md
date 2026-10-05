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
- No custom install/build/output command; Vercel installs the declared Python runtime dependencies and packages the application as one Function.
- `backend/vercel.json` limits this Function to 15 seconds; OFF lookup has its own 8-second deadline and 512 KiB decoded response budget.
- `backend/.vercelignore` excludes local environment files, development environments/tests/caches and private runtime storage.
- CORS allowlist: `https://unlabel-india.vercel.app` and the existing `https://unlabel-frontend.vercel.app`. Native clients can call the same public API. CORS is not authentication.
- Backend environment holds `OFF_USER_AGENT`, `OFF_TIMEOUT_SECONDS=8`, `OFF_MAX_RESPONSE_BYTES=524288`, `CORS_ORIGINS` and `AI_PROVIDER=disabled`. Public OFF reads require no key. No Gemini key is configured or required.

No live FSSAI requests, Indian snapshot import, permanent cloud database or new subscription is required for v0.1.0. The [six-month snapshot proposal](../research/INDIA_SNAPSHOT.md) is a separate data milestone. A future immutable catalogue is built and checked before deploying; never run a bulk import inside a scan request.

## Push and verification

Update docs and run relevant checks before each push. Both projects use their own root-level config files; no repository-root `vercel.json` competes with them. Unaffected-project skipping is disabled to match the requested every-push deployment behavior. Free build/hosting allowances remain finite.

After pushing, match each deployment's Git SHA to the intended commit. Check the website, `/v1/health`, `/v1/meta`, `/openapi.json`, one bounded product lookup, exact-origin CORS/preflight and invalid input. A READY build alone is not endpoint evidence.

Initial imports deployed the foundation commit without the new service/build script. The first corrected push, `0c10e0b807948d70d3327517387f1db8cddc52c7`, automatically produced READY production deployments for both projects:

- Website: `dpl_in9NzBZaSEsZdSfT8XVFoQmWcfK2`; pinned SDK/lockfile and release web compilation succeeded. The public page and JavaScript returned 200, and Chrome rendered the Flutter starter. Unpublished source/environment and missing JavaScript paths returned 404.
- Backend: `dpl_6uCtKb2CbnMtFWu6U35jLarubt3R`; public health/meta/OpenAPI returned 200, live schema matched the export, invalid barcode returned 422, and a live OFF lookup returned 200/found. Exact frontend CORS and preflight passed; an unrelated origin was not allowed.

These HTTP checks used no Vercel login cookie or bypass token. This verifies initial production deployment and provider connectivity, not future scanner/analysis behavior or Indian-market coverage. Later docs-only pushes redeploy the same service/frontend source. See [backend validation](BACKEND_V0_1_0_REVIEW.md) for remaining gates.

References: [Vercel monorepos](https://vercel.com/docs/monorepos), [FastAPI deployment](https://vercel.com/docs/frameworks/backend/fastapi), [Python runtime/version](https://vercel.com/docs/functions/runtimes/python), [Flutter web release](https://docs.flutter.dev/deployment/web), [Vercel Authentication](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication).
