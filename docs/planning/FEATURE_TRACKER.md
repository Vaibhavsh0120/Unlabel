# Feature tracker

Active versions come from [frontend pubspec](../../frontend/pubspec.yaml) and [backend pyproject](../../backend/pyproject.toml). Current scope: [reference auth and provider controls](FRONTEND_V0_9_0_REVIEW.md) and [private account deletion](BACKEND_V0_13_0_REVIEW.md), authorized for completion and push. Earlier reviews retain their own dated evidence.
Current behavior and remaining gates are listed below. The user later authorized auth/profile changes and independent version bumps. [Audit](MAINTENANCE_2026_10_12.md) ·
[Source release ledger](CONTROLLED_RELEASES.md) · [Remaining work](FRONTEND_BACKEND_NEXT_VERSIONS.md).
Versioned reviews/hosted receipts keep their original source dates and test totals.

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
| F13 | Reviewed insights / Home | Implemented locally in v0.7.0 | 20 sourced articles and unique artwork, stable daily four shared with Home, full topic/all browsing, source-linked readers, local bookmarks and recovery; hosted verification pending; no product-safety verdict |
| F14 | Front/back and gallery / Scan | Optional authenticated photo reading implemented in v0.11; local v0.12 stages only private structured proposals | Local v0.6 automatically reads front/back/barcode capture/gallery photos with transfer consent and local fallback; no mandatory typing. Measured physical-device accuracy remains open |
| F15 | OCR/live highlights / Scan | Bounded machine facts/normalized regions; confirmed rows use separate admission | Local v0.6 paints actual post-capture regions and decoder anchors, with View results action; continuous live highlights and real-device accuracy remain future |
| F16 | Saved products / Home | Client-owned; private sync published in v0.7.0 | Published bounded bookmarks/reopening/removal; guests local, signed-in UID-specific private sync; hosted v0.3.0 public report save and Saved count verified |
| F17 | History / Home | Client-owned guest local; optional private sync published | Published bounded dated history/clearing, guest/account isolation and optional private sync; hosted v0.3.0 Profile Scans count verified |
| F18 | Profile/preferences / Home | Verified Google/password ownership; private library contract unchanged | Four app auth states, same-UID provider linking, private thumbnails and optional gender/default avatars; Firebase's supported hosted page completes reset and returns to fixed app sign-in. Reference login/signup use animated layers, fixed desktop cards and a moving mobile card; provider management and explicit private account deletion are included. Verification belongs to the current review |
| F19 | Responsive/light/dark / All | Client-owned | v0.6 adds reference sidebar/Home and responsive results; preceding reviews retain their scope. v0.7 Insights has reviewed 390/1440/1728 light/dark renders and 24 feed text/theme/width configurations without layout exceptions; native proof remains separate |
| F20 | Attribution/age/version / All | Ready | Published metadata/source/date/evidence/build information and working source details; exact hosted v0.3.0 version/build/assets verified |
| C01 | Shared Indian package facts | Ready: released v0.4.0 | Automatic confirmed structured intake through lazy anonymous auth implemented; useful analysis survives save failure |
| C02 | Optional scanner account/private sync | v0.13.0 adds owner-only deletion; private snapshots remain backend-only | Google/password linking preserves UID/library, collisions cannot merge accounts; thumbnail/gender uses a separate owner-only document. Current source passed CI and hosted contract checks; native/device evidence stays in the release ledger; original v0.7.0/v0.2.0 receipts remain historical |

## Component releases

| Component/version | Meaningful goal | Evidence / state |
| --- | --- | --- |
| Frontend v0.9.0+13 | Responsive reference auth, themed shared artwork, provider management and account deletion | [Current review](FRONTEND_V0_9_0_REVIEW.md); source push authorized, hosted/native gates separate |
| Backend v0.13.0 | Fresh-auth private account cleanup and idempotent deletion | [Current review](BACKEND_V0_13_0_REVIEW.md); additive DELETE contract |
| Frontend v0.8.0+12 | Reference auth, linked sign-in, private profile media and UI repairs | [Preceding source review](FRONTEND_V0_8_0_REVIEW.md); its hosted/native gates remain separate |
| Backend v0.12.1 | Verified Google scanner/private-library provider compatibility | [Current review](BACKEND_V0_12_1_REVIEW.md); 70 focused checks/Ruff passed, final hosted/source gates pending |
| Backend v0.12.0 | Bounded private AI proposals, ingredient/claim research search and separate real-product image descriptors | Pushed/READY; dated 1319 tests and 389 hosted checks in release review; current maintenance separate |
| Frontend v0.6.0+7 | Barcode-first automatic reading, minimal-work photo results and reference Home/result layouts | Pushed/READY; dated 207 Flutter / 6 bridge tests, analysis/web build and hosted receipt in review |
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
| Backend v0.8.0 | Sourced Nutrient Comparison | Pushed exact source `1a2fd25`; READY hosted deployment and 25 checks; source release published during the 12 October maintenance |
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
app account or dashboard. Package photos/raw OCR are excluded from public observations. The later auth
scope permits one bounded private profile thumbnail and optional gender in the
existing database, with no new role, paid service or Google gender inference.
[Account/profile contract](../architecture/ACCOUNT_PROFILE.md).

Related: [Master plan](MASTER_PLAN.md), [workflows](FEATURES.md),
[Indian food coverage](../research/INDIAN_FOOD_COVERAGE.md),
[community catalogue](../architecture/COMMUNITY_CATALOGUE.md).
