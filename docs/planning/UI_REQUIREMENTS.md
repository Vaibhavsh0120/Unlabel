# Unlabel UI and interaction requirements

Frontend **v0.1.0+2 Connected Label Reader** is independently published.
Frontend **v0.2.0 Welcome, Home and Optional Login** is implemented with full
render/test/build/push/hosted gates pending. The supplied light/dark
[references](../../design/references/README.md) set the forest/mint and charcoal
direction; scores, sample foods and verdicts remain illustrative.
First-use appearance is light. Cute generated artwork decorates the app without
impersonating actual package images. Native camera/icon switching remain separate.
[Accepted screen/version checklist](ACCOUNT_SYNC_SCREEN_PLAN.md).

## Current useful flow

| Screen | Working behavior |
| --- | --- |
| Welcome | Cute first-launch screen with Continue and no forced login; local completion sends returning users straight to Home |
| Home | Reference-style light/dark cards, real recent records/empty states, Start Scan, barcode/search and working educational/source destinations |
| Navigation | Five bottom tabs: Home, Scan, Compare, Saved, Profile; Scan retains useful manual/search paths pending camera/OCR |
| Profile | Optional password sign-in/create/reset, display name, private sync/status/conflict choices, clear/sign out; guests continue freely |
| Compare | Select actual saved/history/lookup reports, compatible-basis numeric rows and unknown/incompatible states; no universal healthier winner |
| Product lookup | Manual barcode or submitted name/brand query; explicit candidates show barcode/brand/quantity; bounded Show more; empty/broad/unavailable states stay distinct |
| Current-label form | Enter printed identity, table rows/basis/preparation, declarations and claims; confirm current facts and pairing; keep blanks unknown and draft retry identity stable |
| Report | Show current versus historical evidence, nutrient units/bases, approximate total-sugar cubes, scoped claim outcomes, missing/conflicting facts and source references |
| Ingredient insights | Original matched terms and three reviewed English/Hindi technological functions; unknown terms do not get invented explanations |
| Saved/history | Guest-local or isolated account-local snapshots; explicit bookmarks/removal/clearing; optional private cloud sync after login with explicit replacement choices |
| Appearance/About | Light (default)/Dark/System selection, build information and bundled icon attribution |

Confirmed public package facts save automatically using the single scanner role
with anonymous guest or password session authentication. This is separate from an explicit local bookmark. Authentication,
quota or storage failures do not discard the useful analysis. The UI never
presents historical selection as confirmation of the current package.

## Layout and accessibility

Use bounded content widths and natural-height cards. At narrow widths and
enlarged text, actions and nutrient content reflow instead of shrinking. App bars,
safe areas and vertical scrolling keep the same reading order in landscape.
Phone, tablet and desktop share real Material 3 controls and semantic colors.
Solar feature icons are bundled locally; ordinary navigation/form controls use
Material icons consistently. Bundled Nunito and local icons avoid remote font/icon requests.

Light is the initial appearance; the saved explicit choice persists locally. Light and dark have separate readable surface,
foreground, action and selection roles. Main action icons use the matching
on-primary foreground rather than a hardcoded white glyph. Findings have text
states; color never carries an unknown/conflict result alone.

Inputs have visible labels and Enter submits lookup. Keyboard focus and native
button/dialog semantics remain intact. Progress reflects active requests, without
invented percentages. Screen-reader announcements identify loading/results.
Touch controls retain useful hit areas and separation. Section titles expose
heading semantics. Two-times text and small landscape sizes stay scrollable.

Widget checks cover 320/390 mobile, 768 tablet, 1440/1728 desktop and landscape
sizes in light/dark, enlarged text, request staleness, source boundaries and local
save failures. These checks do not prove real Safari/Android/iOS behavior.
Better Design comprehension checks are text-only; rendered spacing/hierarchy
requires actual browser evidence.

## Facts and recovery

- A name/brand result is a candidate, not an identity confirmation. No candidate
  is selected automatically. Stale requests cannot replace a newer lookup.
- Dated catalogue information may differ from the current package. Current claims
  require enough independently confirmed label facts and applicable context.
- Missing nutrition is unknown, never zero. Missing allergen declarations never
  produce an allergy-safe badge. Source disagreements are not silently resolved.
- Sugar cubes use the stated approximate 4 g/cube conversion and printed basis.
  No serving size or added-sugar quantity is inferred.
- Reports retain per-field evidence/references and source dates where supplied.
  Local snapshots do not refresh their findings simply because they are reopened.
- Save/history failures remain visible while the report stays open. A corrupt
  local list can be cleared with confirmation without deleting the other list.
- The manual form retains input after recoverable failure and asks before
  discarding an edited draft. Retries do not silently create a different write.

## Accepted next screen and account work

The [v0.7.0/v0.2.0 plan](ACCOUNT_SYNC_SCREEN_PLAN.md) includes complete reference-style
light/dark screen journeys, one screen at a time, with every visible action
working. A cute first-launch Welcome offers Continue without forced login; its
local completion flag sends returning users straight to Home. Optional login
adds private profile/saved/history sync after successful authentication. Guests
keep existing local workflows; public package observations remain separate.
Generated decorative illustrations must not impersonate actual scanned products.

## Future capture and wider product features

Camera/barcode scanning, gallery/back/front OCR, frame overlays, comparison,
local dietary/allergy suitability and today's insight feed are not in 0.1.0.
Future capture asks for permissions only when needed, keeps photos/raw OCR local,
and requires correction/pairing before confirmed facts enter the report. Browser
camera tracks must stop on exit; rotation/crop coordinates need device evidence.
Local OCR comes first. Gemini and custom training remain unselected until a
measured benchmark establishes a useful bounded fallback.

Future comparison aligns compatible units/bases and exposes missing values; it
does not produce a universal health ranking. Broader English/Hindi UI translation
and Devanagari OCR need separate acceptance. First-visit offline website use and
signed iOS distribution are not promised by a web build.

The stack remains free/no card/no linked billing. Keep the existing Flutter
framework, single scanner identity and Firebase Spark boundaries.

[Feature tracker](FEATURE_TRACKER.md) · [Data flow](../architecture/DATA_FLOW.md) ·
[Current backend review](BACKEND_V0_6_0_REVIEW.md)
