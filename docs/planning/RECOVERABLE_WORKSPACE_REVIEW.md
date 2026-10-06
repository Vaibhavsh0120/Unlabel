# Recoverable workspace review

Historical maintenance record for backend 0.2.1. Current backend 0.3.0 claim/bundle/deployment gates are in the [v0.3.0 review](BACKEND_V0_3_0_REVIEW.md), with independently released catalogue proof in the [v0.2.3 review](BACKEND_V0_2_3_REVIEW.md); the results below describe the earlier checkout.

Maintenance checked on **6 October 2026**. Backend remains 0.2.1; frontend remains 0.0.0+1. Release tags and APK/IPA assets are untouched.

The acquired India projection is committed as deterministic gzip: 840,099 compressed bytes, 6,588,910 decoded bytes; 21,188 rows, 21,138 supported records. The bundle manifest, original provenance and official ODbL/DbCL texts travel with it. Hashes distinguish this gzip from the original global source. Coverage remains unverified; nutrition tables/images are absent. Supplied concept references are retained for teammate recovery and are not authoritative product facts.

An actual age file-key decryption round trip matched the current local `.env` without displaying plaintext or identity contents. Setup preserves existing env files and supports a key path, hidden terminal paste, or example defaults. Pasted native identities use age stdin without a saved identity file. Failed decryption and competing plaintext publication are covered by regressions. Temporary decrypted files are ignored and cleaned by their invocation.

The importer checks expected source hash/row/index counts before publication. Wrong expectations preserve the active database. Setup validates the committed bundle, reuses matching indexes and preserves a different valid index unless replacement is explicit.

## Verified results

| Check | Result |
| --- | --- |
| Backend suite | **232 passed**; one existing Starlette/HTTPX deprecation warning. |
| Static/dependency checks | Ruff lint passed, 38 Python files passed format checks, `pip check` found no broken requirements. |
| Documentation | All 54 tracked Markdown files checked for local file links: 214 targets, zero missing. Active version/storage summaries corrected; tagged release records retained as history. |
| Bundle integrity | Compressed/decoded hashes and lengths matched `bundle.json`; 21,188 source rows retained. |
| Tracked-file review | No native private identity or PEM private-key content found. Plaintext env, staging files, SDKs and SQLite remain ignored; largest tracked file is the supplied scan concept, 1,797,039 bytes. |
| Component boundaries | No frontend, contract or mobile-workflow changes in this maintenance task; backend 0.2.1 and frontend 0.0.0+1 unchanged. |

A clean checkout of the staged tracked files began without `.env`, `.venv` or SQLite. Full setup restored the actual age-encrypted settings using the existing external key file, created a new Python environment from the committed development lock, rebuilt the 21,138-record SQLite index and restored Flutter dependencies with the pinned lockfile. It reused the installed Flutter 3.47.4 SDK. This was a local tracked-file checkout, not a remote clone or a first-time SDK installation test.

Both services then ran from that clean copy on ports 8017/7367: health/meta reported readiness, catalogue barcode `8904083506393` returned found, exact local CORS was present, and the Flutter page returned 200. Ctrl+C closed both owned services. The PowerShell launcher was also exercised on backend port 8019; lookup/readiness passed and Ctrl+C closed that port. Existing env bytes matched the restored clean-copy env and stayed unchanged.

Hidden pasted-key handling was verified through synthetic regressions for stdin transport, no key argument/file, error redaction and refusal of echo fallback. Actual cryptographic restoration was verified with the external key file; no real private key was pasted through an automated terminal test.

README branding/quickstart was reviewed in a GitHub-style Markdown browser preview at **390, 1440 and 1728 pixels**, light and dark. All six states had zero document-width overflow and no missing image alt text. Screenshots were inspected; Better Design's quickstart comprehension check passed. Measured branding/quickstart spacing returned no critical/serious findings; the moderate flags were the preview stylesheet's native heading padding and automatic centered margins. This is documentation preview evidence, not a test of GitHub's own renderer or the planned application screens.

Hosted catalogue stays inactive. macOS/Linux paths are implemented but need platform execution before claiming verification there. SDK bootstrap without an installed Flutter, real native builds, OCR, regulatory analysis and hosted snapshot distribution remain separate gates. No APK/IPA action was dispatched. The next feature version is **backend v0.2.2**, focused on catalogue coverage and reproducible hosted distribution.
