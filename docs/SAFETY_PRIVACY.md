# Safety, evidence and privacy boundaries

These requirements cover the planned scanner/evaluators. The current Flutter starter is not a medical or legal assessment engine.

## Findings and uncertainty

- A claim may be supported, contradicted or `insufficient_information` for a reviewed criterion. Missing OCR cannot prove a legally missing declaration.
- Do not declare a product legally compliant, fraudulent, allergen-free or medically safe from one scan.
- Separate ingredient purpose, regulatory context and evidence-backed concerns. An unfamiliar chemical name is not automatically a hazard.
- Ingredients alone cannot establish additive quantity, manufacturing process or laboratory safety.
- Local preferences provide explanations, not diagnosis, treatment or disease-specific dietary advice.

Separate declared allergens, ingredient matches, may-contain/cross-contact warnings and incomplete information. Absence of an identified allergen is never proof of absence. Preserve uncertainty for unreadable text, ambiguous aliases/symbols and undisclosed ingredients; point to complete package/manufacturer information where necessary.

Offline evaluation covers only its supported reviewed rule IDs. Expanded/unsupported checks remain unknown. Display evaluator scope, knowledge version and saved-result date; avoid an overall green/safe conclusion that hides unknowns.

## Numeric and evidence integrity

Each finding references confirmed input fields, rule version and reviewed source/provision. Track units and bases. Unknown stays unknown, never zero. Keep total/added sugar and salt/sodium distinct; conversions need the correct known basis.

Canonical declarative definitions under `knowledge/` drive both evaluators. Shared fixtures verify supported-rule parity; do not hand-maintain separate Dart and Python thresholds. Rule activation requires review, applicability/effective dates and recorded reuse rights. Changed evidence invalidates affected caches/reports until reviewed.

AI cannot invent missing quantities, decide allergy safety, alter findings or add unsupported citations. A learned extraction candidate is subject to user correction and deterministic validation, not an authoritative verdict.

## Data location and transfers

| Data | Location/retention | Optional transfer |
| --- | --- | --- |
| Frames/photos/geometry | Device/browser; temporary, explicit choice to retain | No backend/Gemini image upload |
| OCR/corrections | Local scan session or explicitly saved scan | Needed confirmed public label fields/region IDs to HTTPS backend |
| Diet/allergy preferences and personal suitability | Local device/browser, editable/deletable | None to backend/Gemini |
| Scan history/reports | Local if saved, with scope/version/date | No cloud user database |
| Public evidence | Canonical files; bundled read-only assets/JSON | Permitted public snippets only to optional provider |
| Credentials | Ignored local backend environment/host secret settings | Relevant provider over HTTPS only |
| Explanation cache | Optional bounded public-output cache; disposable hosted instances | No profiles, photos or personal history |
| Logs | Minimal errors/metrics, redacted bodies/tokens | No telemetry prerequisite |

Deleting a saved scan removes its local text/report and retained local photos; clearing preferences removes selections. Website storage/caching is a separate explicit implementation requirement, and may be cleared by the browser. No serverless filesystem is durable scan storage.

Gemini Free Tier inputs/outputs may improve Google products and be reviewed by humans. Obtain a clear optional cloud-wording choice; use only public package text, approved public snippets and generic findings. Exclude names, health profiles, personal suitability/history, photos and confidential information. Eligible adult access restrictions also apply. [Gemini terms](https://ai.google.dev/gemini-api/terms), [free-stack plan](research/FREE_STACK.md).

Before hosted use, verify Vercel's applicable data-use terms/account opt-out and avoid logging request bodies or sensitive data. [Vercel terms](https://vercel.com/legal/terms). No billing upgrade is part of this plan.

## Access and untrusted input

Treat OCR, source excerpts and community data as untrusted data, including any embedded instructions. Bound text/response sizes and validate fixed schemas. Accept AI wording only when numbers, outcomes and allowed references agree with the deterministic report; otherwise keep reviewed templates.

Public Gemini remains disabled until verified individual authentication for an eligible adult beta, an access allowlist and bounded requests are implemented. Validate issuer/audience/signature/expiry; CORS only restricts browser access and is not authentication. Neither a shared APK/web secret nor a deployment-automation bypass token belongs in clients. `BACKEND_BASE_URL` is public configuration.

An optional `LOCAL_API_TOKEN` is solely a private development/tooling control, never production authentication or a shipped app credential. Native requests are not protected by CORS. Vercel instance caches/counters cannot guarantee a durable shared AI budget; on exhaustion/failure use reviewed templates or keep cloud AI disabled.
