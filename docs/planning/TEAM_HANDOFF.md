# Team handoff

Checkpoint **12 October 2026**: frontend **0.7.0+11**, backend **0.12.0**.
Work directly on main and preserve existing edits. The active maintenance scope
and evidence gates are in [the audit](MAINTENANCE_2026_10_12.md).

## Restore and validate

From the repository root, use Python 3.12+:

~~~sh
python scripts/setup.py
python scripts/run_local.py
~~~

Windows wrappers are `scripts/setup.ps1` and `scripts/run-local.ps1`.
`--scope frontend` and `--scope backend` select one component. Safe defaults run
the public catalogue/guest workflow; hidden-key restoration enables existing
configured services. See [local development](LOCAL_DEVELOPMENT.md).

Frontend checks run from frontend: `flutter analyze`, `flutter test`,
`flutter build web --release`, and `node --test test/local_ocr_web_test.cjs`.
Backend checks run from backend with its .venv Python: `-m pytest -q`,
`-m ruff check app tests`, and `-m pip check`. Script/workspace checks are
documented in [scripts](../../scripts/README.md). Native compilation uses the
[manual workflow](../../.github/workflows/README.md).

## Ownership

| Module | Responsibility |
| --- | --- |
| frontend/lib/app and core | Composition, version/configuration, capture, network and local storage |
| frontend/lib/features | Scanner/results/research/comparison, Insights and optional account UI |
| backend/app | Typed API, bounded providers, verified source stores and deterministic reports |
| scripts | Restore/run, version metadata, source validation and release packaging |
| contracts | Current models/examples and immutable historical OpenAPI |
| data and knowledge | Licensed sources, hashes, provenance and reviewed rules |
| docs and design | Active contracts, dated release evidence and reference direction |

See [actual folder map](../architecture/FOLDER_STRUCTURE.md),
[feature tracker](FEATURE_TRACKER.md), [remaining gates](FRONTEND_BACKEND_NEXT_VERSIONS.md)
and [release ledger](CONTROLLED_RELEASES.md).

## Boundaries

Keep public product observations separate from personal account records and
private unverified proposals. Photos/raw OCR remain outside saved/synced data.
Never commit plaintext credentials, private keys, real scans or identities.
Preserve the original OFF/research sources and disagreements; missing is unknown.
Use Spark/free services without paid Storage/Functions or linked billing.
Optional extraction uses explicit consent and a server credential. No reviewer
accounts, suitability verdict, universal score or custom model training is added.
Current source/runtime metadata is separate from dated hosted/device evidence.
