# Feature and integration tracker

Automatic extraction checkpoint (8 October 2026): backend **v0.11.0** adds
bounded Gemini/OpenAI photo reading with exactly one globally active credential,
sticky failure replacement and scanner authentication. **1,303 tests pass**, with
five explicit provider/emulator skips. Keys are server-only; AI facts remain
unverified and photos stay outside database/account sync. Deployment verification
is pending. [Backend review](BACKEND_V0_11_0_REVIEW.md) ·
[Automatic scan plan](AUTOMATIC_SCAN_PLAN.md).

The selected storage remains a verified read-only SQLite public catalogue plus
Firestore mutable observations/accounts/AI selection. New sourced data is
validated and rebuilt into SQLite; no existing dataset is deleted or migrated.

Research database checkpoint (8 October 2026): backend **v0.10.0** implements
three independent researched-product read APIs. The generated database contains
**243 source observations**: **49 manufacturer, 125 retailer and 69 exact-code OFF**.
Frontend **v0.5.0+6** adds mixed-source search and qualified product details.
Local generation is verified; independent final checks, push and hosted proof are
tracked in the [backend review](BACKEND_V0_10_0_REVIEW.md) and
[frontend review](FRONTEND_V0_5_0_REVIEW.md). The
[full website product list](../research/POPULAR_PRODUCTS_ADDED.md) records packs,
ingredients, table availability and source links. Unknown identities, missing
values and incompatible formulas stay qualified. Retail coverage is unmeasured.


Verified checkpoint (8 October 2026): backend **v0.9.0** and frontend
**v0.4.0+5** were independently reviewed, documented and pushed on `main`.
Their exact implementation deployments are READY with **26 backend / 49 frontend
hosted checks**, including all 21 OCR asset hashes. The local suites passed
**1058 backend tests (five provider skips) / 181 Flutter tests**; static checks,
release web build and synthetic browser workflows passed. Physical-device gates
and separate GitHub source-release publication are not established by this proof.
[Backend review](BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](FRONTEND_V0_4_0_REVIEW.md).

