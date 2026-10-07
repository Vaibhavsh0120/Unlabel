# Feature and integration tracker

Checkpoint: **7 October 2026**.

Backend **v0.6.0 Product Discovery** and frontend **v0.1.0+2 Connected Label Reader**
are independently pushed, hosted-verified and published. Frontend source commit
`1138c292296ae6c9309d73d430d267ec1a98fa80` passed production asset/browser checks.
Backend **v0.7.0 Private Account Sync** is implemented and ready for its separate
push: **931 tests passed, five emulator-only skips**, clean Ruff/Pyright and
**18 live synthetic checks** against a local API using real Firebase. Hosted
v0.7.0 verification/publication remain pending. Frontend **v0.2.0 Welcome, Home
and Optional Login** is implemented; full release/rendered validation is pending.
Guests keep personal data locally; optional password sign-in enables private
account profile/saved/history sync. Public package facts remain separate.

[Backend v0.7.0 review](BACKEND_V0_7_0_REVIEW.md) ·
[Frontend v0.1.0 proof](../research/FRONTEND_V0_1_0_PRODUCTION.json) ·
[Account/screen checklist](ACCOUNT_SYNC_SCREEN_PLAN.md).

The five original concept screens describe **20 feature groups**. The historical
v0.6.0 backend baseline has **9 ready, 2 partial, 3 planned and 6 client-owned**
groups; these count capabilities, not effort or percentage completion. C01/C02
are additional public-catalogue/private-account scope. v0.2.0 client comparison
and educational destinations use existing sourced contracts; broader coverage
and the remaining reference-style screens remain tracked below. Concept scores,
sample products and health verdicts are illustrative.

| ID | Feature / screen | Backend current | Frontend current / remaining |
| --- | --- | --- | --- |
| F01 | Barcode identity / Home, Scan | Ready: live and exact snapshot routes | Manual barcode entry/report integrated; camera barcode capture remains pending |
| F02 | Search / Home | Ready: released v0.6.0 bounded indexed discovery | Name/brand search, paging and explicit selection published in frontend v0.1.0; v0.2.0 navigation validation pending |
| F03 | Photos / Results, Compare | Ready: official attributed URL descriptors | Official attributed image/fallback used for actual records; cute generated artwork is decorative and cannot impersonate a scanned product |
| F04 | Nutrition and normalization / Results | Ready | Corrected rows, original basis/unit/preparation and report tables implemented; OCR intake pending |
| F05 | OFF Nutri-Score/NOVA / Home, Results | Ready: optional provider values | Dedicated grade/source display pending; no Unlabel 0–100 health score |
| F06 | Unified report/reasons / Results | Ready: released v0.5.0 | Current/historical sourced reports implemented; reference-style analysis screen is next UI work |
| F07 | Claim checks / Results, Ingredients | Partial: seven reviewed numeric types | Manual identified claims, correction and scoped verdicts implemented; broader claims remain insufficient |
| F08 | Ingredient explanations / Ingredients | Partial: three reviewed English/Hindi name/function entries | Expandable sourced functions implemented; full ingredient-screen layout and wider reviewed coverage pending |
| F09 | Allergens/traces / Scan, Ingredients | Ready: source availability and declarations | Confirmed declaration input and sourced report display implemented; no absence/safety inference |
| F10 | Personal suitability / Results | Planned | Dietary/allergy choices and neutral reasons pending; optional sync must preserve private ownership |
| F11 | Comparison / Compare | Planned | Implemented client selection and compatible-basis facts comparison; validation pending; complete reference-style redesign in v0.3.0; no universal healthier verdict |
| F12 | Sugar visualization / Results | Ready: released v0.5.0 | Approximate 4 g/cube total-sugar view with original basis implemented; added sugar stays distinct |
| F13 | Reviewed insights / Home | Planned | Implemented educational list/detail destinations with source/applicability; validation pending; no fabricated health advice |
| F14 | Front/back and gallery / Scan | Client-owned | Camera/gallery capture, correct-side pairing and permissions pending; current manual path works |
| F15 | OCR/live highlights / Scan | Client-owned; confirmed rows accepted | Local OCR/table interpretation, boxes and correction pending; real-device accuracy unverified |
| F16 | Saved products / Home | Client-owned, currently local | Bounded bookmarks/reopening/removal implemented; guests local, signed-in UID-specific private sync implemented with validation pending |
| F17 | History / Home | Client-owned, currently local | Bounded dated history/clearing implemented; guest/account isolation and optional private sync implemented with validation pending |
| F18 | Profile/preferences / Home | Client-owned private choices | Optional password sign-in/create/reset, display name/private sync, explicit conflict choices and sign out implemented; guest mode fully usable; validation pending |
| F19 | Responsive/light/dark / All | Client-owned | Responsive Material 3, light first-use default and local appearance persistence implemented; final visual review/native icon checks separate |
| F20 | Attribution/age/version / All | Ready | Metadata/source/date/evidence/build information and working source-detail destination implemented; rendered validation pending |
| C01 | Shared Indian package facts | Ready: released v0.4.0 | Automatic confirmed structured intake through lazy anonymous auth implemented; useful analysis survives save failure |
| C02 | Optional scanner account/private sync | v0.7.0 implemented: 931 passed/5 skips and 18 live Firebase checks; hosted/push pending | v0.2.0 implemented: guests local, UID-specific private sync after optional login; 25 focused account tests pass; full release validation pending |

## Component releases

| Component/version | Meaningful goal | Evidence / state |
| --- | --- | --- |
| Backend v0.2.3 | Rich India snapshot facts | Independently published historical source/build/hosted proof |
| Backend v0.3.0 | First reviewed numerical claim checks | Independently published; seven scoped numeric claim types |
| Backend v0.4.0 | Community Product Catalogue | Independently published; automatic observations, deduplication, qualified facts and private staging |
| Backend v0.5.0 | Useful Label Report | Independently published; reports, approximate sugar and three-entry glossary; [review](BACKEND_V0_5_0_REVIEW.md) |
| Backend v0.6.0 | Product Discovery | Published after 863 passed / 5 emulator skips and 23 hosted checks; [review](BACKEND_V0_6_0_REVIEW.md) |
| Frontend v0.1.0+2 | Connected Label Reader | Independently published exact commit 1138c292296ae6c9309d73d430d267ec1a98fa80; production assets/browser proof recorded |
| Backend v0.7.0 | Private Account Sync | Implemented and ready to push; 931 passed/5 skips plus 18 live synthetic Firebase checks; hosted/publication pending; [review](BACKEND_V0_7_0_REVIEW.md) |
| Frontend v0.2.0 | Welcome, Home and Optional Login | Implemented Welcome/Home/account/5-tab navigation and useful destinations; full test/render/build/push/hosted gates pending |
| Frontend v0.3.0 | Complete Scan and Food Screens | Accepted following frontend release; redesign Scan, Compare, Results, Ingredient and supporting destinations one screen at a time |

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
