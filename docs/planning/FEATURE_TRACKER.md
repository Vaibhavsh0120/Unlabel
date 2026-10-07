# Feature and integration tracker

Next accepted releases: **backend v0.6.0 Product Discovery** and **frontend
v0.1.0+2 Connected Label Reader**. Search is implemented and locally reviewed;
its separate hosted/publication gate is pending. Frontend manual lookup, reports,
confirmed entry and local libraries are implemented with test/rendered/release
gates in progress. [Connected plan](CONNECTED_RELEASE_PLAN.md).
With discovery, backend capability counts become **9 ready, 2 partial, 3 planned**
plus **6 frontend-owned groups**. This counts capabilities, not effort completed.

The five supplied [concept screens](../../design/references/README.md) describe **20 feature groups**. Their example scores and verdicts are design references, not approved product facts. Backend and frontend readiness are separate: an endpoint still needs client integration and device checks. Community supporting group **C01** is outside that original baseline. The [master plan](MASTER_PLAN.md) defines the complete useful flow and release order.

Baseline: published **backend v0.2.2**, frontend **0.0.0+1**. Backend scope has **4 ready groups, 1 partial group and 9 planned groups**; **6 groups primarily belong to the frontend**. These are capability counts, not effort percentages. All five concept screens remain unintegrated in the Flutter starter.

After verified v0.2.3: **6 ready, 0 partial and 8 planned backend groups**, plus **6 frontend-owned groups**. All frontend integration remains pending.

After released v0.3.0: **6 ready, 1 partial and 7 planned backend groups**, plus **6 frontend-owned groups**. Claim checks now cover seven reviewed numeric claim types; broader claim evidence remains incomplete. Both backend versions were reviewed, pushed, verified in production and published independently. This measures capabilities, not the percentage of development effort completed.

Published production is **v0.5.0 Useful Label Report**, independently reviewed,
pushed, hosted-verified and released after v0.4.0. C01 remains released. F06 and
F12 are ready; F08 stays partial for three reviewed ingredient name/function
entries. The baseline is **8 ready, 2 partial and 4 planned backend groups**, plus
**6 frontend-owned groups**. These are capabilities, not effort percentages; all
concept-screen frontend integration remains pending. [Current review](BACKEND_V0_5_0_REVIEW.md)
and [twenty hosted checks](../research/BACKEND_V0_5_0_PRODUCTION.json) separate
local, emulator, live Firebase and hosted evidence.

| ID | Feature / screen | Backend current | Frontend work | Acceptance or milestone |
| --- | --- | --- | --- | --- |
| F01 | Barcode identity / Home, Scan | Ready: live and snapshot | Camera/manual entry and results pending | Found/missing/unavailable; exact snapshot keys |
| F02 | Search / Home | Implemented: v0.6.0; hosted gate pending | Implemented; rendered/release gate pending | Bounded snapshot search and pagination; candidate identity confirmation |
| F03 | Photos / Results, Compare | Ready: v0.2.3 descriptors | Image/fallback pending | v0.2.3: official URL, language and attribution |
| F04 | Nutrition and normalization / Results | Ready | Correction form/table pending | Preserve origins, bases, zero/unknown and conflicts |
| F05 | OFF Nutri-Score/NOVA / Home, Results | Ready | Grade/source display pending | Optional provider values; separate from an Unlabel score |
| F06 | Unified report/reasons / Results | Ready: released v0.5.0; hosted-verified | Report layout pending | Source-linked current/historical report; missing inputs visible; no universal score required |
| F07 | Claim checks / Results, Ingredients | Partial: seven reviewed numeric types | Capture/edit/verdict pending | v0.3.0: strict confirmed input, rule/evidence references; wider claims incomplete |
| F08 | Ingredient explanations / Ingredients | Partial: released v0.5.0; three reviewed name/function entries | Explorer pending | Lecithin 322(i), citric acid 330, xanthan gum 415; English/Hindi functions with evidence; wider coverage pending |
| F09 | Allergens/traces / Scan, Ingredients | Ready: live and snapshot availability | Correction/warnings pending | v0.2.3: snapshot field availability; no allergy-safety claim |
| F10 | Personal suitability / Results | Planned | Local preferences/reasons pending | Unknowns and conflicts; neutral preference facts |
| F11 | Comparison / Compare | Planned | Selection/charts pending | Compatible category, mass/volume and preparation |
| F12 | Sugar visualization / Results | Ready: released v0.5.0; hosted-verified | Cubes/basis pending | Total sugar only; explicit 4 g/cube approximation and original basis/preparation; added sugar stays distinct |
| F13 | Reviewed insights / Home | Planned | Feed/details pending | Source, applicability and content version |
| F14 | Front/back and gallery / Scan | Client-owned | Pending | Correct sides, permissions and manual path |
| F15 | OCR/live highlights / Scan | Client-owned; confirmed rows accepted | Pending | Bounding boxes, correction and real-device checks |
| F16 | Saved products / Home | Client-owned local storage | Pending | Dated facts/report versions; local removal/export |
| F17 | History / Home | Client-owned local storage | Pending | Cached history distinct from a fresh lookup |
| F18 | Profile/preferences / Home | Client-owned private choices | Pending | Local persistence/reset; explicit controls |
| F19 | Responsive/light/dark / All | Client-owned | Starter only | iPhone/iPad/MacBook, text scaling and keyboard |
| F20 | Attribution/age/version / All | Ready | Source/version display pending | Capability handshake and dates; no certification label |
| C01 | Shared Indian package-fact coverage / supporting scope | Released: v0.4.0; hosted-verified | Pairing/correction, automatic anonymous requests and source/conflict views pending | Four routes, semantic dedup, private staging/receipts, qualified candidates, typed sources and configured free Firebase |

