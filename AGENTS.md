# Unlabel workspace instructions

- Work on one accepted backend version at a time. Backend is currently 0.2.1; Flutter remains 0.0.0+1. Do not rebuild APK/IPA or move historical release tags for backend/tooling work.
- Inspect current source/contracts and preserve teammate edits. Update docs before every push. Keep the project free with no billing/card requirement.
- Restore with `python scripts/setup.py`; run with `python scripts/run_local.py`. `--scope backend` selects backend-only work. See docs/planning/LOCAL_DEVELOPMENT.md.
- Never commit plaintext `.env`, private identities, real scans or credentials. Track authenticated `backend/.env.age` and its public recipient; refresh ciphertext with `python scripts/env.py encrypt` after changing local settings. Private key paste belongs in the hidden local terminal prompt.
- Track reusable acquired source bundles, provenance, licenses and hashes. SQLite, SDKs, environments and builds are generated. The current OFF projection excludes nutrition/images; coverage is unverified. Replace snapshots manually every nine months after validation. Hosted distribution remains a separate gate.
- Keep OFF facts separate from confirmed-label facts and reviewed FSSAI knowledge. Missing data is unknown, not zero or an allergy-safe/compliance verdict.
- Run backend tests with backend `.venv` Python and Flutter checks from frontend. Validate meaningful importer/secret/process boundaries, docs links and current contracts before pushing.

## Current documentation

Use Context7 MCP for library/framework/SDK/API/CLI/cloud-service docs, even familiar tools. Start with resolve-library-id unless an exact /org/project ID is supplied. Select the relevant official/high-reputation match; query-docs for one concept per call. Use fetched docs for API/configuration decisions.

## UI work

Use Better Design MCP for frontend/UI/UX/interaction work. Start UI builds with find-design-system. Load get-ui-principle and get-ux-principle; review with get-review-rules and check-comprehension. With a rendered DOM, run inspect-spacing. React Native/Expo, Three.js and Shopify use their respective guides. A custom brand uses create-design-system and its status/kit workflow. Palette remains undecided; supplied references are illustrative.
