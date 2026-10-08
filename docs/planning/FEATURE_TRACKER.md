# Feature and integration tracker

Published checkpoint, 8 October 2026: **frontend v0.6.1+8 / backend v0.12.0**
are pushed on `main`, with READY production deployments and **55 frontend / 389
backend hosted checks**, including all 21 OCR asset hashes. All 243 researched
observations and their separate 120 image descriptors match the pinned sources.
Automatic barcode/photo reading, the reference Home/results layout, private
structured proposals and richer research search are deployed. Authenticated hosted
AI generation, physical camera accuracy and the 3–5 second shopping target remain
separate verification gates.
[Frontend review](FRONTEND_V0_6_1_REVIEW.md) ·
[Backend review](BACKEND_V0_12_0_REVIEW.md).

The new **frontend v0.6.1+8** correction keeps sidebar leaves behind content,
preserves navigation in shorter windows, replaces the tightly cropped insight
image, compacts recent scans and adds separate expanded Profile editors. The
mobile indicator follows hold/direct drag with release selection and cancellation.
Its 232 passing tests, clean analysis, release build, local rendered review and
independent deployment gate are recorded in
[the correction review](FRONTEND_V0_6_1_REVIEW.md).

The original 24,641 bulk records and all 243 research observations remain
preserved. Real source-image descriptors cover 120 research observations; 123
remain without a descriptor. This is dated acquisition coverage, not complete
Indian retail coverage or current-pack image verification.