## Backend version goals

| Version | Goal | Completion evidence | State |
| --- | --- | --- | --- |
| v0.2.3 | Rich India snapshot product facts | Full JSONL EOF/hash/counts; compact source; typed facts API; nutrition/image/tag/date boundaries; old contracts; actual hosted reads | Verified and pushed |
| v0.3.0 | First evidence-backed claim checks | 543 tests; zero static errors/warnings; current reviewed FSSAI sources; strict confirmed-input/rule/evidence APIs; 72 hosted HTTP checks and exact build receipts | Verified, pushed and published |
| v0.4.0 | Community Product Catalogue | Implemented automatic observation save/dedup, private staging/receipts, qualified candidates/review, typed fields and configured free Firebase | Reviewed, pushed, hosted-verified and published; [review](BACKEND_V0_4_0_REVIEW.md) |
| v0.5.0 | Useful Label Report | F06/F12 ready; F08 partial: three reviewed ingredient functions; 18-route OpenAPI and 22 validated examples | Reviewed, pushed, hosted-verified and published after separate v0.4.0; [review](BACKEND_V0_5_0_REVIEW.md) |
| v0.6.0 | Product Discovery | 863 tests passed, five emulator skips; clean static checks; old routes/components preserved; same-source setup upgrade | Locally reviewed; push/hosted/publication pending; [review](BACKEND_V0_6_0_REVIEW.md) |

Each version is reviewed, documented, pushed and verified before the next is published. Rows advance only after their stated behavior is checked. A broad claim feature remains partial while other claim families or manufacturing/category evidence are unresolved.

## Frontend connection

The [Indian food coverage strategy](../research/INDIAN_FOOD_COVERAGE.md) tracks
barcode/back/front paths separately. v0.4.0 accepts automatic structured facts,
stages unverified observations and resolves compatible sourced fields while
preserving originals. APIs are implemented; camera/OCR/background requests still
need frontend integration. Released v0.5.0 provides reports, approximate sugar cubes
and three ingredient functions; their UI remains pending. Front text search and regional capture benchmarks
remain future scope; no photo recognition is implemented.


Read `/v1/meta` first and check API major/capabilities. Select live or snapshot identity explicitly; snapshot misses do not call OFF automatically. v0.2.3 adds a separate facts model, preserving the old product parser. Correct community values against the current package, retain origins and submit confirmed structured rows with request/session/revision IDs.

Show a positive claim only with applicable evidence and sufficient confirmed inputs. Keep unknown nutrients, `insufficient_information`, correction, provider failure and snapshot misses distinct. Claim checks use deterministic reviewed rules without Gemini. Rendering, camera/OCR, saved state and offline behavior remain frontend work.

No interactive account or separate Share action is planned. Confirmed public
product facts save automatically, with anonymous write auth behind the scenes;
extracted candidates stay unverified. Photos/private OCR/profiles/history stay
private. Compatible field complementing keeps source/date and original
observations; approval does not confirm the current caller's packet. Local OCR
comes first, no custom training is selected and Gemini remains disabled until a
measured fallback benchmark.
[Master plan](MASTER_PLAN.md) · [Community catalogue](../architecture/COMMUNITY_CATALOGUE.md).

Related: [Workflows](FEATURES.md), [versions](../superpowers/plans/2026-10-05-backend-versions.md), [API plan](../architecture/API_PLAN.md), [backend guide](../../backend/README.md).
