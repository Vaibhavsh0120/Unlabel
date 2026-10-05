# Unlabel UI and interaction requirements

Status: requirements for later feature UI. A minimal responsive Flutter starter is foundation work; the four scanning features and a custom design system/palette are not implemented. Product name: **Unlabel**; tagline: **Label Padhega India**. One Flutter app directly in `frontend/` targets Android/iOS/web; platform capability differences must be visible.

## Device and layout coverage

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

1. **Start/scan:** explain front-and-back capture briefly; offer camera and website image selection. No login or lengthy onboarding blocks a first scan; preferences are optional.
2. **Permission/capability:** request camera access when the user selects it, explain its purpose, and provide upload/manual correction alternatives when unavailable. Stop browser camera tracks when leaving capture. Explain unsupported live overlays directly.
3. **Capture/review:** distinguish front, ingredients, and nutrition panels; keep original text alongside correction context. Label required units/basis and missing evidence. Preserve edits through rotation, error, retry, and back navigation.
4. **Processing:** show local versus online evaluation, meaningful stages, and a bounded retry/cancel path. No fabricated percentage or infinite spinner. Gemini failure switches wording without losing findings; an unavailable API leaves supported offline checks usable.
5. **Result:** lead with product identity, evidence completeness, mode/coverage, and claim states; then nutrients, suitability reasons, and ingredients. Place citations beside findings. Distinguish an unsupported rule from a supported check with missing evidence; both remain insufficient information.
6. **Ingredient detail:** original term, common name/purpose, qualified concerns, unknowns, and language/source controls. Hindi translation must preserve qualifications and allow longer text.
7. **Preferences/history/comparison:** preferences remain local; saving is explicit; history versions and separate device/browser storage are clear. Comparison exposes basis/units and missing data. Delete actions need deliberate confirmation or a reliable undo.

App navigation should provide a predictable back path between capture, correction, result, and ingredient detail. Website URLs/back preserve navigation without putting allergies or label text in URLs. Disclosures stay beside findings. Proposed capture copy: **Scan the food label**, "Capture the front and back of the same package. Review the text before analysis," with **Open camera** and **Choose photo** actions.

## Accessibility and understandable feedback

- Essential controls have visible text/outcome labels and accessible names. Camera-only input, icon-only meaning, hover-only actions, and undocumented gestures cannot be the sole route.
- Touch targets aim for at least 44 logical/CSS pixels with separation; website controls support keyboard, mouse, trackpad, and touch. Focus is visible and follows reading order; dialogs restore focus.
- Text meets at least 4.5:1 contrast and meaningful controls/focus 3:1 in both modes. Support text enlargement, browser zoom/reflow, screen readers, and reduced motion; animation never delays a safety-relevant finding.
- Findings combine wording/icons with any future colors. Nutrient charts show numeric values, units/basis, and a readable text/table alternative; chart colors alone do not encode meaning.
- Correction errors sit beside the field, describe the fix, and are announced accessibly. On submit, focus the first invalid field. Distinguish no text found, missing evidence, network failure, unavailable OCR assets, and empty history.
- Missing evidence must read **unknown/incomplete**, not safe or zero. "Not detected" is not "allergen-free." Proposed result copy: **Some label information is missing**, "Review the package and correct unclear text. Missing allergen information cannot confirm that this food is safe," with **Correct label** and **View evidence**. No diagnosis/treatment/safety guarantee.

## Later verification and free-scope boundary

Validate both languages/appearance modes across widths, actual iPhone/iPad portrait/landscape, MacBook Safari, and Android. Include enlarged text, keyboard-only operation, permission denial, storage failure, unsupported images, supported offline findings, unsupported-rule unknowns, and a cached offline web session. Web initial load, service-worker readiness, and missing OCR assets have distinct states.

Better Design responsive, mobile-web, accessibility, semantic-role, and error guidance informs this plan. Proposed capture/incomplete-result copy passed its text-only comprehension check; this proves neither rendered quality nor native behavior. Starter rendering checks are separate from future complete-feature reviews; DOM spacing measurement applies where a measurable DOM exists.

The foundation must retain the user's **zero cost/no card** constraint. The requested Flutter starter and manual APK/unsigned-IPA workflow do not authorize paid design kits, remote subscriptions, hosted user databases, or app-store purchases. iOS signing and installability limits are documented in the release plan. The Flutter website remains a later separate deployment from the backend API.