Checkpoint: **8 October 2026**. Backend v0.7.0 and frontend v0.2.0+3 are published
and hosted-verified; their historical reviews/receipts remain unchanged. Frontend
v0.3.0+4 now has reference Welcome/Profile, app-only startup, private local OCR,
editable confirmation, immediate search focus, opaque headers and the requested
navbar gap/drag behavior. Scan Label and navbar design/order remain preserved.
Local checks: **168 Flutter tests**, clean analysis, web build, four OCR bridge
tests and successful synthetic browser recognition. Frontend v0.3.0 is independently
published from implementation `3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`, READY
deployment `dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, with 49 hosted checks and all 21 OCR hashes.
Hosted Welcome, actual Search input focus/results, public report save and Profile
counts work. [Source release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0) ·
[Production receipt](../research/FRONTEND_V0_3_0_PRODUCTION.json).
Later docs-only closure commits preserve that implementation identity.
Backend v0.8.0 was pushed from `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` and hosted-verified with 25 checks at READY deployment `dpl_651iY8R8Dj6wNEdVC71Kw3ZW4oig`; its source-release publication is not established by that receipt.
Current implementation slices are **backend v0.9.0 Reviewed Ingredient Functions** and **frontend v0.4.0+5 Sourced Comparison and Ingredient Detail**. Each receives independent tests, review, documentation, push and exact-source hosted checks. See [the implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md). [Next versions](FRONTEND_BACKEND_NEXT_VERSIONS.md) ·
[Frontend review](FRONTEND_V0_3_0_REVIEW.md).

The five original concept screens describe **20 feature groups**. The historical
v0.6.0 backend baseline has **9 ready, 2 partial, 3 planned and 6 client-owned**
groups; these count capabilities, not effort or percentage completion. C01/C02
are additional public-catalogue/private-account scope. v0.2.0 client comparison
and educational destinations use existing sourced contracts; broader coverage
and the remaining reference-style screens remain tracked below. Concept scores,
sample products and health verdicts are illustrative.

| ID | Feature / screen | Backend current | Frontend current / remaining |
| --- | --- | --- | --- |
| F01 | Barcode identity / Home, Scan | Ready: live and exact snapshot routes | Manual barcode entry/report integrated inside Scan Label; automatic camera barcode detection remains pending |
| F02 | Search / Home | Ready: released v0.6.0 bounded indexed discovery | Name/brand search, paging and explicit selection published; v0.3.0 immediate mounted input focus, public cache/queue/skeleton and real hosted results verified |
| F03 | Photos / Results, Compare | Ready: official attributed URL descriptors | Official attributed image/fallback used for actual records; cute generated artwork is decorative and cannot impersonate a scanned product |
| F04 | Nutrition and normalization / Results | Ready | Corrected rows, original basis/unit/preparation and report tables implemented; local OCR with editable review implemented in v0.3.0; nutrition rows remain manual |
| F05 | OFF Nutri-Score/NOVA / Home, Results | Ready: optional provider values | Dedicated grade/source display pending; no Unlabel 0–100 health score |
| F06 | Unified report/reasons / Results | Ready: released v0.5.0 | Current/historical sourced reports and reference analysis published; hosted v0.3.0 public report opened/saved without stale SnackBar failure |
| F07 | Claim checks / Results, Ingredients | Partial: seven reviewed numeric types | Manual identified claims, correction and scoped verdicts implemented; broader claims remain insufficient |
| F08 | Ingredient explanations / Ingredients | Partial: v0.9.0 expands to six reviewed English/Hindi name/function entries | v0.4.0 adds matched-ingredient detail with bilingual functions and evidence; broader ingredient coverage remains partial |
| F09 | Allergens/traces / Scan, Ingredients | Ready: source availability and declarations | Confirmed declaration input and sourced report display implemented; no absence/safety inference |
| F10 | Personal suitability / Results | Planned | Device-local dietary/allergen reminders implemented; suitability/filtering remains future and does not infer allergy safety |
| F11 | Comparison / Compare | v0.8.0 sourced endpoint pushed and hosted-verified; v0.9.0 preserves the route | v0.4.0 integrates exact-source table selection and server comparison into existing paired cards; no universal healthier verdict |
| F12 | Sugar visualization / Results | Ready: released v0.5.0 | Approximate 4 g/cube total-sugar view with original basis implemented; added sugar stays distinct |
| F13 | Reviewed insights / Home | Planned | Published educational list/detail destinations with source/applicability; broader reviewed coverage remains future; no fabricated health advice |
| F14 | Front/back and gallery / Scan | Client-owned | Published camera/gallery capture, permissions, retry and manual review; v0.3.0 local post-capture reading published; automatic barcode detection and measured device accuracy remain future |
| F15 | OCR/live highlights / Scan | Client-owned; confirmed rows accepted | Local English/Hindi OCR and editable suggestions implemented; automatic nutrition-table interpretation/live boxes and real-device accuracy remain future |
| F16 | Saved products / Home | Client-owned; private sync published in v0.7.0 | Published bounded bookmarks/reopening/removal; guests local, signed-in UID-specific private sync; hosted v0.3.0 public report save and Saved count verified |
| F17 | History / Home | Client-owned guest local; optional private sync published | Published bounded dated history/clearing, guest/account isolation and optional private sync; hosted v0.3.0 Profile Scans count verified |
| F18 | Profile/preferences / Home | Client-owned private choices | Optional password sign-in/create/reset, display name/private sync, explicit conflict choices and sign out implemented; guest mode fully usable; v0.3.0 reference Profile uses real controls/counts and explicitly unavailable notifications/comparison totals |
| F19 | Responsive/light/dark / All | Client-owned | Published responsive Material 3/light default/persisted appearance; light Welcome/Profile visually checked at 390/1440/1728px and theme/large-text tests pass; native icon checks separate |
| F20 | Attribution/age/version / All | Ready | Published metadata/source/date/evidence/build information and working source details; exact hosted v0.3.0 version/build/assets verified |
| C01 | Shared Indian package facts | Ready: released v0.4.0 | Automatic confirmed structured intake through lazy anonymous auth implemented; useful analysis survives save failure |
| C02 | Optional scanner account/private sync | v0.7.0 pushed and hosted-verified; 931 passed/5 skips and 18 hosted synthetic checks; independently published | v0.2.0 implemented: guests local, UID-specific private sync after optional login; 25 focused account tests pass; 135 tests, clean analyzer, hosted READY web deployment and source release published |

## Component releases

| Component/version | Meaningful goal | Evidence / state |
| --- | --- | --- |
| Backend v0.2.3 | Rich India snapshot facts | Independently published historical source/build/hosted proof |
| Backend v0.3.0 | First reviewed numerical claim checks | Independently published; seven scoped numeric claim types |
| Backend v0.4.0 | Community Product Catalogue | Independently published; automatic observations, deduplication, qualified facts and private staging |
| Backend v0.5.0 | Useful Label Report | Independently published; reports, approximate sugar and three-entry glossary; [review](BACKEND_V0_5_0_REVIEW.md) |
| Backend v0.6.0 | Product Discovery | Published after 863 passed / 5 emulator skips and 23 hosted checks; [review](BACKEND_V0_6_0_REVIEW.md) |
| Frontend v0.1.0+2 | Connected Label Reader | Independently published exact commit 1138c292296ae6c9309d73d430d267ec1a98fa80; production assets/browser proof recorded |
| Backend v0.7.0 | Private Account Sync | Pushed and hosted-verified source 9d9a9b6; independently published; 931 passed/5 skips plus 18 hosted synthetic checks; [review](BACKEND_V0_7_0_REVIEW.md) |
| Frontend v0.2.0+3 | Welcome, Home and Optional Login | Independently published; 135 tests and hosted production receipt |
| Frontend v0.3.0+4 | Visual Label Reader and reference Welcome/Profile | Published exact implementation `3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`; 168 tests, READY deployment, 49 hosted checks and all 21 OCR hashes; native gates separate |
| Backend v0.8.0 | Sourced Nutrient Comparison | Pushed exact source `1a2fd25`; READY hosted deployment and 25 checks; source-release publication not established |
| Backend v0.9.0 | Reviewed Ingredient Functions | Six entries, strict source/alias validation and immutable evidence; independently pushed/READY, 1058 tests/five provider skips and 26 hosted checks |
| Frontend v0.4.0+5 | Sourced Comparison and Ingredient Detail | Exact sources, selected tables, guarded responses and bilingual detail; independently pushed/READY, 181 tests and 49 hosted checks |

Each component is reviewed, documented, pushed and verified before its separate
publication. Historical tags and native artifacts are preserved. A backend test
does not prove a rendered app flow, hosted behavior, Firestore isolation or a
physical camera/device journey.

## Data and identity boundaries

Read `/v1/meta` first. Search yields candidates, never package confirmation.
Current corrected facts and dated catalogue reports preserve their own evidence.
Missing remains unknown; generic Indian food composition does not fill branded
packet gaps. No custom model or Gemini is selected.

In frontend v0.1.0, personal history, bookmarks and preferences stay local.
Confirmed structured public product facts save automatically with anonymous
scanner authentication; there is no separate Share step. The later user request
authorizes **optional login/profile/private sync** for v0.7.0/v0.2.0: guests keep
the same useful features without personal cloud storage, and signed-in scanners
may sync their own data. There is still one scanner role, with no admin/reviewer
app account or dashboard. Photos/raw OCR are excluded from public observations.

Related: [Master plan](MASTER_PLAN.md), [workflows](FEATURES.md),
[Indian food coverage](../research/INDIAN_FOOD_COVERAGE.md),
[community catalogue](../architecture/COMMUNITY_CATALOGUE.md).
