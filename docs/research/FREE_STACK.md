# Zero-cost stack and AI plan

Research checked: **2026-10-05**. Status: backend/hosting architecture proposal; the Flutter scaffold and manual artifact workflow have separate implementation scope.

Unlabel's college demo must require **₹0 service charges, no credit card and no paid billing setup**.
The planned hosted path uses two Vercel Hobby projects: the website and one shared FastAPI backend.
One Flutter project directly under `frontend/` targets Android, iOS and the website; all clients call the same backend.
The product is online-first: Open Food Facts supplies product data and its own computed insights; the backend performs Unlabel's reviewed FSSAI-related checks.
Vercel hosts the compiled Flutter web assets, not the installable native packages.
The local fallback assumes the team already has an Android phone, a laptop and a local network.
Ordinary device, electricity and Internet costs are not newly purchased project infrastructure.
Free-tier offerings can change; optional cloud AI must never be required for core analysis.

## Proposed demo stack

| Layer | Planned choice | Why it fits the constraint |
| --- | --- | --- |
| Frontend | Flutter directly under `frontend/`, Android/iOS/web targets | One Dart codebase; platform folders are generated inside this project. |
| Website hosting | Flutter static output from `frontend/build/web/` | A separate Vercel Hobby project hosts compiled web assets after a custom/pinned Flutter build. |
| Mobile camera/OCR | Bundled on-device ML Kit text recognition | Process label images on the phone; bundled models avoid a first-use model download. |
| Browser OCR | Future browser adapter; Tesseract.js worker is a candidate | Capture/upload first; do not assume native ML Kit works on Flutter web. No OCR package is added by this plan. |
| Shared backend | FastAPI under `backend/`, Vercel Hobby planned | One hosted API serves the website and both native apps; the same code can run on the laptop/LAN. |
| Product data | Open Food Facts read-only barcode API, selected | Public reads need no product API key; use application identity, attribution, bounded requests and missing/unavailable fallback. See [integration plan](../architecture/OPEN_FOOD_FACTS.md). |
| Knowledge | Versioned, reviewed files under `knowledge/` | Store ingredient aliases, bilingual explanations, rule definitions and source metadata in Git. |
| Hosted knowledge lookup | Bundled read-only JSON derived from `knowledge/` | No database service or mutable filesystem is needed for the hosted baseline. |
| Optional local lookup/cache | Derived SQLite on the laptop | A local optimization only; do not use a Vercel function's filesystem as a durable database. |
| Core analysis | Python backend evaluator using reviewed canonical rules | Apply evidence-linked checks to confirmed package fields and source-tagged OFF data; no duplicate Dart rule engine required. |
| Limited offline access | Saved dated reports, local preferences, optional small preinstalled glossary | Preserve useful local content; new analysis requires a reachable backend. |
| Explanation baseline | Backend-rendered reviewed English/Hindi templates | Preserve usable online/backend analysis when Gemini is disabled or fails. |
| Optional explanation | Gemini Developer API Free Tier | Enable only after actual account, model, quota and privacy checks. |

