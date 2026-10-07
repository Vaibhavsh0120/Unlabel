# Unlabel UI and interaction requirements

Status: requirements for later feature UI. A minimal responsive Flutter starter is foundation work; the four scanning features and a custom design system/palette are not implemented. Product name: **Unlabel**; tagline: **Label Padhega India**. One Flutter app directly in `frontend/` targets Android/iOS/web; platform capability differences must be visible.

## Device and layout coverage

The five [supplied references](../../design/references/README.md) are tracked for teammate recovery. Their values are illustrative; the color theme remains undecided.

| Surface | Required coverage | Layout intent |
| --- | --- | --- |
| iPhone | Website and iOS app, portrait/landscape | Readable single flow; safe-area-aware controls; short landscape height must remain usable |
| iPad | Website and iOS app, portrait/landscape; resized browser windows | Add preview/review or list/detail panes when content fits, retaining the same reading order |
| MacBook | Website, keyboard/mouse/trackpad and resized windows | Constrain long text width; use extra space for evidence/details instead of enlarging every control |
| Android | App and mobile website; portrait/landscape | Equivalent essential flow, reachable touch controls, system inset/permission handling |

Breakpoints follow content needs rather than one hardcoded size per device. Containers can scale fluidly; text and controls remain legible instead of shrinking a desktop view. Narrow results stack before adding columns. No accidental page-wide horizontal scroll; comparison tables may use a clearly indicated, keyboard-operable local scroll area.

Use Flutter logical sizing, bounded content widths, layout constraints, flexible spacing, and adequate hit areas. The website must handle mobile browser bars, safe areas, and the on-screen keyboard; viewport height alone cannot guarantee the correction action stays visible. Rotation/resizing must preserve the draft and remap overlays correctly.

## Appearance without choosing colors

- Support **system**, **light**, and **dark** appearance. System is the initial default; an explicit override persists locally and can return to system.
- Define semantic roles before a palette: page/surface, primary/secondary text, border, main action and its foreground, selected state, focus, information, warning, error, supported/contradicted/unknown findings, and chart series.
- Keep action, selection, status, and chart roles independently adjustable, even if some future values match. Shared Flutter theme extensions map those roles consistently across Android/iOS/web.
- Check foreground/background pairs in both modes; do not build dark mode by merely inverting images or dimming text. Native/browser controls should match the selected scheme where supported.
- No final brand palette or font is selected in the foundation. The starter may use framework defaults; selecting a product design system and palette is a separate later design decision. No generated design-system installation is needed now.

## Essential screen flow

1. **Start/lookup:** lead with barcode scan/manual entry for an online Open Food Facts product report. No login/long onboarding; preferences are optional. Do not force front/back OCR when provider facts suffice for a basic report.
2. **Permission/capability:** request camera access when selected and explain whether it reads a barcode or label. Manual barcode entry and targeted image/manual correction are alternatives. Stop browser camera tracks when leaving; explain unsupported live overlays.
3. **Product review/optional capture:** verify identity, source, freshness, and important facts. Request front claims or missing/conflicting panels only when needed. Keep provider values and current-package evidence/corrections distinct; retain edits through rotation/retry/back.
4. **Processing:** show product lookup, source review, and online backend checks with bounded retry/cancel. No fabricated percentage/infinite spinner. Gemini failure falls back to templates. Offline state offers saved reports/preferences/available glossary, not fresh analysis.
5. **Result:** lead with identity/source dates/completeness; separate **Open Food Facts insights**, **Unlabel checks using reviewed FSSAI criteria**, and local suitability reasons. Label source/algorithm for provider scores; cite each backend finding. Missing/unsupported evidence stays insufficient information, never a full-compliance badge.
6. **Ingredient detail:** original term, common name/purpose, qualified concerns, unknowns, and language/source controls. Hindi translation must preserve qualifications and allow longer text.
7. **Preferences/history/comparison:** preferences remain local and saving is explicit. Offline reports retain dates and their earlier suitability/profile snapshot; preference edits flag stale reasons rather than recomputing new findings. Separate stores, units/missing values, and deliberate delete/undo are clear.

Navigation provides a predictable path between barcode lookup, optional capture/correction, result, and ingredient detail. URLs/back preserve context without allergies/label text in URLs. Disclosures stay beside findings. Proposed start copy: **Look up a food product**, "Scan its barcode or enter the number to check available product information," with **Scan barcode** and **Enter barcode** actions. Optional capture explains the specific missing/conflicting fact it resolves.

## Accessibility and understandable feedback

- Essential controls have visible text/outcome labels and accessible names. Camera-only input, icon-only meaning, hover-only actions, and undocumented gestures cannot be the sole route.
- Touch targets aim for at least 44 logical/CSS pixels with separation; website controls support keyboard, mouse, trackpad, and touch. Focus is visible and follows reading order; dialogs restore focus.
- Text meets at least 4.5:1 contrast and meaningful controls/focus 3:1 in both modes. Support text enlargement, browser zoom/reflow, screen readers, and reduced motion; animation never delays a safety-relevant finding.
- Findings combine wording/icons with any future colors. Nutrient charts show numeric values, units/basis, and a readable text/table alternative; chart colors alone do not encode meaning.
- Correction errors sit beside the field, describe the fix, and are announced accessibly. On submit, focus the first invalid field. Distinguish no text found, missing evidence, network failure, unavailable OCR assets, and empty history.
- Missing evidence must read **unknown/incomplete**, not safe or zero. "Not detected" is not "allergen-free." Proposed result copy: **Some label information is missing**, "Review the package and correct unclear text. Missing allergen information cannot confirm that this food is safe," with **Correct label** and **View evidence**. No diagnosis/treatment/safety guarantee.

## Later verification and free-scope boundary

Validate languages/modes across widths, iPhone/iPad portrait/landscape, MacBook Safari, and Android. Include enlarged text/keyboard, denied camera/manual barcode entry, missing provider records, source conflicts, optional OCR, insufficient evidence, and saved-report dates. Offline tests prove no new provider/analysis/Gemini calls and no silent refresh of old suitability. Optional cached web history and first-visit unavailable states are distinct.

Better Design responsive, mobile-web, accessibility, semantic-role, and error guidance informs this plan. Comprehension checks are text-only; they prove neither rendered quality nor native behavior. Starter rendering checks are separate from future complete-feature reviews; DOM spacing measurement applies where a measurable DOM exists.

The foundation must retain the user's **zero cost/no card** constraint. The requested Flutter starter and manual APK/unsigned-IPA workflow do not authorize paid design kits, remote subscriptions, hosted user databases, or app-store purchases. iOS signing and installability limits are documented in the release plan. The Flutter **0.0.0+1** starter website and FastAPI API are deployed in separate Vercel projects; the starter has no API flow. Released backend **v0.4.0** retains rich catalogue facts/dated status and the reviewed numerical claim subset, and adds automatic structured public observations/source resolution; production v0.4.0 is hosted-verified and released; scanning, saved results and an offline UI remain future frontend work. Version-specific production evidence is recorded in the [current review](BACKEND_V0_4_0_REVIEW.md); complete India-market coverage remains unproven.
