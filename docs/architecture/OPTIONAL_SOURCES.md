# Optional backend sources

Every backend source can be disabled without removing its files. A fresh clone
can start without any private API keys. Build the bundled data with
`python scripts/setup.py`; see [local development](../development.md).

Copy [backend/.env.example](../../backend/.env.example) to ignored `backend/.env`.
Leave unused keys blank. `AI_ENABLED=auto` resolves
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
| Community/authenticated machine observations | `UNLABEL_COMMUNITY_ENABLED` on self-hosted API (`COMMUNITY_ENABLED` for legacy runtime) | Verified identity, PostgreSQL admission/AI tables and separate evidence worker | Disabled; guest libraries stay on device |
| Private account synchronization | `ACCOUNT_SYNC_ENABLED` | Configured community runtime and signed-in owner | Disabled; device-local workflows remain |

The keyless source switches default to `true`. Community writes and private sync
retain explicit `false` defaults because they enable persistence. To disable
everything external, set `OFF_ENABLED=false`, `AI_ENABLED=false`,
`COMMUNITY_ENABLED=false`, and `ACCOUNT_SYNC_ENABLED=false`.
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
community, private synchronization, notifications and consented photo extraction.
The refreshed Gemini key is valid and Gemini is the active provider; OpenAI
returned a quota error during live generation. `ai_explanations:false` is an
unimplemented reserved capability, not a disabled screen; reviewed ingredient
explanations come from the enabled glossary.

Check `/v1/meta` for actual initialized capabilities and source status. It never
returns API keys. A disabled provider cannot be selected by a client request.

## Secrets and retired providers

Never commit plaintext `.env` or put provider keys in Flutter build defines.
Run `secrets/secrets.ps1 encrypt` after secret changes to refresh the authenticated
project bundle and legacy backend ciphertext. A clone owner uses an authorized
private identity through the hidden local prompt.

NutriGraphAPI was removed at the operator's request, including its adapter,
route, client display, local/example variables and Coolify environment entries.
Its refreshed credential failed the supplied lookup (404) and alias (401).
Historical contracts and source records remain historical evidence only.
