# Data flow

Updated **12 October 2026** against frontend **v0.7.0+11** and backend
**v0.12.0**. The current API exports **27 paths / 28 operations**. Latest
frontend hosted proof is pending; backend read-only hosted proof is separate
from authenticated AI/staging and physical-device accuracy.
[Frontend review](../planning/FRONTEND_V0_7_0_REVIEW.md) ·
[Backend review](../planning/BACKEND_V0_12_0_REVIEW.md).

## Capture, source lookup and qualified results

1. `frontend/lib/core/capture/` receives camera/gallery photos and decodes a
   captured barcode/checksum before AI/OCR. A known sourced report can open
   directly. Front/back pairing, cancellation, geometry and stale responses are
   handled locally; continuous live decoding is a separate gate.
2. The repository searches the read-only bulk catalogue and separate research
   catalogue, or requests exact live OFF facts. Research observations retain their
   publisher/date/pack/identity limits; they are not confirmed physical labels.
3. Local OCR uses Android ML Kit, iOS Vision or same-origin browser Tesseract.
   Explicitly consented scanner-authenticated Gemini/OpenAI extraction is optional;
   an unavailable cloud route falls back locally. Missing/ambiguous fields stay
   unknown. Photos are not sent by ordinary product, report or private-sync calls.
4. Extracted results are `machine_extracted_unverified`. Literal declarations,
   detected regions and explicitly based tables remain qualified. Human acceptance
   uses a separate strict confirmed-observation path; bounded qualifiers and
   uncertain geometry cannot become exact public quantities automatically.
5. Reports show original source/age/evidence, table basis, separate storage outcomes
   and useful partial states. Six reviewed ingredient functions, original-basis
   sugar cubes and exact-source comparison have their own source references.

[Automatic scan plan](../planning/AUTOMATIC_SCAN_PLAN.md) ·
[OFF adapter](OPEN_FOOD_FACTS.md) · [AI routing](AI_ROUTING.md).

## Preserved normalization and claim contracts

Live OFF reads use a fixed origin/application User-Agent, an eight-second default
total deadline and a 512 KiB decoded-response budget. Direct nutrition accepts
eligible packaging/manufacturer input tables; estimated/computed/legacy aggregates
stay unavailable. Parsing is bounded to 16 tables and 64 accepted rows, omitting
an over-budget table as a whole. Separate tables are never silently combined.

Confirmed normalization accepts 1–64 strict structured rows, UUID request/session
IDs, correction revision and completeness. Its 32 KiB actual-byte request cap
runs before JSON parsing. No provider connection, photo/raw OCR or personal
profile is needed. Units/bases are normalized only with sufficient evidence;
unknown serving sizes remain per serving. Zero stays zero. Sodium/salt,
total/added sugar and available/total carbohydrate retain separate meanings.

The response retains original rows, source-row references and conversion versions.
`complete` means processing completed for supplied rows, not full nutrient
coverage. Provider and confirmed input origins remain separate. Selected
user-confirmed claims require applicability context and sufficient input; unsupported,
missing or conflicting evidence yields `insufficient_information`. Statutory
fibre energy uses original rows at **4.2 kJ/kcal**; normalization-v1 retains
**4.184**. No health/allergy/compliance verdict follows from these outcomes.

## Automatic observations and resolution

Confirmed public facts use separate automatic intake with lazy anonymous or
existing password scanner authentication. The server keeps original rows/context,
normalized full/factual hashes, immutable receipts and semantic deduplication.
Provisional/barcode-less facts stay private staging with bounded seven-day expiry
and write-time cleanup. Compatible exact front/back facts may become explicitly
qualified unreviewed candidates; conflicts/identity mismatches await exact-hash
maintenance. Moderator review is never current-package or safety proof.

Resolved views preserve source groups, date, completeness, alternatives and
conflicts. Incompatible tables remain unselected rather than averaged. Unknown
branded values are not filled from generic-food composition. OFF-only resolution
remains useful during community unavailability; saving never disables independent
normalization/claim evaluation. [Community lifecycle](COMMUNITY_CATALOGUE.md).

