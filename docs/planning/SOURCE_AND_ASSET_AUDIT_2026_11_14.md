# Source and asset audit — 14 November 2026

## Data and provider use

| Source | Current use | Audit decision |
| --- | --- | --- |
| OFF India source bundle | Verified read-only catalogue, indexed search and dated product facts | Preserve 24,641 indexed products, compressed input, licenses and hashes; no refresh or migration in this release |
| Static research observations | Separate exact-identity research search/detail and provenance | Preserve 243 immutable observations and their independent receipt |
| Source image descriptors | Remote official/manufacturer image URLs with evidence references | Keep 120 descriptors separate from facts; no image-byte bundling or decorative package substitution |
| FSSAI/reviewed knowledge and glossary | Deterministic qualified claim/ingredient explanations | Retain reviewed references, versions and unresolved/missing states |
| Community/machine streams | Identity-checked, immutable qualified observations with conflict retention | Preserve original admission, ownership, deduplication and receipt boundaries |
| OFF live / NutriGraph | Optional bounded provider lookups | Existing caches, single-flight and quotas retained; vendor connectivity/coverage is not inferred from a configured key |
| Gemini/OpenAI | Optional consented extraction through the backend | No frontend keys, raw-photo persistence, custom training or fabricated evidence |
| OCR/barcodes | Local/native OCR and self-hosted web OCR/ZXing before optional cloud reads | Preserve lazy engine loading, camera cancellation and session-only captures |

Frontend public-read caches already have TTL/LRU bounds and coalesce concurrent
reads. Search thumbnail requests are limited to two and obsolete query work is
not started. NutriGraph already coalesces lookups, bounds request admission and
expires temporary observations without extending provider retention. Broadly
caching private/confirmed results or vendor facts would weaken existing evidence
or ownership boundaries and was not introduced.

## Asset improvements

- Auth PNG masters are retained under `frontend/design_sources/artwork/auth/`;
  runtime WebP files preserve identical RGBA pixels/dimensions. A regular-weight
  wordmark-only font replaces the complete variable serif at runtime; its full
  licensed source remains available for reproducible authoring.
- These five runtime assets shrink from **5,601,583 to 2,716,814 bytes**. The
  build additionally stops bundling unused Nunito/Quicksand runtime fonts
  (**401,756 bytes**); their sources/licenses remain for offline icon authoring
  and historical provenance.
- The unused old scanner garden PNG (**1,442,755 bytes**) is removed from the
  runtime/source asset bundle. It is not referenced by a production widget.
  Historical Git versions retain the original generation provenance.
- Combined runtime reduction: **4,729,280 bytes**, before archive compression.
  `scripts/release/optimize_ui_assets.py --check` verifies retained/derived hashes;
  regeneration also checks every decoded RGBA pixel. No artwork is regenerated.
- Warmup now prioritizes only Welcome while Welcome is visible, and Home's
  relevant public illustrations afterward. History/Saved/Sources artwork loads
  when used. No private photo or product image enters decorative warmup.
- Removed dead profile comparison-total plumbing and the notification placeholder.
  Builds, caches, snapshots, downloaded tools, local databases and screenshots
  remain ignored. Public source bundles, source licenses, contracts and useful
  developer preview tools remain intentional tracked inputs.

## Screen review coverage

Shared typography/surface/navigation changes apply across Home, scanner, product
search, product information, comparisons, Saved/History, Insights/readers,
Sources/details, Welcome, recovery and account screens. Full Flutter checks cover
responsive overflow, 2x text, stationary shells, keyboard/navigation behavior,
camera lifecycle and ownership. Actual auth/profile captures cover phone, tablet
portrait/landscape and laptop in both themes. New notifications have a separate
responsive, persistence and cancellation suite. Physical device/Safari rendering,
camera accuracy and real OS notification acceptance remain separate evidence.
