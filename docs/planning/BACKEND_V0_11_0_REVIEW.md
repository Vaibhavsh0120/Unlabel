# Backend v0.11.0: automatic photo extraction

Implementation source `578a9afebae8f77fe98344233cdc9155e82bb37a` is pushed, with
READY deployment `dpl_GYRcK2j22N2gY24Hsxk5pi8UH8rA`. Read-only public/API
verification passed 389 checks, preserving all 243 source observations and 24,641
bulk catalogue products. Authenticated AI generation/failover remains unexercised.
[Production receipt](../research/BACKEND_V0_11_0_PRODUCTION.json).
Later v0.12.0 work is local and
uncommitted under the user's no-push instruction.

Optional authenticated photo reading now supports Gemini and OpenAI through one
globally selected credential. A barcode catalogue hit remains independent of AI.
This checkpoint adds the backend contract; frontend v0.6 automatic scanning is a
separate implementation and deployment.

The same Firestore selection applies to every AI operation and scanner. Manual
changes use a revision guard. Credential, quota and transient failures may switch
the shared selection once to an eligible configured replacement; successful calls
never rotate it. Late failures cannot undo a newer selection. Local capacity and
invalid model output do not change providers. Keys remain server-only.

`POST /v1/ai/extract` accepts at most three distinct front/back/barcode photos,
explicit transfer consent and a verified scanner token. Photos are bounded to
900,000 decoded bytes each, valid PNG/JPEG containers and 24 megapixels; actual
JSON bodies are bounded to 4 MiB. Fixed provider origins, no redirects/proxies,
bounded output, strict numerical/table/GTIN validation and a 48-second extraction
deadline apply. Facts retain `machine_extracted_unverified`; missing stays null.
Photos, raw OCR and model output are not persisted by this endpoint.

Machine-only status/activation routes require `AI_CONTROL_SECRET`. They introduce
no app admin role. Default shared admission limits are 100 requests/day globally
and 10 per actor bucket. Fixed counter documents avoid unbounded histories and
paid TTL. The configured Gemini/OpenAI accounts remain under operator control;
no Firebase billing, Storage or Functions are enabled.

## Validation

Full backend suite: **1,303 passed, five explicit provider/emulator skips**.
Tests cover malformed/oversized images, duplicate slots/JSON keys, image metadata,
schema ambiguity, privacy-safe errors, authentication, cooldowns, sticky selection,
configuration changes, contention, late failures and shared limits. Existing
catalogue, community, account, claim, nutrition and comparison behavior passes.
Auth construction no longer touches a Firestore document reference before use.
Current exported OpenAPI has 27 paths and 28 operations, preserving old paths.

Both locally supplied keys passed model-access checks. One owned synthetic Gemini
label passed 11 extraction checks in 3.88 seconds; see the
[synthetic receipt](../research/AI_VISION_SYNTHETIC_CHECK.json). This does not
establish real-package accuracy, OpenAI generation quota, native-device behavior
or authenticated hosted extraction. Public production verification is recorded
separately in the dated receipt; it made no AI generation or account/data writes.

## Storage decision

The user authorized choosing the best database on 8 October 2026. Retain the
verified read-only SQLite catalogue for predictable lookup/search without per-scan
cloud document reads. Firestore remains the shared mutable store for community
observations, private accounts and AI selection. The original 24,641 catalogue
products and 243 researched observations remain intact. No migration or deletion
of existing SQLite data is authorized by this implementation decision.

See [AI architecture](../architecture/AI_ROUTING.md) and
[automatic scan plan](AUTOMATIC_SCAN_PLAN.md).
