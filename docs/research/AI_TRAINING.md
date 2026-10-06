# AI training, Hugging Face and limited offline access

AI/provider research checked: **2026-10-05**. This remains a future AI plan; no model is trained, AI account created or inference service deployed.
Current implementation includes the Flutter **0.0.0+1** starter, manual native artifact workflow, deployed website/API projects and **backend v0.2.1** product/nutrition lookup, confirmed-value normalization and optional read-only identity catalogue tooling. Camera/OCR, reviewed health/claim analysis, explanation templates and cloud AI remain future features. Complete India acquisition/coverage and catalogue hosting are separate measured gates; no trained model follows from a product-data import.

## What needs training?

**No custom training is required for the baseline.** OCR already uses an existing recognition model.
Reviewed ingredient aliases, source lookup, nutrient calculations, claim checks and glossary explanations use deterministic data/rules.
The online backend owns Unlabel's reviewed checks; selected Open Food Facts product data/computed insights retain their own provenance.
Optional Gemini explanations use an existing model. Connecting an API key is not training a model.
The college demonstration can therefore work without GPUs, paid model hosting or a vector RAG database.

| Component | Baseline approach | Optional later research |
| --- | --- | --- |
| OCR | Existing on-device/browser OCR model and user correction. | Improve capture/OCR evaluation before considering retraining. |
| Ingredient matching | Reviewed aliases and known additive identifiers. | Small alias candidate model for noisy OCR or unfamiliar phrasing. |
| Front-package claims | Extract text and check reviewed rules against confirmed label values. | Bounded claim-type/span extraction model. |
| Explanations | Backend-reviewed English/Hindi templates; optional Gemini rewriting, plus an optional small preinstalled glossary. | Evaluate a small local model against the same evidence contract. |
| Allergy/legal/nutrition findings | Backend-reviewed rules with missing-data states; separate source-tagged OFF insights. | Do not replace evidence with a learned “safe” or legal-compliance classifier. |

Training learns model parameters; hosting runs a saved model; a model repository stores its files.
Uploading weights to the Hugging Face Hub does not automatically create a website API or make inference offline.

## If we later train a small model

Start with one measurable task such as ingredient alias candidate generation or claim-span extraction.
Use licensed public label text and manually verified annotations; retain license, source and annotation records.
Do not upload personal profiles/history or private photos. Synthetic examples may supplement, not replace, real held-out evaluation.
Split by product/package family so near-duplicate labels do not appear in both training and test sets.
Compare against the existing alias/rule baseline on noisy OCR, English/Hindi text, unknown ingredients and incomplete labels.
Measure extraction precision/recall, unknown rejection, latency and model size; record errors instead of promising improvement.
Try a small CPU-friendly model on existing hardware first. Choose a training library/model only after checking data and hardware.
Save reproducible settings, model/data license information, evaluation results and version hashes alongside a model card.
Keep large weights and raw datasets out of ordinary Git; no training files or dependencies are added now.

## Hugging Face: current zero-cost limits

The official overview now says new Gradio/Docker compute Spaces require a paid personal PRO or organization plan.
CPU Basic's hardware table says no hourly cost, but that does not remove the plan requirement.
Static Spaces are free, yet do not run a Python training/inference backend.
[Spaces overview](https://huggingface.co/docs/hub/spaces-overview), [pricing](https://huggingface.co/pricing).

There is an explicit free-hosting exception: a personal account in good standing with verified email and age over 30 days
can host up to two ZeroGPU Spaces. ZeroGPU supports Gradio, uses queued shared compute and has daily usage quotas.
Verify the actual account and current rules before relying on this; no account has been tested for this project.
Do not buy PRO, paid GPU time, prepaid quota or dedicated endpoints to bypass the ₹0/no-card constraint.
[ZeroGPU eligibility and limits](https://huggingface.co/docs/hub/spaces-zerogpu).

An eligible ZeroGPU demo is an optional experiment, not the guaranteed always-available backend.
If a later model merits hosting, the existing FastAPI backend can call that optional provider and validate its output.
Keep Hugging Face access tokens backend-only and preserve the public-only provider boundary.
Do not make either Flutter web or native apps embed credentials or depend directly on the Space's private implementation.
Space queues, unavailable inference and exhausted quota must fall back to backend rules/templates or explicit missing information.
Context7 research resolved and queried `/huggingface/hub-docs`; sources above were checked live.

## Limited offline capability plan

Unlabel is online-first. New analysis requires the backend, which combines confirmed package fields,
selected Open Food Facts product data, reviewed FSSAI-related checks and template explanations.
Gemini failure must preserve that backend template baseline; it does not require an offline Dart evaluator.
OFF computed insights remain provider insights, not automatic Unlabel or regulator verdicts.

Without a reachable backend, the planned client can show saved reports with their original dates/versions,
retain local preferences/drafts, and optionally explain ingredients from a small preinstalled glossary.
No fresh claim/nutrition/allergen verdict is generated offline. Never infer allergy safety from missing data.
Do not duplicate canonical thresholds into Dart or require cross-language evaluator parity.
Native OCR capture can be local if its models are bundled, but capture alone is not a completed analysis.

An existing laptop/LAN backend is the no-card demo fallback. If external Internet is unavailable,
it can analyze sufficient confirmed fields using packaged evidence and templates; uncached OFF lookup,
Hugging Face inference and Gemini remain unavailable. Missing evidence produces explicit unknowns.

Website access to saved content still needs a successful initial load, local report storage and explicit
app-shell/rendering/glossary caching. Flutter does not manage a caching service worker by default:
[Flutter web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
Any later small-model device inference requires a compatible export/runtime and separate evaluation;
it is not needed for the online-first baseline. Server weights or an HF endpoint do not run inside Flutter.

Implement the online reviewed backend/template baseline first, then measure whether training improves extraction enough to justify its added work.
