# Optional AI experiments — no training started

| Folder | Future use |
| --- | --- |
| datasets | Licensed, labelled synthetic/reusable extraction data; no user scans |
| experiments | Optional small model experiments and recorded configurations |
| evaluation | Held-out evaluation, error cases and evidence-integrity checks |
| export | Model export metadata; large weights remain outside Git |
| spaces | Optional Hugging Face demo configuration, only after eligibility review |

The first scanner does not need custom training: pretrained OCR + reviewed rules + a glossary handle the baseline. Any optional model assists extraction/wording and cannot replace deterministic nutrition rules or allergy uncertainty.

Read [AI training research](../docs/research/AI_TRAINING.md). Hosting a model is different from training one. No model, dataset, Hugging Face account, inference endpoint or paid compute has been created.
