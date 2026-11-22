# Optional backend sources

Every backend source can be disabled without removing its files. A fresh clone
can start without any private API keys. Build the bundled data with
`python scripts/setup.py`; see [local development](../development.md).

Copy [backend/.env.example](../../backend/.env.example) to ignored `backend/.env`.
Leave unused keys blank. `AI_ENABLED=auto` and `NUTRIGRAPH_ENABLED=auto` resolve
from the configured credentials at startup. `false` overrides a present key;
`true` cannot make a missing key usable. Restart after changing configuration.
An enabled/configured source is not proof that its upstream endpoint works.

| Source | Switch | Required configuration | Without configuration |
| --- | --- | --- | --- |
| Open Food Facts live reads | `OFF_ENABLED` | No key; bounded application User-Agent is derived from the version | Enabled by default; `false` makes no OFF request |
| Bundled OFF catalogue | `CATALOGUE_ENABLED` | Generated catalogue and `CATALOGUE_DIRECTORY` | Unavailable if absent; other sources still work |
| Research observations | `RESEARCH_CATALOGUE_ENABLED` | Imported Mongo evidence and PostgreSQL search projection on the hosted API; generated database for legacy local runtime | Unavailable if absent; tracked source observations remain untouched |
| Reviewed claim knowledge | `CLAIMS_ENABLED` | Validated local/bundled knowledge | No reviewed claim results when disabled/unavailable |
| Reviewed ingredient glossary | `GLOSSARY_ENABLED` | Bundled reviewed glossary | Ingredient declarations remain available without glossary explanations |
| Gemini extraction | `AI_ENABLED=auto`, `GEMINI_ENABLED` | Valid `GEMINI_API_KEY` and authenticated persistence below | Slot absent; OpenAI works independently |
| OpenAI extraction | `AI_ENABLED=auto`, `OPENAI_ENABLED` | Valid `OPENAI_API_KEY` and authenticated persistence below | Slot absent; Gemini works independently |
| NutriGraph live facts | `NUTRIGRAPH_ENABLED=auto` | Working vendor endpoint and key | Removed from active production sources after failed refreshed-key checks at the operator's request |
| Community/authenticated machine observations | `UNLABEL_COMMUNITY_ENABLED` on self-hosted API (`COMMUNITY_ENABLED` for legacy runtime) | Verified identity, PostgreSQL admission/AI tables and separate evidence worker | Disabled; guest libraries stay on device |
| Private account synchronization | `ACCOUNT_SYNC_ENABLED` | Configured community runtime and signed-in owner | Disabled; device-local workflows remain |

The keyless source switches default to `true`. Community writes and private sync
retain explicit `false` defaults because they enable persistence. To disable
everything external, set `OFF_ENABLED=false`, `AI_ENABLED=false`,
`NUTRIGRAPH_ENABLED=false`, `COMMUNITY_ENABLED=false`, and `ACCOUNT_SYNC_ENABLED=false`.
The bundled catalogue, research observations and reviewed knowledge can still work.

## Credential selection and authentication

`AI_INITIAL_CREDENTIAL_ID=auto` selects the first enabled configured slot:
Gemini, then OpenAI, then replacement credentials. An OpenAI-only installation
therefore works without inventing a Gemini credential. Explicit slot IDs remain
supported. The existing shared active choice stays sticky; changing/rotating
credentials still requires the documented operator activation when shared state
already exists. `GEMINI_ENABLED=false` or `OPENAI_ENABLED=false` also excludes
that provider's replacement slots.

Cloud extraction keeps the authenticated backend boundary. The self-hosted API
verifies identity sessions and uses PostgreSQL for admission, quotas, private
staging and active-provider state. Community and compatible machine publication
enqueue a durable job; the evidence worker archives strictly validated public
facts into separate Mongo collections with find/insert-only credentials. It
never archives photos, raw OCR or account identifiers. Firebase configuration
below applies only to the legacy runtime: `COMMUNITY_ENABLED=true`,
`COMMUNITY_PROJECT_ID`, `COMMUNITY_SERVICE_ACCOUNT_JSON` and
`COMMUNITY_ACTOR_SECRET`. No unauthenticated vendor proxy is opened.

Production enables OFF, the licensed catalogue, research, claims, glossary,
community, private synchronization, notifications and OpenAI photo extraction.
The current Gemini credential is rejected upstream, so OpenAI is the active slot.
`ai_explanations:false` is an unimplemented reserved capability, not a disabled
screen; reviewed ingredient explanations come from the enabled glossary.

Check `/v1/meta` for actual initialized capabilities and source status. It never
returns API keys. A disabled provider cannot be selected by a client request.

## Secrets and the NutriGraph sandbox

Never commit plaintext `.env` or put vendor keys in Flutter build defines.
After changing local secrets, run `python scripts/env.py encrypt` to refresh
tracked `backend/.env.age` using the public recipient. A clone owner supplies
their own secrets, or decrypts only with an authorized private identity through
the hidden local prompt. The encrypted file does not make credentials public.

NutriGraph data is exact-identity, provider-unverified, in-memory and expires
within 24 hours. It is never serialized into saved reports, history, private
sync or either permanent catalogue. The supplied sandbox allowance is 1,000
total requests; two checks were made on 26 October and the local remaining cap
was set to 998. The cap and monthly guard are per process, so restarts/replicas
do not establish a durable account-wide remaining balance. The vendor remains
the account-wide quota authority. An upstream 429 stops new requests for that
process; generic HTML 404 responses report provider unavailability rather than
claiming that a food is absent.

The refreshed vendor key was checked on 22 November using its supplied UPC.
`/api/lookup` returned JSON 404 `Not Found`; the documented `/fetch` alias
returned 401 `Unauthorized`. The operator requested removal if it failed;
production therefore sets `NUTRIGRAPH_ENABLED=false`. Integration code and
historical provenance remain available for a future verified vendor repair.
No successful lookup or regional India coverage is claimed.
