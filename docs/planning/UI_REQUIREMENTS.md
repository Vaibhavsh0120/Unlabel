# Unlabel UI and interaction requirements

The **0.1.0+2 Connected Label Reader** is implemented in the existing Flutter
application. Its green/white/mint direction follows the owner's five
[reference images](../../design/references/README.md); the displayed example
scores, product facts and claims are illustrative. Local analysis/tests passed.
Rendered browser, push/publication and native-device checks remain separate in
the [connected release plan](CONNECTED_RELEASE_PLAN.md).

## Current useful flow

| Screen | Working behavior |
| --- | --- |
| Home | One primary product lookup, barcode/name entry paths, current-label entry, real recent history and saved products |
| Product lookup | Manual barcode or submitted name/brand query; explicit candidates show barcode/brand/quantity; bounded Show more; empty/broad/unavailable states stay distinct |
| Current-label form | Enter printed identity, table rows/basis/preparation, declarations and claims; confirm current facts and pairing; keep blanks unknown and draft retry identity stable |
| Report | Show current versus historical evidence, nutrient units/bases, approximate total-sugar cubes, scoped claim outcomes, missing/conflicting facts and source references |
| Ingredient insights | Original matched terms and three reviewed English/Hindi technological functions; unknown terms do not get invented explanations |
| Saved/history | Device-local snapshots, explicit bookmarks/removal, independent history clearing and confirmed recovery of corrupt lists |
| Appearance/About | Light (default)/Dark/System selection, build information and bundled icon attribution |

Confirmed public package facts are saved automatically using the single anonymous
scanner role. This is separate from an explicit local bookmark. Authentication,
quota or storage failures do not discard the useful analysis. The UI never
presents historical selection as confirmation of the current package.

## Layout and accessibility

Use bounded content widths and natural-height cards. At narrow widths and
enlarged text, actions and nutrient content reflow instead of shrinking. App bars,
safe areas and vertical scrolling keep the same reading order in landscape.
Phone, tablet and desktop share real Material 3 controls and semantic colors.
Solar feature icons are bundled locally; ordinary navigation/form controls use
Material icons consistently. System fonts avoid remote font requests.

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
