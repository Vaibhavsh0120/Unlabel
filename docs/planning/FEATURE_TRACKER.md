# Feature and integration tracker

Checkpoint: **7 October 2026**. Backend **v0.6.0 Product Discovery** is reviewed,
pushed, hosted-verified and published at `c5fa883214b1448332f7c2465f8a063430279459`.
Its full suite passed **863 tests**, with **5 emulator-only skips**, and **23 hosted
HTTP checks** passed. Frontend **0.1.0+2 Connected Label Reader** is implemented;
its final rendered/release checks and separate publication remain in progress.
[Backend review](BACKEND_V0_6_0_REVIEW.md) · [Hosted proof](../research/BACKEND_V0_6_0_PRODUCTION.json)
· [Connected release plan](CONNECTED_RELEASE_PLAN.md).

The original five concept screens describe **20 feature groups**. Backend scope
has **9 ready, 2 partial and 3 planned groups**, plus **6 primarily client-owned
groups**. These count capabilities, not effort or percentage completion. C01
community coverage and C02 optional account sync are supporting scope outside that
baseline. Example scores, products and health verdicts in the reference images
are illustrative; the app must show actual sourced results or honest empty states.

| ID | Feature / screen | Backend current | Frontend current / remaining |
| --- | --- | --- | --- |
| F01 | Barcode identity / Home, Scan | Ready: live and exact snapshot routes | Manual barcode entry/report integrated; camera barcode capture remains pending |
| F02 | Search / Home | Ready: released v0.6.0 bounded indexed discovery | Name/brand search, paging and explicit candidate selection implemented; final rendered/release gate pending |
| F03 | Photos / Results, Compare | Ready: official attributed URL descriptors | Product image/fallback rendering remains pending; generated illustration must not impersonate a real product |
| F04 | Nutrition and normalization / Results | Ready | Corrected rows, original basis/unit/preparation and report tables implemented; OCR intake pending |
| F05 | OFF Nutri-Score/NOVA / Home, Results | Ready: optional provider values | Dedicated grade/source display pending; no Unlabel 0–100 health score |
| F06 | Unified report/reasons / Results | Ready: released v0.5.0 | Current/historical sourced reports implemented; reference-style analysis screen is next UI work |
| F07 | Claim checks / Results, Ingredients | Partial: seven reviewed numeric types | Manual identified claims, correction and scoped verdicts implemented; broader claims remain insufficient |
| F08 | Ingredient explanations / Ingredients | Partial: three reviewed English/Hindi name/function entries | Expandable sourced functions implemented; full ingredient-screen layout and wider reviewed coverage pending |
| F09 | Allergens/traces / Scan, Ingredients | Ready: source availability and declarations | Confirmed declaration input and sourced report display implemented; no absence/safety inference |
| F10 | Personal suitability / Results | Planned | Dietary/allergy choices and neutral reasons pending; optional sync must preserve private ownership |
| F11 | Comparison / Compare | Planned | Next accepted connected screen: selection, compatible table basis, unknown/conflict handling; no universal healthier verdict |
| F12 | Sugar visualization / Results | Ready: released v0.5.0 | Approximate 4 g/cube total-sugar view with original basis implemented; added sugar stays distinct |
| F13 | Reviewed insights / Home | Planned | Next accepted insight list/detail destination with reviewed educational text, source and applicability |
| F14 | Front/back and gallery / Scan | Client-owned | Camera/gallery capture, correct-side pairing and permissions pending; current manual path works |
| F15 | OCR/live highlights / Scan | Client-owned; confirmed rows accepted | Local OCR/table interpretation, boxes and correction pending; real-device accuracy unverified |
| F16 | Saved products / Home | Client-owned, currently local | Bounded local bookmarks, reopening/removal and list clearing implemented; optional account sync next |
| F17 | History / Home | Client-owned, currently local | Bounded local dated history and clearing implemented; optional account sync next |
| F18 | Profile/preferences / Home | Client-owned private choices | Local appearance implemented; optional login/profile/private sync next; guest mode remains fully usable |
| F19 | Responsive/light/dark / All | Client-owned | Responsive Material 3, light first-use default and local appearance persistence implemented; final visual review/native icon checks separate |
| F20 | Attribution/age/version / All | Ready | Metadata handshake, source/date/evidence and build information implemented; reference-style source-detail destination next |
| C01 | Shared Indian package facts | Ready: released v0.4.0 | Automatic confirmed structured intake through lazy anonymous auth implemented; useful analysis survives save failure |
| C02 | Optional scanner account/private sync | Next accepted backend v0.7.0 scope | Next frontend v0.2.0 scope; guests retain personal data locally; signed-in personal records stay private and separate from public facts |

## Component releases

| Component/version | Meaningful goal | Evidence / state |
| --- | --- | --- |
| Backend v0.2.3 | Rich India snapshot facts | Independently published historical source/build/hosted proof |
| Backend v0.3.0 | First reviewed numerical claim checks | Independently published; seven scoped numeric claim types |
| Backend v0.4.0 | Community Product Catalogue | Independently published; automatic observations, deduplication, qualified facts and private staging |
| Backend v0.5.0 | Useful Label Report | Independently published; reports, approximate sugar and three-entry glossary; [review](BACKEND_V0_5_0_REVIEW.md) |
| Backend v0.6.0 | Product Discovery | Published after 863 passed / 5 emulator skips and 23 hosted checks; [review](BACKEND_V0_6_0_REVIEW.md) |
| Frontend v0.1.0+2 | Connected Label Reader | Implemented manual lookup/report/form/local libraries; 42-test suite and final rendered/release gates tracked separately |
| Backend v0.7.0 | Private Account Sync | Accepted next scope; implementation/evidence pending; [plan](ACCOUNT_SYNC_SCREEN_PLAN.md) |
| Frontend v0.2.0 | Welcome, Home and Optional Login | Accepted next scope; first-launch welcome, Home, optional login/private sync and Home/Scan/Compare/Saved/Profile bar; each action works |
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
