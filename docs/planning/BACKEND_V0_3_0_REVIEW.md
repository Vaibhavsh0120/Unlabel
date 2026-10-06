# Backend v0.3.0 review and release gates

Prepared **7 October 2026** (Asia/Calcutta). Source **0.3.0**, frontend **0.0.0+1**. This is the second independent backend version in the [accepted plan](../superpowers/plans/2026-10-06-backend-v0.2.3-v0.3.0.md); [v0.2.3](BACKEND_V0_2_3_REVIEW.md) remains an independently pushed, hosted-verified and tagged release. [Release notes](BACKEND_V0_3_0_RELEASE.md) · [Current API](../../backend/README.md) · [Readiness tracker](FEATURE_TRACKER.md).

## Implemented scope

| Boundary | Current behavior |
| --- | --- |
| Confirmed input | Strict normalization rows plus 1–16 unique identified claims, selected table and explicit food/form/preparation context; no image/profile/raw OCR |
| Numerical rules | Source/high fibre, low/sugar-free and low/very-low/sodium-free; ordinary general food and matching confirmed table only |
| Unreviewed claims | High/source protein, no-added-sugar and multigrain always insufficient with reasons/missing inputs |
| Outcomes | Supported/contradicted/insufficient; any applicable alternative may pass, but contradiction needs every applicable alternative known and failing |
| Provenance | Input row/region IDs, rule IDs, source IDs, knowledge version, assessment date and numerical-only scope |
| Exact numerical comparisons | Original decimal strings plus unit/basis factors become exact rational values; non-terminating conversion cannot move a threshold; bounded output rejects unrepresentable results |
| Energy | Statutory 4.2 kJ/kcal from original rows with exact rational arithmetic; normalization-v1 4.184 snapshot remains unchanged |
| Evidence currency | Known future publication/effective dates, future/non-current reviews, unsupported category or conflicts suppress affected assessments |
| Read APIs | Seven rules plus unsupported list; three public evidence records; unknown source 404, invalid/missing knowledge typed 503 |
| Request boundaries | Both POST routes use actual 32 KiB bounds, checked numeric JSON tokens and shared bounded redacted 422 errors |
| Storage/providers | Stateless request memory; no OFF/FSSAI/Gemini requests for claim evaluation; no uploaded PDFs or source photos |
| Knowledge packaging | Two approved bounded JSON files, hashes/lengths and a strict receipt; generated copies ignored; hosted receipt required including explicit overrides |
| Compatibility | Eleven routes/current OpenAPI, five added schemas and eleven validated owned examples; historical exports and strict earlier contracts preserved |
| Setup progress | Dependency-free stderr byte bars for compressed/decoded verification; unknown-total stages use elapsed/indeterminate work; native dependency output preserved; noninteractive logs have no redraw or guessed percentage |

## Reviewed sources and bundle

Canonical [rules](../../knowledge/rules/claims/reviewed-v1.json) and [registry](../../knowledge/sources/registry/fssai-claims-v1.json) identify **claims-2026-10-06.1**, reviewed **6 October 2026**. The [knowledge guide](../../knowledge/README.md) records all three official PDF URLs, acquired hashes/sizes and exact page/row locators. Fresh bounded reads matched all three PDFs against the registry without retaining document bytes: [dated source check](../research/FSSAI_CLAIMS_V0_3_0_SOURCE_CHECK.json). Gazette notifications are authoritative; the compendium is a cross-check. No source PDF is redistributed in Git or the function.

`backend/build_catalogue.py` passed the actual network-free combined build, generating and verifying the catalogue and knowledge receipts. Successful stdout is one JSON object with `catalogue` and `claims_knowledge` keys. Existing v0.2.3 OFF source/count/date/coverage remains unchanged; receipt bytes can differ across catalogue builds because build UUID/index dates differ. Vercel must match its own actual build receipt to public metadata, not a previous local database hash.

