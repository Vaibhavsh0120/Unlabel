# Reference screens and the next releases

Current frontend correction: **v0.6.2+9** displays selected-only Profile summaries,
first two labels and `+N`, preserving complete separate editors and saved data.
[Review/deployment status](FRONTEND_V0_6_2_REVIEW.md).

Preceding published checkpoint, 8 October 2026: **frontend v0.6.1+8 / backend v0.12.0**
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
image, and redesigns Profile preferences/allergens. Its local verification and
independent deployment gate are recorded in
[the correction review](FRONTEND_V0_6_1_REVIEW.md).

The preceding frontend v0.5.0+6 and backend v0.11.0 sources are already pushed
with READY deployments and 49 frontend/389 backend read-only hosted checks;
authenticated AI generation and physical-device proof remain separate.
The release/history sections below describe their original dated scope.

Verified checkpoint (8 October 2026): backend **v0.9.0** and frontend
**v0.4.0+5** were independently reviewed, documented and pushed on `main`.
Their exact implementation deployments are READY with **26 backend / 49 frontend
hosted checks**, including all 21 OCR asset hashes. The local suites passed
**1058 backend tests (five provider skips) / 181 Flutter tests**; static checks,
release web build and synthetic browser workflows passed. Physical-device gates
and separate GitHub source-release publication are not established by this proof.
[Backend review](BACKEND_V0_9_0_REVIEW.md) ·
[Frontend review](FRONTEND_V0_4_0_REVIEW.md).

Accepted scope: **8 October 2026**. Work directly on `main` and preserve published
backend v0.7.0/frontend v0.2.0 history. Frontend v0.3.0 is now published and
hosted-verified. Backend v0.8.0 was pushed from `1a2fd25b3f781ac916ca6fc1179883f81d5f40a8` and hosted-verified with 25 checks at READY deployment `dpl_651iY8R8Dj6wNEdVC71Kw3ZW4oig`; its source-release publication is not established by that receipt.
Current implementation slices are **backend v0.9.0 Reviewed Ingredient Functions** and **frontend v0.4.0+5 Sourced Comparison and Ingredient Detail**. Each receives independent tests, review, documentation, push and exact-source hosted checks. See [the implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md).

The latest correction takes precedence: **do not change the navbar**. Preserve
Home / Scan / Compare / Saved, their order and design. The user's clarification
authorizes only a smaller bottom gap and a held active indicator that follows
the finger and commits the chosen screen on release.
Profile remains its existing header shortcut. Do not add a settings button to
the top right of Profile. The screenshot is the body/layout reference, while
actual account identity, stored counts and supported settings supply its content.

## Release boundaries

| Component/version | Delivery | Evidence / state |
| --- | --- | --- |
| Frontend v0.3.0+4 | Reference Welcome on phone/PC, botanical startup screen, reference Profile with working account/device settings, immediate Home search keyboard, opaque header, a single Scan Label entry with private capture/gallery and editable review | Published: 168 tests, clean analysis/build, 390/1440/1728px captures, READY deployment and 49 hosted checks and all 21 OCR hashes; physical keyboard/camera proof separate |
| Backend v0.8.0 | Sourced Nutrient Comparison, with strict selected table basis/preparation, safe known unit conversion and original source references | Pushed/hosted-verified with 25 checks; source-release publication not established. Existing v0.7.0 already accepts corrected labels; no photo/raw-OCR upload endpoint |
| Frontend v0.4.0+5 | Exact-source server comparison, original table selection, unknown/conflict states and matched-ingredient bilingual detail; native OCR/automatic barcode/notifications remain later gates | Bounded current-session confirmation, no confirmation reconstruction after restore, stale-response/privacy tests, responsive browser checks; physical-device proof separate |
| Backend v0.9.0 | Expand to six reviewed bilingual ingredient-function entries with exact source/alias/INS validation and immutable evidence; preserve unavailable/conflict outcomes | Reviewed licensed source entries, immutable provenance, bounds and contract examples; no health/allergy/compliance verdict or invented score |

Versions remain independent. A UI change does not require a new API or backend
version. Backend v0.7.0 provides `/v1/reports/check` for confirmed manual and
corrected OCR inputs; source capture alone does not mean automatic recognition.
Local OCR is now implemented behind post-capture review and has read a synthetic label in the compiled browser. Nutrition extraction, live boxes and physical-device accuracy remain unverified.
Anything without passing implementation/acceptance evidence remains planned.

## Executed frontend order and remaining ownership

