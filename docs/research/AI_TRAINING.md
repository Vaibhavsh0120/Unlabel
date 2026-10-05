# AI training, Hugging Face and offline plan

Checked: **2026-10-05**. This is a future plan; no model is trained, account created or inference service deployed.
The current authorized implementation is the Flutter starter and manual native artifact workflow, not the scanner/analysis engines.

## What needs training?

**No custom training is required for the baseline.** OCR already uses an existing recognition model.
Reviewed ingredient aliases, source lookup, nutrient calculations, claim checks and glossary explanations use deterministic data/rules.
Optional Gemini explanations use an existing model. Connecting an API key is not training a model.
The college demonstration can therefore work without GPUs, paid model hosting or a vector RAG database.

| Component | Baseline approach | Optional later research |
| --- | --- | --- |
| OCR | Existing on-device/browser OCR model and user correction. | Improve capture/OCR evaluation before considering retraining. |
| Ingredient matching | Reviewed aliases and known additive identifiers. | Small alias candidate model for noisy OCR or unfamiliar phrasing. |
| Front-package claims | Extract text and check reviewed rules against confirmed label values. | Bounded claim-type/span extraction model. |
| Explanations | Reviewed English/Hindi glossary/templates; optional Gemini rewriting. | Evaluate a small local model against the same evidence contract. |
| Allergy/legal/nutrition verdicts | Deterministic reviewed rules with missing-data states. | Do not replace evidence with a learned “safe” or legal-compliance classifier. |

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
Space queues, unavailable inference and exhausted quota must fall back to local rules/templates or explicit missing information.
Context7 research resolved and queried `/huggingface/hub-docs`; sources above were checked live.

## Offline capability plan

Offline means usable supported analysis without Vercel, Gemini or Hugging Face; it does not mean downloading Gemini itself.
Bundle a reviewed subset of canonical `knowledge/` rules, glossary, aliases and English/Hindi templates into Flutter.
Reserve `frontend/lib/core/analysis/` and a knowledge loader; keep threshold/source definitions in canonical files.
Dart evaluates the device subset; optional Python evaluates expanded rules using the same common definitions.
Parity fixtures must compare units, source IDs, rule versions, verdicts and missing-data states on common cases.
Return `insufficient_information` for unsupported/incomplete checks and never infer allergy safety from an incomplete list.
Native offline mode also needs bundled OCR models and local history; all of this remains future implementation.

The website needs a successful initial load plus an explicitly configured caching service worker.
Cache application/rendering/font assets, reviewed knowledge and browser OCR worker/Wasm/language assets before going offline.
Flutter does not manage a caching service worker by default: [Flutter web FAQ](https://docs.flutter.dev/platform-integration/web/faq).
Any later small-model offline inference needs a compatible export/runtime plus device/browser accuracy, size and performance tests.
Do not promise that server Python weights or a Hugging Face endpoint automatically run inside Flutter.

Implement the reviewed offline baseline first, then measure whether training improves extraction enough to justify its added work.
