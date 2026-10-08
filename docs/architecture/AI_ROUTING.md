# One active AI credential

Backend v0.11 adds optional Gemini and OpenAI photo extraction. All AI operations
must enter `AiGateway`; callers cannot supply keys, provider URLs, model names or
choose a provider per task. The app has only scanner users, with anonymous or
password Firebase authentication. No reviewer/admin app role is introduced.

## Selection and replacement

`unlabel_service_configuration/ai-active` in the existing free `unlabel` Firestore
database holds one slot ID, revision, configuration digest and bounded cooldowns.
It contains no credentials or photos. Every admitted AI operation reads this
shared choice. A server restart/default setting never resets an existing choice.
Requests already admitted before a switch may finish with their earlier key.

The initial slot is `gemini-primary` by default. Both provider keys may be stored,
but only the active slot is used. Success never rotates slots. Credential failure,
quota or upstream/network failure records a cooldown and atomically selects one
configured eligible replacement. The replacement stays active. A delayed failure
cannot overwrite a newer manual/automatic revision. If all slots are blocked,
requests wait; when an earlier slot recovers while the active one is still blocked,
admission may move the global pointer to that available slot. It does not return
to a recovered primary while the active replacement is healthy.

There are at most eight configured slots and two provider attempts per request.
Malformed model output, invalid schemas, refusals and local connection-pool load
do not change keys. HTTP quota deadlines are honored up to one day. Provider
adapters make no retries. A 48-second extraction deadline leaves host response
time; actual cold/authentication/network behavior remains a deployment gate.

Adding/removing/rotating a credential changes the configuration digest. An old
worker fails closed after deliberate activation of the new configuration rather
than silently selecting an old key. Deploy the same settings to all workers,
then activate with the current revision. This is a machine maintenance operation.

## Local configuration

Put `GEMINI_API_KEY` and optionally `OPENAI_API_KEY` in ignored `backend/.env`.
`AI_ENABLED=true` enables the capability when the Firebase runtime and initial
credential are available. `GEMINI_MODEL` defaults to `gemini-3.5-flash-lite`;
`OPENAI_MODEL` defaults to `gpt-4.1-mini`. OpenAI live availability is separate
from adapter tests and requires the operator's API access; no billing is enabled.
Extra keys use bounded `AI_FALLBACK_CREDENTIALS_JSON` entries with `id`, `provider`,
`api_key` and `model`. The same key cannot appear twice for one provider.

The hidden-prompt helper saves one key and refreshes encrypted settings:

~~~powershell
backend/.venv/Scripts/python.exe scripts/configure_ai.py openai
backend/.venv/Scripts/python.exe scripts/env.py encrypt
backend/.venv/Scripts/python.exe scripts/ai_provider.py --project unlabel-india-catalogue status
backend/.venv/Scripts/python.exe scripts/ai_provider.py --project unlabel-india-catalogue activate openai-primary --expected-revision 1
~~~

Use the actual returned revision. `AI_INITIAL_CREDENTIAL_ID` only initializes an
empty shared selection. Direct `.env` edits require another encryption refresh.
The [example settings](../../backend/.env.example) contain placeholders only.
Plaintext keys, private identities and machine-control credentials stay excluded
from Git; `backend/.env.age` is the authenticated recoverable ciphertext.

## HTTP contracts and limits

| Route | Access and behavior |
| --- | --- |
| `GET /v1/ai/active` | Machine bearer secret; nonsecret slot/provider/model/revision/status |
| `POST /v1/ai/control/activate` | Same machine secret; configured slot ID plus expected revision; stale requests return409 |
| `POST /v1/ai/extract` | Verified scanner token and explicit photo-transfer consent; qualified machine facts |

The app uses public `/v1/meta` capability flags, which do not read Firestore or call
AI. The machine secret is `AI_CONTROL_SECRET`, never embedded in a client. The
loopback preview allows scanner extraction but deliberately excludes control.

Extraction accepts one to three distinct front/back/barcode PNG/JPEG photos,
900,000bytes each and a4MiB actual JSON-body limit on that route only. Header,
container, dimensions, canonical base64, explicit consent and decoded structured
results are validated. Provider URLs are fixed; redirects and environment proxies
are disabled. Upstream envelopes are limited to256KiB, facts to128KiB and output
to8,192tokens. Request/validation/provider errors do not echo photos, keys or
provider response bodies. Quota counters use fixed documents: one global and256
actor buckets, with default100requests/day globally and10/day per bucket. Bucket
collisions share a conservative allowance. Existing Firestore deny-all client
rules and backend-only credentials remain unchanged.

## Evidence and privacy

Facts are `machine_extracted_unverified`, with missing fields remaining null,
separate explicitly based tables, qualifiers and normalized detected regions.
AI output does not become a confirmed package observation or overwrite canonical
data. This route does not persist extraction output, raw OCR, prompts or images.
The later app flow must qualify these results and keep photos outside sync.

Provider handling differs: Google's free-tier data-use terms must be shown before
transfer. OpenAI requests use `store:false`; that is not a promise of provider
zero retention. See [Gemini pricing/data-use](https://ai.google.dev/gemini-api/docs/pricing)
and [OpenAI data controls](https://platform.openai.com/docs/guides/your-data).
No paid Firebase services or billing/card setup is added.

The synthetic Gemini check is [recorded separately](../research/AI_VISION_SYNTHETIC_CHECK.json).
It validates one clear owned test label and timing, not real-package accuracy,
native camera behavior, all model/provider access or production deployment.
