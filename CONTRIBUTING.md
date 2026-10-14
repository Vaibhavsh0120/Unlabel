# Contributing

Read [AGENTS.md](AGENTS.md), current contracts and the working-tree diff first.
Work directly on main in this workspace; preserve teammate edits and historical
source/release evidence. Keep changes within the authorized scope and update
affected docs before pushing. Do not bump versions for the current maintenance.

Restore with `python scripts/setup.py`; run with `python scripts/run_local.py`.
Use `--scope backend` or `frontend` when appropriate. See
[local development](docs/planning/LOCAL_DEVELOPMENT.md) and
[actual folder ownership](docs/architecture/FOLDER_STRUCTURE.md).

From frontend, run `flutter analyze`, `flutter test`, `flutter build web --release`
and `node --test test/local_ocr_web_test.cjs`. From backend, use its .venv Python
for `-m pytest -q`, `-m ruff check app tests` and `-m pip check`.
From root, run `python scripts/release/validate_workspace.py`, icon/OCR checks and the
release guard tests described in [scripts](scripts/README.md).
Changes to API models require regenerated/synthetic-validated current contracts;
preserve old versioned OpenAPI. Native builds use the manual workflow separately.

Edit only pubspec.yaml or backend/pyproject.toml for a future component version;
do not repeat version literals in runtime/workflow files. Document the new release
without rewriting dated reviews. See [release/versioning](docs/planning/RELEASE_VERSIONING.md).

Never commit plaintext credentials, private identities or real scans. Keep
public sourced package facts separate from personal sync/private machine proposals.
Retain provenance, unknowns and conflicts; no invented health/allergy verdict.
Use existing free/no-card services and explicit consent for optional photo transfer.