Flutter supports building and installing Android APKs locally: [Android deployment](https://docs.flutter.dev/deployment/android).
Choose a bundled Latin OCR model; add bundled Devanagari recognition only when Hindi-label tests justify it.
ML Kit documents bundled versus downloaded models, text geometry and image-quality limitations:
[Android text recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
Verify the eventual Flutter bridge actually bundles the intended native models before claiming offline OCR.

FastAPI deployment is a server process the team can run locally: [deployment concepts](https://fastapi.tiangolo.com/deployment/).
SQLite operates without a separate database server: [SQLite architecture](https://www.sqlite.org/serverless.html).
Any local database is a rebuildable artifact, not a second source of truth. Do not commit generated databases or scan caches.
No backend database, model download or server process is created by this architecture plan.

Vercel Hobby is free for personal/non-commercial use, with finite allowances and no paid overage assumption.
Before deploying, verify actual no-card account/import eligibility; do not upgrade if a card or paid feature is required.
Hobby collaboration features are limited; use repository collaboration rather than assuming paid dashboard seats.
[Hobby terms and limits](https://vercel.com/docs/plans/hobby).
See [DEPLOYMENT_PLAN.md](../architecture/DEPLOYMENT_PLAN.md) for both roots, evidence packaging, CORS and protected AI.

## What “offline” means here

Offline access is limited; it is not a separate analysis engine and is not implemented by the starter scaffold.
`knowledge/` remains the single source for declarative rules, aliases, glossary and English/Hindi templates.
Python owns the reviewed analysis rules and template rendering. Do not duplicate them in Dart or require cross-language evaluator parity.
Flutter may cache dated reports, keep preferences locally, and optionally bundle a small reviewed ingredient glossary.
Open Food Facts computed tags/scores retain provider provenance; they are not Unlabel or FSSAI verdicts.

| Availability | Planned behavior |
| --- | --- |
| Backend reachable; Gemini disabled or unavailable | Run reviewed backend checks and return source-linked English/Hindi templates. Missing OFF data stays unknown rather than blocking sufficiently evidenced package checks. |
| Backend unreachable | Open saved dated reports/local preferences and an optional preinstalled glossary; retain any local draft. New analysis waits for a reachable backend. |
| Backend reachable; Gemini permitted and available | Add validated language explanations to the deterministic findings. |
| Laptop/LAN backend reachable; external Internet unavailable | Analyze sufficient confirmed fields using packaged rules/templates. Uncached OFF lookup and cloud AI are unavailable; unsupported or incomplete findings remain unknown. |

Backend-unavailable mode must not generate fresh verdicts or treat a dated report as a new analysis.
Live highlights may locate local OCR text and show matching returned findings; local boxes alone do not prove nutrient levels or claim outcomes.
The backend-available/no-Gemini path is the required college demonstration fallback.
Hosted analysis needs Internet access. Test loss of Internet separately from loss of LAN/backend connectivity.
Any offline native OCR capture requires bundled models, but does not create a new offline analysis.
Website offline saved-content access requires an initial successful load plus explicit service-worker caching
of app shell/rendering assets and local report storage; a preinstalled glossary needs its own caching. Ordinary browser caching is insufficient.
Flutter does not generate/manage a caching service worker by default: [web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
See [AI_TRAINING.md](AI_TRAINING.md) for the optional training/hosting plan and Hugging Face eligibility.

## Gemini eligibility and current options

Google states that new accounts begin on the Free Tier; linking billing is the upgrade path.
For this project, use only an eligible **Free Tier project with no linked billing account**.
Do not activate paid billing, prepay, paid trial credits or another team's already billed project.
[Official billing guidance](https://ai.google.dev/gemini-api/docs/billing).

India is listed as a supported region: [available regions](https://ai.google.dev/gemini-api/docs/available-regions).
Account eligibility must still be checked by the teammate who later creates the key.
No accounts or keys are created now.

On this research date, Google's model catalog lists `gemini-3.5-flash-lite` and `gemini-3.8-flash` as stable
and recommends these for new projects. The standard pricing table currently lists free input/output for both.
These names are **research snapshots, not configured defaults or availability guarantees**.
The same catalog restricts 2.5 model access to prior active users, so an old tutorial is not a reliable new-project plan.
[Model catalog](https://ai.google.dev/gemini-api/docs/models), [pricing](https://ai.google.dev/gemini-api/docs/pricing).

Leave `GEMINI_MODEL` and `GEMINI_API_KEY` blank in the foundation environment example.
When implementation starts, verify a stable model's actual Free Tier availability and quotas in that project.
Keep cloud AI disabled by default. Never silently switch to a paid model or enable billing after an error.

## API key, privacy and provider boundary

The key belongs only in the backend's ignored environment configuration.
Google recommends a backend proxy and warns against keys embedded in mobile applications:
[API key security](https://ai.google.dev/gemini-api/docs/api-key).

The Free Tier's submitted content and generated responses may be used to improve Google products;
human reviewers may inspect them. Google says not to send personal, sensitive or confidential information.
Its API terms also impose adult-use and API-client age restrictions; plan an eligible adult college demonstration.
[Gemini terms](https://ai.google.dev/gemini-api/terms).

The Gemini provider input must contain only:

- Public, user-corrected text printed on the food package.
- Public evidence snippets with source IDs and versions.
- Generic deterministic findings about that product, without personal suitability information.
- Requested output language and the expected response schema.

Exclude profiles, allergy selections, personal suitability findings, account identifiers, location and scan history.
Exclude original images, OCR camera frames, faces and image metadata entirely.
Profiles remain on the phone or in browser storage. Neither the backend nor Gemini receives a user's dietary or allergy profile; the client applies preferences to neutral analysis results locally.
An ingredient-allergen fact about a public product is different from revealing a user's allergy.
Treat label text as untrusted data, constrain prompt size and keep provider logs free of request bodies and secrets.

## SDK and response validation

Future Python integration should use the official `google-genai` SDK behind a replaceable provider interface.
Context7 research used `/googleapis/python-genai` for environment-key configuration and structured output.
[Official Python SDK](https://github.com/googleapis/python-genai).

Request a small schema for explanations and allowed evidence IDs.
Validate both the JSON shape and its meaning: citations must exist, values must match known findings,
and ingredient names must refer to confirmed extracted text or reviewed aliases.
Structured output does not make generated values factually correct:
[structured output validation](https://ai.google.dev/gemini-api/docs/structured-output).

Gemini may simplify or translate supplied evidence. It must not invent nutrition values, choose legal thresholds,
override deterministic claim checks, label unknown allergens “safe,” or invent authority citations.
If output fails validation, keep the deterministic report and render the reviewed template.

## Quota, caching and failure plan

Google's limits vary by model and account, apply per project rather than per key, and are not guaranteed.
Creating more keys does not create more project quota. Read the actual limits when enabling the provider.
[Rate-limit guidance](https://ai.google.dev/gemini-api/docs/rate-limits).

- Call the provider only after the user confirms corrected label text; never send every camera frame.
- Cache generic explanations by normalized label hash, language, knowledge/rule version, prompt version and model ID.
- On Vercel, instance memory and temporary files are disposable; cache hits are an optimization, not a promised shared cache.
- Keep cached product explanations separate from private scan history and user suitability results.
- Bound request size, concurrency and retry count; respect retry guidance with backoff.
- Do not repeatedly retry a depleted daily quota. Return templates and a clear AI-unavailable state.
- Handle missing keys, rejected models, timeouts, quota errors and malformed output with the same usable baseline.
- Public cloud-AI routes stay disabled until individual access control is verified. CORS or an app-embedded secret does not protect quota.

## Alternatives and exclusions

| Option | Role | Constraint or limitation |
| --- | --- | --- |
| Backend deterministic rules + reviewed bilingual templates | Required | Team must curate evidence; unknown data remains unknown. No model training or AI provider account. |
| Gemini Free Tier | Optional | Eligible adult account, public-only inputs and variable quota; disable if no-card access is unavailable. |
| Hugging Face ZeroGPU Space | Optional later experiment | Eligible verified personal account older than 30 days; Gradio only, queue/quota limits. Ordinary new CPU/Docker compute Spaces require a paid plan. |
| Local Ollama model on an existing laptop | Optional future experiment | No hosted API credit dependency; requires suitable existing RAM/storage, model download and license review. |
| Other hosted “free AI” offers | Not a foundation dependency | Accept only after current no-card, no-billing, privacy and quota verification; do not promise perpetual free hosting. |
| Paid/trial cloud services or paid embeddings | Excluded | Billing accounts, card-backed trials and upgrade requirements violate this project's constraint. |

Ollama supports local-only operation and cloud disabling with `OLLAMA_NO_CLOUD=1`:
[local-only configuration](https://docs.ollama.com/faq).
Its local API requires no API key: [authentication](https://docs.ollama.com/api/authentication).
Context7 research used `/ollama/ollama`; no local runtime or model is installed now.
Local generation must use the same validation and deterministic fallback as Gemini.

The hosted plan excludes paid Vercel features, AI Gateway credits, managed vector databases and card-backed trials.
Do not add durable/shared cloud caches or databases as hidden prerequisites. Store profiles and history on each client.
Install Android test builds directly. Store publication fees and iOS device/distribution requirements are separate from free API hosting.
Flutter web compilation and native artifact packaging are separate from deployment; the manual build workflow does not deploy Vercel.
Current Vercel terms allow Hobby model-training opt-out in account settings; verify that setting before hosting personal inputs.
[Vercel data-use terms](https://vercel.com/legal/terms).
Start backend retrieval with exact ingredient aliases and reviewed source lookup from packaged knowledge files.
No vector RAG system or custom model training is necessary for the baseline. Train a bounded extraction model only after labeled-data evaluation.
