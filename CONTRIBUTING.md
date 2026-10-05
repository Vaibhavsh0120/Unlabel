# Working on the Unlabel foundation

The current phase includes architecture, a basic Flutter starter and a manual APK/unsigned-IPA workflow. Core scanning, the backend and deployment are not implemented. Do not expand into those features or activate paid billing without the next implementation request.

## Team boundaries

- Android/iOS/web work belongs in the single Flutter frontend. Optional online API and expanded rule evaluation belong in backend; supported offline evaluation belongs in frontend/lib/core/analysis.
- Reviewed ingredient/rule/source content belongs in knowledge. Shared contract definitions belong in contracts. Shared test fixtures belong in data/fixtures.
- Agree on the API contract, missing-value behavior and evidence IDs before frontend/backend work starts in parallel.
- Preserve others' changes; keep one shared contract owner. Split changes by feature or responsibility.
- Update architecture and handoff documents when an accepted decision changes.

## Data and secrets

- Never commit API keys, private allergy profiles, real user scan history, runtime databases or unreviewed source downloads.
- backend/.env.example documents future settings. Real values belong in an ignored backend/.env file when implementation starts.
- Do not put Gemini keys into the mobile app, its assets, build arguments or client-side environment files.
- Fixtures must be synthetic or explicitly reusable, with source/rights recorded. Legal thresholds need a reviewed source, effective date and food-category applicability.
- Never turn unknown or missing data into zero, a passed claim or an allergy-safe verdict.

## Future validation

Implementation should test meaningful unit normalization, claim-rule applicability, allergens, evidence references, API shape and provider failures. Camera/OCR and overlay geometry require physical Android-device checks. Build success alone will not prove OCR accuracy or food safety.

Track application lockfiles. Do not add fake backend code, source data or test placeholders that suggest the food-analysis features already run. Use the manual workflow for version-aligned demo artifacts; never describe unsigned iOS as directly installable.
