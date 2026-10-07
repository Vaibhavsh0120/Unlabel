# Reference screens and the next releases

Accepted scope: **8 October 2026**. Work directly on `main` and preserve published
backend v0.7.0/frontend v0.2.0 history. This plan implements the user's requested
screens now; later releases remain plans until their own checks close.

The latest correction takes precedence: **do not change the navbar**. Preserve
Home / Scan / Compare / Saved, their order and design. The user's clarification
authorizes only a smaller bottom gap and a held active indicator that follows
the finger and commits the chosen screen on release.
Profile remains its existing header shortcut. Do not add a settings button to
the top right of Profile. The screenshot is the body/layout reference, while
actual account identity, stored counts and supported settings supply its content.

## Release boundaries

| Component/version | Delivery | Evidence needed |
| --- | --- | --- |
| Frontend v0.3.0+4 | Reference Welcome on phone/PC, botanical startup screen, reference Profile with working account/device settings, immediate Home search keyboard, opaque header, a single Scan Label entry with private capture/gallery and editable review | Flutter analysis/tests/web build; light phone screenshot comparison; desktop layouts; camera/gallery/review/report flow; native keyboard/camera proof separately |
| Backend v0.8.0 | Sourced Nutrient Comparison, with strict selected table basis/preparation, safe known unit conversion and original source references; scan validation additions only for measured contract gaps | Existing v0.7.0 already accepts corrected confirmed labels; no new photo/OCR upload endpoint; synthetic comparison tests/contracts and separate hosted proof |
| Frontend v0.4.0+5 | Remaining reference report/ingredient screens, remaining native OCR acceptance, automatic barcode camera detection, source-aware comparison details and persistence/notification design | Reviewed local extraction, editable candidate fields, explicit confirmation, bounded errors/cancellation and real camera/browser/device checks |
| Backend v0.9.0 | Expand reviewed bilingual ingredient-function coverage and evidence references with explicit unavailable/conflict outcomes | Reviewed licensed source entries, immutable provenance, bounds and contract examples; no health/allergy/compliance verdict or invented score |

Versions remain independent. A UI change does not require a new API or backend
version. Backend v0.7.0 provides `/v1/reports/check` for confirmed manual and
corrected OCR inputs; source capture alone does not mean automatic recognition.
Local OCR is now implemented behind post-capture review and has read a synthetic label in the compiled browser. Nutrition extraction, live boxes and physical-device accuracy remain unverified.
Anything without passing implementation/acceptance evidence remains planned.

## Implementation order and ownership

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

After screen verification, address the user's added performance scope: skeleton
feedback for pending search, measure startup and search request patterns, reduce
unnecessary work, and add bounded caches without making dated source facts appear
current. Preserve foreground camera/animation lifecycle and reduced-motion support.

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
Push, exact hosted verification and independent source release receipts follow.