| Approved packaged JSON | Bytes | SHA-256 |
| --- | --- | --- |
| `rules/claims/reviewed-v1.json` | 11,754 | `5977bc482e105931deb79858430894e330b23ef682c93b9c4aa25d1a14a39128` |
| `sources/registry/fssai-claims-v1.json` | 2,913 | `6697f183d315475eacb7fb678df3be6bf3123e35f0122e070bb020b9f1f57e4d` |

With `VERCEL=1`, startup verifies a knowledge receipt even when `CLAIMS_KNOWLEDGE_DIRECTORY` explicitly selects another directory. An invalid existing package never falls back to canonical source. Local development may load canonical root knowledge only when the default package is absent; verified packaged knowledge exposes `/v1/meta.knowledge_artifact`, while direct canonical loading has a null artifact. Knowledge failure leaves health, live OFF and catalogue readiness independent.

## Checks before source push

| Gate | Evidence/status |
| --- | --- |
| Full backend tests | **543 passed**, including **16 setup-progress regression cases**, with only the existing Starlette/httpx deprecation warning |
| Claim API checks | **20 passed** before complete-suite verification |
| Lint/format | Ruff check passed for backend and all **11 Python scripts**; **60 Python files** passed format checks |
| Static types | Root-configured basic **Pyright 1.1.414** passed for **59 Python files**, **zero errors / zero warnings**. [Pinned reproducible optional command](../../backend/README.md#validate) |
| Dependencies | `pip check` passed |
| Contract exports | Current eleven-route OpenAPI and five added schemas compare with runtime; all eleven owned examples validate |
| Actual network-free build | Final combined catalogue plus approved JSON knowledge build/receipt verification passed; the two knowledge hashes above match |
| Actual local setup | `setup.py --scope backend --non-interactive` passed, preserving existing env and reusing the validated **24,641-record** index |
| Independent code/dead-code review | Fresh independent review passed **150 focused tests** with no remaining findings. Hosted explicit-override receipt gap fixed with RED→GREEN regression; unused duplicate router knowledge loader removed. Fractional-basis threshold rounding was fixed with exact rational comparisons; nine boundary/outside cases reproduced failures then passed. An extreme tiny positive energy overflow regression passed after bounded conversion was fixed |
| All Markdown/scripts | All **63 Markdown files** checked for current versus historical scope; guides match v0.3.0 routes, knowledge, build/progress output and remaining work. All **11 maintained Python scripts**, both PowerShell wrappers, application/build/progress source and existing workflow/web script boundaries reviewed |
| Syntax/artifacts | All maintained Python AST, **49 JSON**, **1 TOML**, **3 YAML** and **11 XML/plist** parsed; both PowerShell parsers, web Bash syntax, **7 workflow Bash blocks** and **6 embedded Python snippets** passed |
| Docs links/whitespace | Final links checked after current Markdown updates; zero missing targets. `git diff --check` passed with line-ending advisories only |
| Settings/secrets | Public OFF identity updated to 0.3.0; ciphertext refreshed; no tracked private keys. Generated SQLite/knowledge/receipts and plaintext env are ignored. Actual private-key restoration was not rerun |
| Frontend/native boundary | Flutter analysis reported zero issues and all **3 tests passed**; source remains 0.0.0+1 with no frontend integration, APK/IPA rebuild or historical tag movement |

## Hosted and publication gates

Source push, exact-commit production deployments, build-log receipt/public metadata agreement, claim/rule/evidence HTTP behavior, invalid/oversized/unknown/conflicting cases, current OpenAPI, compatibility, CORS and website/bootstrap checks are pending. A local build or READY deployment alone is insufficient endpoint proof. Confirm excluded env, database, receipt and knowledge paths are not publicly served.

After verified source push and hosted behavior, publish a source-only Backend v0.3.0 prerelease for the tested commit, preserving earlier tags/assets. Record the exact implementation SHA, deployment IDs, public receipts and dated HTTP evidence here. Do not represent this pending production/publication gate as complete.

The wider full report/health score, claim coverage beyond this subset, glossary, comparison, saved/history/preferences, camera/OCR and frontend wiring remain future work. Missing data stays unknown; numerical support never establishes allergy safety or complete legal compliance.