The frontend steps below remain the completed published v0.3.0 history.
Frontend v0.4.0/backend v0.9.0 are also implemented, independently pushed and
hosted-verified according to the
[implementation plan](FRONTEND_V0_4_0_BACKEND_V0_9_0_PLAN.md). The v0.8.0
source and hosted receipt remain historical proof, with publication tracked separately.

1. Define scope and inspect current capture/report/account contracts.
2. Implement Welcome/loading artwork and responsive composition. Keep live text
   and real buttons separate from generated decorative raster illustrations.
   The branded loading screen is app-only; the website has no branded startup
   shell or added loading delay, according to the user's later clarification.
3. Implement Profile identity, real library counts, local preferences, dark mode,
   privacy/help and existing sign-in/sync/conflict/logout actions. Notifications
   cannot imply a push service that does not exist. No extra settings shortcut.
4. Keep Home search available and focus the existing mounted search input from
   the tap. Remove the redundant Find a product route; use Scan Label for capture
   and its barcode/manual fallback. Remove obsolete source/tests after replacement.
   Keep Scan Label's existing UI unchanged. Recognition is integrated into the
   captured-photo review behind it, according to the user's later correction.
5. Set opaque, elevation-free app headers and status-bar surfaces. Preserve the
   navbar design/tabs/order with only the requested gap and drag refinements.
6. Validate the edited screens in light mode at mobile dimensions, compare with
   the supplied references and fix visible differences. Validate desktop Welcome
   and Profile, dark mode and enlarged-text layouts as separate checks.
7. Update release review/tracker/design documentation with exact local checks and
   remaining browser/native/hosted gates. Publish components independently only
   after their applicable verification; no APK/IPA build for backend-only work.

After screen verification, the added performance work delivered search skeletons,
bounded public-read caches/request sharing, limited thumbnail work and reduced
image decoding. Request/lifecycle regressions cover the changes; no device
frame-rate or hosted latency benchmark is claimed. Dated facts retain their dates,
and foreground camera/animation lifecycle/reduced-motion boundaries remain.

## Controls and visual fidelity

Use the white/forest/mint reference compositions, card hierarchy, botanical
package hero, anonymous illustrated avatar and serif loading wordmark. Do not
draw fake status bars, OS home indicators or desktop window buttons inside the app.
Real device/browser chrome owns those areas. Desktop layouts gain horizontal
space through deliberate columns and constrained reading width; mobile stacks
retain the reference hierarchy and scroll when height/text size requires it.

Get started completes device-local Welcome and enters the guest workflow.
I already have an account opens the existing password sign-in dialog. Profile
edits the actual display name; private cloud/device differences retain explicit
choices. Dietary/allergen preferences stay device-local and do not establish
product suitability or allergy safety. Counts use real records; unavailable
statistics stay unavailable. Decorative art never supplies product evidence.

Flutter canvas screenshots establish visual evidence. DOM inspection can measure
the web host/pre-Flutter shell but cannot provide individual Flutter card spacing;
record that boundary instead of claiming nonexistent DOM measurements.

Keep all services free with no card/billing requirement, Gemini disabled and
photos/raw OCR outside private/public sync. No new account roles or dashboards.

## Verified implementation checkpoint

The frontend has 168 passing Flutter tests, clean analysis and a successful
release web build. Four web-bridge tests, 21 pinned OCR asset hashes and 42
existing platform/icon hashes pass. Android Kotlin bridge compilation passed;
iOS Vision still requires macOS/device checks. Photos/raw OCR stay in memory and
off the backend. Barcode fallback, review correction and report entry work with
the existing backend. The old Find a product page and unused Scan search callback
are removed. Profile has no top-right gear or bottom guest continuation action.
Notifications are visibly unavailable; comparison counts are unknown rather
than invented. Preferences/theme/privacy/help/account actions are implemented.

After screens, performance changes bound public search/report caching, coalesce
requests, cap background thumbnail work and stop discarded queues/animations.
Tests cover reopening pending search and query changes without obsolete reloads.
These are request/lifecycle proofs, not device frame-rate or OCR-accuracy claims.
The frontend is independently published from exact implementation
`3f9a8172c284c74e25c0c83a270c1e8cabc26bdb`, READY deployment
`dpl_7oPH6ZU42BgvNURT7rWPFsPVu3c8`, with 49 hosted checks and all 21 OCR hashes.
Hosted Welcome enters Home; Search focuses its actual input and returns ten of
57 matches; a public report saves locally and Profile reflects Scans 1 / Saved 1
with comparison count still unknown. Later docs-only closure commits retain
that implementation identity. [Source release](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0) ·
[Production receipt](../research/FRONTEND_V0_3_0_PRODUCTION.json).
