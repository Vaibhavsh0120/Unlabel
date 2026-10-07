# Backend v0.6.0 Product Discovery review

Goal: bounded name/brand/quantity-text candidate discovery over the existing OFF
snapshot, followed by exact barcode selection and the released useful report.

Implementation, local validation and independent review are complete.
Hosted production remains separately
verified v0.5.0 until the v0.6.0 source is pushed and its exact deployment checked.
The accepted [connected release plan](CONNECTED_RELEASE_PLAN.md) tracks both
components. [Search contract](../architecture/PRODUCT_DISCOVERY.md).

Required gates: focused/full backend tests; Ruff/Pyright; schema/example exports;
network-free bundle receipt/size; actual same-source setup migration/progress;
old 18-route/component compatibility; all Markdown/scripts/links/private values;
independent code review; push; exact hosted artifact/search/legacy report checks;
source-only release preserving historical tags. Results are recorded after runs.

## Local evidence, 7 October 2026

- Full backend suite: **863 passed, 5 skipped**. Skips require the explicitly
  selected Firestore emulator; previous release cloud/hosted checks are historical.
- Ruff passed across app/tests/scripts; Pyright reported **0 errors, 0 warnings**.
- Exported nineteen-route v0.6.0 OpenAPI, search schema and **24** validated
  synthetic examples. Structural comparison found **zero changes** to the
  eighteen old paths and their existing components. Historical exports remain.
- Network-free source build produced **76,111,872 bytes (72.58 MiB)**, below the
  100 MiB artifact cap. All **24,641** supported identities remain indexed. Search
  adds optional tables without changing Manifest, application ID or user version.
- Actual backend setup preserved local settings, passed locked dependency checks
  and rebuilt the same acquired source with the new discovery index. Validation
  and build progress were visible; no new source download or paid provision ran.
- Measured full validation used 8.295 million SQLite VM instructions in 0.268 s;
  the bounded 50-million-instruction refresh also handled a real old-to-new
  76 MiB snapshot replacement in 0.269 s. Regular queries retain a separate
  one-million-instruction/1,000-candidate limit.
- Query/Unicode/prefix/broad-input/pagination/stale-cursor/index corruption and
  replacement regressions passed. Invalid inputs use redacted 422 responses.

The local build hash and snapshot ID are generated per build. Hosted receipts
must be read from the actual deployment; local bytes do not prove production.

Independent review checked real indexed searches, SQL index plans, provenance,
snapshot replacements, resource limits and unchanged old contracts. One example
warning differed from the runtime; it was aligned and exports regenerated. No
blocking runtime findings remained. Review did not establish regional coverage.

Workspace review parsed every maintained Python/JSON file, all Markdown links,
YAML/TOML/XML/plist files, Bash build/workflow steps and PowerShell scripts.
Python type checking includes maintained scripts and tests. Updated setup reuse,
version metadata, acquisition User-Agent, exports and encrypted environment;
preserved plaintext/private identities outside Git. No demonstrably dead backend
code was found. The frontend's dead starter is removed in its separate release.

Frontend integration, real-device camera/OCR and measured retail coverage are
separate evidence. No paid Firebase feature, AI call or model training is selected.
