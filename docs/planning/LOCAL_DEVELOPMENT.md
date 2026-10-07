# Clone, restore, run

Local backend **v0.4.0** implements the community catalogue APIs; production
remains **v0.3.0** until push/hosted verification. Flutter stays **0.0.0+1**.
OFF snapshot and reviewed claims work independently of Firebase. Camera/OCR,
client background requests and v0.5.0 reports remain pending. [Master plan](MASTER_PLAN.md).

## Quick start

Install Git and Python 3.12+ first. Install [age](https://github.com/FiloSottile/age#installation) for encrypted restoration. Flutter 3.47.4 is reused when available; otherwise setup clones that official version into ignored `.local-tools/flutter-sdk`, leaving the global SDK unchanged. First-time SDK/dependency installation needs internet. Android/iOS development still needs its platform toolchain.

~~~powershell
git clone https://github.com/Vaibhavsh0120/Unlabel.git
cd Unlabel
./scripts/setup.ps1
./scripts/run-local.ps1
~~~

macOS/Linux: `python3 scripts/setup.py`, then `python3 scripts/run_local.py`.
This private repository requires teammate GitHub access. No Git LFS, database
account, API key or new world-export download is needed for OFF snapshot/claims.
The automatic public-fact catalogue needs explicit Firebase project/database and
private backend credentials; safe defaults leave it disabled. Setup never
provisions a cloud account, attaches billing or creates a paid fallback.

| Setup step | Result |
| --- | --- |
| Environment | Preserve existing `backend/.env`; otherwise restore ciphertext or copy safe defaults. |
| Python | Create ignored `backend/.venv`, install the tracked direct/transitive development version lock and check dependencies. |
| Product source | Verify committed compressed/decoded hashes and byte limits for 24,695 India rows. |
| SQLite | Regenerate ignored `backend/storage/runtime/india/catalogue.sqlite3`: 24,641 supported identity/facts records. Expected hash/counts are checked before publication; reuse a matching valid index. |
| Flutter | Resolve the pinned SDK and run `flutter pub get --enforce-lockfile`. |

Setup now shows progress automatically. Catalogue verification uses measured compressed/decoded bytes and prints `Verified` only after checksum and size checks succeed. Interactive terminals show byte bars plus an indeterminate bar/elapsed time for environment creation and index validation/build; pip and Flutter operations have named stages and retain native output. Noninteractive/redirected logs use plain `Starting`/`Verified`/`Done`/`Stopped` lines without redraws or invented percentages. Progress goes to stderr, adds no dependency or download, and needs no new flag. A failed stage reports `Stopped`; it does not claim completed verification.

Use `-Scope backend` / `--scope backend` for backend-only work, or `frontend` for Flutter-only setup. Re-running setup preserves a different valid catalogue. To adopt an updated committed bundle deliberately, use `-ReplaceCatalogue` / `--replace-catalogue`. Corrupt/unrecognized existing databases require operator review. A same-source JSONL identity-only database is preserved by default; `--replace-catalogue` deliberately rebuilds its facts table. Actual `scripts/setup.py --catalogue-only --replace-catalogue` restored 24,641 records and the 62,472,192-byte local index in this release; private-key env restoration was not rerun.

## Firebase community configuration

Firebase **Unlabel**, project `unlabel-india-catalogue`, has its first Standard
Firestore database **`unlabel`** in **Mumbai/asia-south1**, free tier enabled and no
linked billing. Anonymous Auth, deny-all direct client rules and dedicated backend
credentials are configured. Safe defaults keep `COMMUNITY_ENABLED=false`.

Enabling requires `COMMUNITY_PROJECT_ID`, `COMMUNITY_DATABASE_ID=unlabel`, backend
`COMMUNITY_SERVICE_ACCOUNT_JSON` and an actor secret of at least 32 characters.
Restore authorized encrypted settings or configure ignored `.env`; never put
admin secrets into Flutter or tracked plaintext. `firebase/client-config.json`
is public SDK configuration. Setup does not provision/cloud-deploy or enable billing.
Use the [community guide](../architecture/COMMUNITY_CATALOGUE.md) and
[operator commands](../../scripts/README.md). Live/emulator/hosted proof remains
separate in the [review](BACKEND_V0_4_0_REVIEW.md).

## Restore encrypted settings

`backend/.env.age` is tracked ciphertext for the public recipient in `scripts/age-recipient.txt`. Plaintext, decrypted staging files and private identities stay outside Git. Vercel excludes `.env*`; production settings are managed separately.

If `.env` is absent, setup offers **key file**, **hidden private-key paste**, or **safe example**. `-Identity PATH`, `--identity PATH` or `AGE_IDENTITY_FILE` supplies a key path without prompting. Existing `.env` is checked first and kept unchanged. Hidden paste accepts one native `AGE-SECRET-KEY-1...` line and passes it directly to age stdin: no saved identity file, command argument or echoed key. Terminals unable to hide input are refused. Share authorized key access separately from GitHub.

~~~powershell
./scripts/setup.ps1 -Identity 'D:/Dev/Secrets/age/master-age-key.txt'
./scripts/setup.ps1 -Scope backend -NonInteractive
# After editing local values, refresh ciphertext before pushing:
python scripts/env.py encrypt
# Explicit restoration when .env is absent:
python scripts/env.py decrypt --identity 'D:/Dev/Secrets/age/master-age-key.txt'
python scripts/env.py decrypt --paste-key
~~~

Explicit decryption refuses existing plaintext unless `--force` is supplied. It publishes only after successful decryption; failures preserve existing files. Your `agel`/`ageu` functions also work from `backend/` with this recipient; the repository helper stages output instead of redirecting directly over `.env`. Paste private keys only into the local hidden terminal prompt. Example defaults support today's OFF APIs without decrypted secrets.

## Run and exit

Open **http://127.0.0.1:7357** for the starter and **http://127.0.0.1:8000/docs** for the API. The runner checks occupied ports, waits for backend readiness, uses the restored catalogue with `CATALOGUE_REQUIRE_RECEIPT=false` for that local index, and supplies exact local CORS origins through process-only overrides. It passes `BACKEND_BASE_URL` to Flutter without rewriting `.env`; the starter has no API interaction yet. Press **Ctrl+C** to stop owned services. A failed service stops the others.

~~~powershell
./scripts/run-local.ps1 -Scope backend
./scripts/run-local.ps1 -BackendPort 8001 -WebPort 7358
./scripts/run-local.ps1 -Scope frontend -BackendUrl https://unlabel-api.vercel.app
~~~

Web-server mode opens no browser automatically. First compilation can take longer. These scripts do not build APK/IPA, change versions, deploy cloud services or set up native signing.

## Keep in Git

Source, docs, native project files, lockfiles, public data/provenance/licenses, supplied concept references and age ciphertext are tracked. The [2,098,225-byte India JSONL bundle](../../data/catalogue/README.md) removes the need for another global download. SQLite, environments, SDKs and build caches are regenerated by setup/build commands. The world dump, private scans, plaintext credentials and private identities remain excluded. Git history retains old bundles; nine-month replacement does not erase history.

This establishes **local recovery**. The current backend also has a separate networkless hosted build: from `backend/`, run `.venv/Scripts/python.exe build_catalogue.py` (Unix: `.venv/bin/python build_catalogue.py`) to generate ignored `app/catalogue/data/catalogue.sqlite3`/`receipt.json` and the approved two-file claim knowledge/receipt under `app/claims/data/`. Successful stdout is one JSON object with `catalogue` and `claims_knowledge` keys. Use `CATALOGUE_DIRECTORY=app/catalogue/data` and `CATALOGUE_REQUIRE_RECEIPT=true` when exercising that packaged path; the local runner deliberately uses the setup-generated index instead. [Historical recovery verification](RECOVERABLE_WORKSPACE_REVIEW.md) · [Current source/build/hosted gates](BACKEND_V0_3_0_REVIEW.md).

After deliberately updating backend dependencies, run `backend/.venv/Scripts/python.exe scripts/lock_backend.py` from root (use `backend/.venv/bin/python` on Unix), review the lock and run the backend suite before committing it. Runtime requirements remain declared separately.

For a valid identity-only index from the same JSONL source, setup preserves the store by default; run `python scripts/setup.py --scope backend --replace-catalogue` to migrate it to the current facts-enabled catalogue. An intact current facts store is reused.

## Claim knowledge in local and hosted runs

The current build validates canonical `knowledge/rules/claims/reviewed-v1.json` and `knowledge/sources/registry/fssai-claims-v1.json`; generated copies/receipt stay ignored. `build_catalogue.py --knowledge-directory PATH --knowledge-output-directory PATH` selects explicit knowledge build locations. `CLAIMS_KNOWLEDGE_DIRECTORY` selects a runtime directory relative to backend or absolute. Local default uses `app/claims/data` when present, otherwise root canonical `knowledge/`; an invalid existing package never falls back. With `VERCEL=1`, a verified knowledge receipt is required even for an explicit override. Invalid/missing knowledge disables only claim/rule/evidence access. No setup/run/build operation downloads regulator PDFs, enables Gemini or requires a paid service. Check `/v1/meta` capabilities/knowledge version and retain its receipt summary when available. [Current API/synthetic claims](../../backend/README.md#reviewed-confirmed-label-claim-checks).
