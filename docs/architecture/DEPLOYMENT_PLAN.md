# Website and shared API deployment plan

Checked: **2026-10-05**. The user imported two Git-connected Vercel projects and authorized their configuration. Backend v0.1.0 and a pinned Flutter web build now have tracked deployment configuration; live verification follows the first push containing it. Future OCR, rule analysis and evidence packaging remain plans.

Website: **[unlabel-india.vercel.app](https://unlabel-india.vercel.app)** (`unlabel-frontend`, root `frontend`). API: **[unlabel-api.vercel.app](https://unlabel-api.vercel.app)** (`unlabel-backend`, root `backend`). [Actual settings and validation state](../planning/VERCEL_SETUP.md).

## Project boundaries

| Target | Repository root | Runtime / scope | Calls |
| --- | --- | --- | --- |
| Website Vercel project | `frontend/` | Compiled Flutter web static assets from `build/web/` | Shared FastAPI URL over HTTPS. |
| Backend Vercel project | `backend/` | FastAPI on Python 3.12 | OFF product lookup now; reviewed rules and optional Gemini later. |
| Android/iOS apps | `frontend/` | Flutter native builds | The same FastAPI URL over HTTPS. |

Vercel documents separate roots for monorepo projects: [monorepos](https://vercel.com/docs/monorepos).
`frontend/web/` is Flutter's generated web platform folder, not a separate React/Vite application or Vercel project root.
FastAPI is directly supported and becomes one Vercel Function; `app/main.py` is the implemented entrypoint.
There is no need to split every route into a separate function or create an extra Node API.
[FastAPI support](https://vercel.com/docs/frameworks/backend/fastapi).

The native apps are built through Flutter's platform tooling; Vercel hosts their API, not their installable packages.
Use platform-specific OCR adapters in the same frontend: native ML Kit, future browser OCR with capture/upload first.
Tesseract.js through browser interop is a candidate, not an installed dependency or implemented feature.
Send confirmed label text and region IDs to the backend. Photos and bounding-box coordinates remain local. Every target uses the same `contracts/`.
The product is online-first. Python owns reviewed rule evaluation; Flutter receives stable reports and source-tagged OFF product snapshots. Limited offline scope is saved dated results, local preferences and an optional glossary. No second Dart rule engine or cross-evaluator parity system is required for the MVP.

## Flutter website build and hosting

Flutter documents `flutter build web` as a release build that generates `build/web/` under the project root.
[Flutter web deployment](https://docs.flutter.dev/deployment/web).
Vercel's static build settings serve this output. `frontend/tool/vercel-build.sh` supplies and checks Flutter 3.47.4, resolves the tracked lockfile and builds release web assets with public backend URL/version/commit metadata.
The chosen path and alternative are:

- **Configured:** custom Vercel build using Other, a supplied pinned SDK and `build/web` output.
- **Alternative:** prebuilt static deployment from an authorized GitHub/local job with the pinned SDK and Vercel Build Output API assets.

For the prebuilt path, `build/web/` alone is not a Vercel prebuilt artifact: include `.vercel/output/config.json` and place assets under `.vercel/output/static/`.
Keep generated SDKs and build outputs out of Git. Validate root hosting/base URL, browser refresh and asset paths before publishing.
Keep hash routing initially or configure/test a navigation fallback for path routing; avoid treating missing assets as successful page loads.
[Build settings](https://vercel.com/docs/builds/configure-a-build), [static output layout](https://vercel.com/docs/build-output-api/primitives).
Both projects deploy automatically from Git pushes to `main`. The manual native artifact workflow does not deploy either Vercel project.

## ₹0 and no-card boundary

Select Hobby only for an eligible personal/non-commercial college demo; do not select Pro trials or upgrades.
Hobby has finite resource allowances, limited collaboration features and may pause service when limits are exceeded.
Use default Vercel domains; domain purchases, paid seats, add-ons and AI Gateway credits are not prerequisites.
The user's existing account shows Hobby and both imports are connected. No signup/payment flow or billing upgrade was performed.
If the actual account requires paid/card-backed access, retain the local demo instead of changing the cost constraint.
[Hobby plan](https://vercel.com/docs/plans/hobby), [function pricing](https://vercel.com/docs/functions/usage-and-pricing).

The plan assumes one deployment owner with teammates collaborating in Git. Check repository import permissions separately.
Current Hobby terms permit model training and describe account-setting opt-out; verify opt-out before personal inputs are processed.
Keep request bodies, profiles, history, tokens and secrets out of application logs.
[Vercel terms](https://vercel.com/legal/terms).

## Bundle shared evidence during the build

Canonical `knowledge/` and `contracts/` sit outside the backend project's root. Build access is not runtime availability.
“Include source files outside of the Root Directory in the Build Step” is enabled. Future evidence packaging still needs its own implementation and artifact verification.
[Outside-root build access](https://vercel.com/docs/monorepos/monorepo-faq).

The future backend build must validate canonical files and copy only required JSON into a generated, ignored backend bundle.
Include source IDs, rule/knowledge versions and a manifest of source hashes. Do not maintain those copies manually.
Verify the final Python function artifact contains that evidence and reads it from a known packaged path.
Python bundling currently includes reachable project files by default; explicitly exclude development files and large source PDFs.
An outside-root setting alone does not prove that the deployed API contains the evidence.
[Python bundling and file paths](https://vercel.com/docs/functions/runtimes/python).

Changes to `knowledge/`, `contracts/` or the evidence packaging script must rebuild the backend even when `backend/` is unchanged.
Changes to shared client contracts must trigger relevant Flutter web/native checks. Validate one contract version before promotion.

## Stateless runtime and storage

Treat every hosted request as able to land in a fresh instance. Read evidence; do not update packaged files at runtime.
Vercel Functions provide a read-only filesystem with temporary scratch space:
[function runtimes](https://vercel.com/docs/functions/runtimes).
Do not store scan history, mutable SQLite databases, user accounts, quota counters or permanent caches in that filesystem.
The current backend uses live OFF reads. Future evidence is read-only JSON; an immutable SQLite catalogue may be bundled only after size/read-access checks. A laptop may also use a derived SQLite index.
Profiles, history and pending scans remain in browser/device storage and do not sync between clients in the initial scope.

## Limited offline access and optional model hosting

The MVP is online-first. Open Food Facts supplies primary product data; Python applies reviewed criteria. Offline scope is saved dated reports/product snapshots, local preferences and an optional small glossary. Bundled OCR may capture drafts on supported devices, but fresh analysis waits for the backend. No duplicate Dart rule engine is required.

For the website, offline use needs an initial successful load and a deliberate caching service worker.
Cache the app shell and chosen saved-content/glossary assets. Browser draft OCR would additionally need worker/Wasm/language assets; it is not required for the initial offline scope.
Test airplane-mode restart, saved-content dates and cache upgrades; do not label saved results as fresh analysis.
Flutter does not provide a managed caching service worker by default: [web FAQ](https://docs.flutter.dev/platform-integration/web/faq).

Hugging Face may later supply an optional trained-model inference provider through this same backend, not a replacement frontend.
Its new CPU/Docker compute Space creation requires a paid plan; free ZeroGPU Gradio hosting has account-age and quota conditions.
Do not provision it, train a model or depend on it now. See [AI_TRAINING.md](../research/AI_TRAINING.md) for verified options.

Bound input text, requests, provider timeouts and returned output below actual platform limits.
Use request/response analysis rather than a background process that must survive an invocation.
Keep OCR and local model inference off the hosted backend; install neither OCR models nor Ollama in the function bundle.
[Function limits](https://vercel.com/docs/functions/limitations).

## API URL and CORS configuration

Flutter web and native builds will receive a public `BACKEND_BASE_URL` through Dart build configuration, such as `--dart-define`.
These are addresses, not secrets. Preview and production clients need explicit matching API URLs and contract versions.
The backend allowlist must include exact website origins and deliberate local development origins; avoid wildcard preview trust.
Handle browser preflight requests and permit only required methods and headers. Native clients do not rely on browser CORS.
If login is added, select token/cookie behavior deliberately; never combine credentialed requests with wildcard origins.
CORS controls browser access and is not API authentication or a quota protection mechanism.
[CORS guidance](https://vercel.com/kb/guide/how-to-enable-cors).

Backend secrets include the optional Gemini key; never put it in Dart build settings, frontend environment files or public assets.
Keep the provider disabled and `GEMINI_MODEL` blank until the real Free Tier project's availability is verified.

## Optional AI access and abuse control

Keep a publicly reachable deployment's Gemini route disabled by default; deterministic templates remain usable.
For a later invited adult beta, require verified individual identity tokens and a backend invite allowlist before cloud-AI access.
Select and verify a no-card identity mechanism in that implementation phase; there is no authentication service dependency now.
Do not distribute a shared API secret, Vercel automation bypass token or Gemini key inside website/native builds.
Token signature, issuer, audience, expiry and invite membership must be checked server-side.

Vercel Authentication can protect previews, but it uses browser login/cookies scoped to a deployment URL.
Hobby access-request invitations are limited; this is not transparent authentication for both native apps and a separate web project.
Do not rely on that protection alone for a cross-platform API or assume paid password protection is free.
[Deployment authentication](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication).

Anonymous AI would need separately verified anti-abuse controls; a browser challenge alone does not authorize native requests.
An in-memory limiter/cache is disposable and cannot enforce a durable global daily user budget across serverless instances.
Gemini's actual project quota remains a provider limit; authorized users can still exhaust it. Bound calls and use template fallback.
If adequate protection cannot fit ₹0/no-card, keep hosted Gemini disabled and demonstrate it through the private local backend.
See [FREE_STACK.md](../research/FREE_STACK.md) for public-only provider inputs and deterministic failure behavior.

## Validation and later feature gates

Confirm account/plan eligibility, evidence artifact contents, HTTPS URLs, CORS/preflight and API contract compatibility.
Exercise browser and native calls against the same backend; test missing/invalid identity before enabling hosted AI.
Test provider failure, quota exhaustion, serverless restart and backend outage without relying on stored server state.
Verify saved-content access offline and separately verify the website's cached app/content after an initial load. New backend analysis must clearly defer when connectivity is absent.
Measure cold-start response time and bundle size; keep the laptop/LAN demonstration ready if hosted limits pause service.
Project imports/configuration and the website build script are now part of v0.1.0 hosting setup. See [Vercel setup](../planning/VERCEL_SETUP.md) and [backend review](../planning/BACKEND_V0_1_0_REVIEW.md) for current evidence. The additional gates above apply when their planned features are implemented.