AI proposals use different private staging: 256 fixed actor-hash buckets, eight
items each, at most 32 KiB fact JSON per item and seven-day write-time pruning.
Photos, geometry/region text, prompts, raw OCR and provider envelopes are excluded.
Extraction reports `private_unverified` or `not_stored`; storage failure preserves
useful fields and does not change the active credential. There is no public
machine-staging read or paid TTL service. [AI boundaries](AI_ROUTING.md).

## Personal storage and educational content

| Data | Location / retention boundary |
| --- | --- |
| Photos/live frames | Local temporary capture; optional external extraction only after consent; never account/database sync |
| Machine fields/corrections | Local scan session; accepted public fields and private AI proposals have separate admission |
| Dated saved/history reports | Guest local library or isolated verified-UID namespace; optional password-owned bounded private sync |
| Dietary/allergen reminders | Device-local, editable/deletable; never personal backend/AI input |
| Appearance/Welcome completion | Device-local |
| Insights | Twenty bundled articles/illustrations; date-stable daily four shared by Home/Insights |
| Insight bookmarks | Device-local protected storage/recovery; outside account sync |
| Curated public sources/knowledge | Versioned tracked source; independently verified generated read-only artifacts |

Private sync carries only bounded display name/saved/history snapshots. Explicit
cloud/device choices resolve differences; uncertain writes retain immutable UUID,
payload and CAS revision. Browser eviction/private mode/site clearing can lose
local data. `data/private/` is ignored development input, not a production upload
target. [Private sync](PRIVATE_ACCOUNT_SYNC.md) · [Insights](INSIGHTS.md).

## Builds, failures and verification boundaries

The network-free build verifies tracked source hashes/counts, generates separate
bulk/research SQLite and receipts, and packages the two approved claim JSON files.
Its JSON output includes `catalogue`, `claims_knowledge` and `research_catalogue`.
Hosted startup enables each source only after independent integrity verification.
A broken artifact does not activate an unverified source or silently fall back to
canonical development files. [Catalogue workflow/rollback](CATALOGUE.md).

| Failure | Behavior |
| --- | --- |
| Source not found/unavailable | Qualified missing/partial/outage state; no invented facts |
| Cloud extraction unavailable/invalid/quota-limited | Useful local fallback; machine output never overrides deterministic claims |
| Save/staging unavailable | Useful report/extraction with separate storage outcome |
| Invalid knowledge/glossary | Suppress affected assessments/detail; retain available facts |
| Interrupted/stale request | Preserve local session and discard mismatched responses |
| Backend offline | Dated saved content, reminders, bundled Insights and supported local capture; fresh lookup/analysis waits |
| Website camera denied/unsupported | Supported gallery recovery and capture lifecycle cleanup |

The website requires a secure camera context. A loaded page/local store does not
prove first-visit offline use or airplane-mode restart. Source/widget/synthetic
checks are separate from native accuracy, measured 3–5 second scans,
authenticated hosted generation, private writes and a complete offline web cache.

## Historical evidence retained

The v0.2.3 full acquisition reached validated gzip EOF with **24,695 India rows**
and **24,641 supported codes**, source **2026-10-06T06:53:46Z**, refresh due
**2027-07-06T06:53:46Z**. Its dated generated SQLite was **62,472,192 bytes**;
[coverage/build report](../research/CATALOGUE_V0_2_3_COVERAGE.json) and
[hosted proof](../research/BACKEND_V0_2_3_PRODUCTION.json) remain historical.
Current bulk records and 243 separate research observations are preserved.
Coverage remains unverified. Refresh uses nine calendar months from source
export, never a new build date; replacement creates a new immutable deployment.
The v0.3.0/v0.8.0 and v0.9.0/v0.4.0 release checkpoints remain in their original
reviews and do not establish current hosted behavior.
