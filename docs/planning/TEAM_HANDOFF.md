# Team handoff

Checkpoint **13 October 2026**: canonical versions are in
[frontend pubspec](../../frontend/pubspec.yaml) and [backend pyproject](../../backend/pyproject.toml).
Work directly on main and preserve existing edits. Current auth/profile, provider
compatibility and pending hosted/native gates are in the
[frontend review](FRONTEND_V0_8_0_REVIEW.md), [backend review](BACKEND_V0_12_1_REVIEW.md)
and [maintenance audit](MAINTENANCE_2026_10_12.md).

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
`flutter build web --release`, and `node --test test/*_web_test.cjs`.
Backend checks run from backend with its .venv Python: `-m pytest -q`,
`-m ruff check app tests`, and `-m pip check`. Script/workspace checks are
documented in [scripts](../../scripts/README.md). Native compilation uses the
[manual workflow](../../.github/workflows/README.md). From root,
`node --test firebase/auth-bridge.test.cjs` checks the fixed-origin email bridge.
[Account/profile setup](../architecture/ACCOUNT_PROFILE.md) records OAuth/signing,
owner-only media and the pending provider callback setting.

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