Automatic extraction checkpoint (8 October 2026): backend **v0.11.0** adds
bounded Gemini/OpenAI photo reading with exactly one globally active credential,
sticky failure replacement and scanner authentication. **1,303 tests pass**, with
five explicit provider/emulator skips. Keys are server-only; AI facts remain
unverified and photos stay outside database/account sync. Deployment verification
passes for 389 public/API checks; authenticated hosted generation is separate.
[Backend review](BACKEND_V0_11_0_REVIEW.md) ·
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
| F01 | Barcode identity / Home, Scan | Ready: live and exact snapshot routes | Local v0.6 decodes captured barcode/checksum before AI/OCR; known reports open directly. Continuous feed/device accuracy remain separate gates |
| F02 | Search / Home | Ready: released v0.6.0 bounded indexed discovery | Name/brand search, paging and explicit selection published; v0.3.0 immediate mounted input focus, public cache/queue/skeleton and real hosted results verified |
| F03 | Photos / Results, Compare | Ready: official attributed URL descriptors; local v0.12 adds 120/243 separate research descriptors | Actual sourced image or session front photo; missing images have an honest fallback. Fresh decorative artwork cannot impersonate a scanned product |
| F04 | Nutrition and normalization / Results | Ready; local v0.12 retains qualified machine proposals privately | Local v0.6 automatically reads explicitly based tables, preserves unknowns/bounds and blocks ambiguous public rows; physical accuracy and final verification remain separate |
| F05 | OFF Nutri-Score/NOVA / Home, Results | Ready: optional provider values | Dedicated grade/source display pending; no Unlabel 0–100 health score |
| F06 | Unified report/reasons / Results | Ready: released v0.5.0 | Current/historical sourced reports and reference analysis published; hosted v0.3.0 public report opened/saved without stale SnackBar failure |
| F07 | Claim checks / Results, Ingredients | Partial: seven reviewed numeric types | Local v0.6 reads front claim text automatically; only separately accepted sufficient inputs enter scoped deterministic assessments. Broader claims remain insufficient |
| F08 | Ingredient explanations / Ingredients | Partial: v0.9.0 expands to six reviewed English/Hindi name/function entries | v0.4.0 adds matched-ingredient detail with bilingual functions and evidence; broader ingredient coverage remains partial |
| F09 | Allergens/traces / Scan, Ingredients | Ready: source availability and declarations | Local v0.6 reads literal declarations with unknown/partial states and optional acceptance; sourced display retains its provenance. No absence/safety inference |
| F10 | Personal suitability / Results | Planned | Device-local dietary/allergen reminders implemented; suitability/filtering remains future and does not infer allergy safety |
| F11 | Comparison / Compare | v0.8.0 sourced endpoint pushed and hosted-verified; v0.9.0 preserves the route | v0.4.0 integrates exact-source table selection and server comparison into existing paired cards; no universal healthier verdict |
| F12 | Sugar visualization / Results | Ready: released v0.5.0 | Approximate 4 g/cube total-sugar view with original basis implemented; added sugar stays distinct |
| F13 | Reviewed insights / Home | Planned | Published educational list/detail destinations with source/applicability; broader reviewed coverage remains future; no fabricated health advice |
| F14 | Front/back and gallery / Scan | Optional authenticated photo reading implemented in v0.11; local v0.12 stages only private structured proposals | Local v0.6 automatically reads front/back/barcode capture/gallery photos with transfer consent and local fallback; no mandatory typing. Measured physical-device accuracy remains open |
| F15 | OCR/live highlights / Scan | Bounded machine facts/normalized regions; confirmed rows use separate admission | Local v0.6 paints actual post-capture regions and decoder anchors, with View results action; continuous live highlights and real-device accuracy remain future |
| F16 | Saved products / Home | Client-owned; private sync published in v0.7.0 | Published bounded bookmarks/reopening/removal; guests local, signed-in UID-specific private sync; hosted v0.3.0 public report save and Saved count verified |
| F17 | History / Home | Client-owned guest local; optional private sync published | Published bounded dated history/clearing, guest/account isolation and optional private sync; hosted v0.3.0 Profile Scans count verified |
| F18 | Profile/preferences / Home | Client-owned private choices | Optional password sign-in/create/reset, display name/private sync, explicit conflict choices and sign out implemented; guest mode fully usable; v0.3.0 reference Profile uses real controls/counts and explicitly unavailable notifications/comparison totals |
| F19 | Responsive/light/dark / All | Client-owned | Local v0.6 adds reference desktop sidebar/Home and stacked/two-column product results. Final screenshot comparison at 390/1440/1728 is in progress; earlier Welcome/Profile checks retain historical scope |
| F20 | Attribution/age/version / All | Ready | Published metadata/source/date/evidence/build information and working source details; exact hosted v0.3.0 version/build/assets verified |
| C01 | Shared Indian package facts | Ready: released v0.4.0 | Automatic confirmed structured intake through lazy anonymous auth implemented; useful analysis survives save failure |
| C02 | Optional scanner account/private sync | v0.7.0 pushed and hosted-verified; 931 passed/5 skips and 18 hosted synthetic checks; independently published | v0.2.0 implemented: guests local, UID-specific private sync after optional login; 25 focused account tests pass; 135 tests, clean analyzer, hosted READY web deployment and source release published |

## Component releases

| Component/version | Meaningful goal | Evidence / state |
| --- | --- | --- |
| Backend v0.12.0 local | Bounded private AI proposals, ingredient/claim research search and separate real-product image descriptors | Local review complete; 1319 full backend tests and targeted runner checks pass; hosted identity in release review |
| Frontend v0.6.0+7 local | Barcode-first automatic reading, minimal-work photo results and reference Home/result layouts | Local review complete; 207 Flutter / 6 bridge tests, clean analysis, web build; hosted identity in release review |
| Backend v0.11.0 | One globally active Gemini/OpenAI extraction credential | Source 578a9af pushed/READY; 389 read-only hosted checks; authenticated generation separate; 1,303 historical tests/five skips |
| Frontend v0.5.0+6 | Sourced researched-product search/details | Source 00ae175 pushed/READY; 49 hosted checks and all 21 OCR hashes; 194 historical tests |
| Backend v0.10.0 | Immutable 243-observation research catalogue | Source e04ba54 pushed/READY; 389 hosted checks in its dated receipt |
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
packet gaps. No custom model/training is selected. Optional Gemini/OpenAI uses one
global credential with sticky replacement; its unverified facts stay distinct
from accepted observations and never establish current-package identity by themselves.

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
