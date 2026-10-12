# Optional AI research — no custom training

Backend **v0.12.0** implements optional authenticated Gemini/OpenAI photo
extraction through [app/ai](../backend/app/ai/), with one globally active
server credential, explicit transfer consent, bounded unverified output and
separate private staging outcomes. Frontend local barcode/OCR remains the first
path and cloud failure falls back locally. [Current AI routing/privacy](../docs/architecture/AI_ROUTING.md).

This root directory holds research documentation, not the runtime provider code.
The unused dataset/experiment/evaluation/export/Spaces scaffold was removed.
No custom model, training dataset, Hugging Face deployment or paid compute was
created. Synthetic evaluation and source fixtures live in backend/frontend tests
and [contract examples](../contracts/examples/), with dated provider evidence
under `docs/research/`.

Pretrained OCR, reviewed deterministic claims and the sourced glossary handle
the baseline. Extraction cannot decide allergy safety, replace confirmation,
override numerical criteria or create unsupported evidence. Any future custom
training would require reviewed licensed inputs, independent evaluation and the
existing no-card/privacy boundaries. [Training research](../docs/research/AI_TRAINING.md).
