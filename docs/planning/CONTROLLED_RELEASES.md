# Controlled component releases

The maintenance pass publishes missing reviewed source identities and preserves
historical tags/assets. Current versions come from the component manifests.
The later auth/profile frontend release is documented in
[its review](FRONTEND_V0_8_0_REVIEW.md), with the minimal
[backend compatibility patch](BACKEND_V0_12_1_REVIEW.md) separate. Their publication
identities are recorded after verification.

Historical source identities are recorded in [the machine ledger](../../contracts/versioning/releases.json).
Legacy backend vVERSION tags stay preserved. New backend/frontend tags identify
their component; mobile frontend-vVERSION+BUILD tags identify separate artifacts.

| Component | Source release | Implementation | Review |
| --- | --- | --- | --- |
| backend | [0.1.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.1.0) | `d1889f0e` | [Evidence](BACKEND_V0_1_0_REVIEW.md) |
| backend | [0.2.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.0) | `26b65230` | [Evidence](BACKEND_V0_2_0_REVIEW.md) |
| backend | [0.2.1](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.1) | `ef6fac2d` | [Evidence](BACKEND_V0_2_1_REVIEW.md) |
| backend | [0.2.2](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.2) | `5583aca5` | [Evidence](BACKEND_V0_2_2_REVIEW.md) |
| backend | [0.2.3](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.2.3) | `56064d7f` | [Evidence](BACKEND_V0_2_3_REVIEW.md) |
| backend | [0.3.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.3.0) | `ba44cbd2` | [Evidence](BACKEND_V0_3_0_REVIEW.md) |
| backend | [0.4.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.4.0) | `d793f628` | [Evidence](BACKEND_V0_4_0_REVIEW.md) |
| backend | [0.5.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.5.0) | `0c067027` | [Evidence](BACKEND_V0_5_0_REVIEW.md) |
| backend | [0.6.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.6.0) | `c5fa8832` | [Evidence](BACKEND_V0_6_0_REVIEW.md) |
| backend | [0.7.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/v0.7.0) | `9d9a9b64` | [Evidence](BACKEND_V0_7_0_REVIEW.md) |
| backend | [0.8.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.8.0) | `1a2fd25b` | [Evidence](BACKEND_V0_8_0_REVIEW.md) |
| backend | [0.9.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.9.0) | `5ed899e2` | [Evidence](BACKEND_V0_9_0_REVIEW.md) |
| backend | [0.10.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.10.0) | `e04ba543` | [Evidence](BACKEND_V0_10_0_REVIEW.md) |
| backend | [0.11.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.11.0) | `578a9afe` | [Evidence](BACKEND_V0_11_0_REVIEW.md) |
| backend | [0.12.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/backend-v0.12.0) | `39e600e1` | [Evidence](BACKEND_V0_12_0_REVIEW.md) |
| frontend | [0.1.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.1.0) | `1138c292` | [Evidence](FRONTEND_V0_1_0_REVIEW.md) |
| frontend | [0.2.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.2.0) | `5f3e92fe` | [Evidence](FRONTEND_V0_2_0_REVIEW.md) |
| frontend | [0.3.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.3.0) | `3f9a8172` | [Evidence](FRONTEND_V0_3_0_REVIEW.md) |
| frontend | [0.4.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.4.0) | `d8b2eb33` | [Evidence](FRONTEND_V0_4_0_REVIEW.md) |
| frontend | [0.5.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.5.0) | `00ae1759` | [Evidence](FRONTEND_V0_5_0_REVIEW.md) |
| frontend | [0.6.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.6.0) | `6403517b` | [Evidence](FRONTEND_V0_6_0_REVIEW.md) |
| frontend | [0.6.1](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.6.1) | `48b6f3e4` | [Evidence](FRONTEND_V0_6_1_REVIEW.md) |
| frontend | [0.6.2](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.6.2) | `ed2b8ff6` | [Evidence](FRONTEND_V0_6_2_REVIEW.md) |
| frontend | [0.6.3](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.6.3) | `afccb9c1` | [Evidence](FRONTEND_V0_6_3_REVIEW.md) |
| frontend | [0.7.0](https://github.com/Vaibhavsh0120/Unlabel/releases/tag/frontend-v0.7.0) | `8b5f9064` | [Evidence](FRONTEND_V0_7_0_REVIEW.md) |

Source publication does not imply native signing, current hosted runtime or
physical camera/recognition proof. Versioned reviews/JSON receipts retain their
original test totals, deployed commit and unavailable gates.

The historical mobile 0.6.1+5 draft targets frontend 0.6.2+9 source using explicit
build/version overrides. Its assets remain a draft and are not relabeled as the
canonical source version. Starter and older mobile tags/assets remain preserved.
The iOS source feed has its own prerelease and never represents a backend release.

[Release workflow and versions](RELEASE_VERSIONING.md) ·
[Maintenance scope](MAINTENANCE_2026_10_12.md).
