# Frontend v0.6.0+7: automatic scans and reference layouts

Production checkpoint, 8 October 2026. Implementation/source commit
`6403517b11ea150cd43fdf37469911a5aaafa926` is pushed after review/docs and READY at
`dpl_DFqy6kZQDRbhHdBSAmbLQ2xEhL7P`, assigned to
`https://unlabel-india.vercel.app`. All **54 read-only hosted checks** passed,
including the five fresh artwork assets, corrected inline model headers and all
21 OCR asset hashes. The [production receipt](../research/FRONTEND_V0_6_0_PRODUCTION.json)
does not establish physical camera accuracy or hosted AI generation.

The user's subsequent short-window sidebar/insight and Profile editor corrections
are tracked separately in [frontend v0.6.1](FRONTEND_V0_6_1_REVIEW.md).

The previous frontend v0.5.0+6 implementation remains at
`00ae175993aa1cf435c3ff9ec9c8ee05cef94005`, with observed READY deployment
`dpl_AscVhThAEqDPsd3E1REiFbpMLbPB`, 49 hosted checks and all 21 OCR asset hashes.
Its [production receipt](../research/FRONTEND_V0_5_0_PRODUCTION.json) excludes this
local redesign and physical camera/recognition evidence.

## Implemented behavior

- Desktop Home has a 240 px sidebar, top search/Profile/notification controls,
  botanical scan banner, four working shortcuts, educational insight and actual
  recent scans or a useful empty state. The supplied desktop references guide
  its composition. Mobile retains Home / Scan / Compare / Saved in that order.
- A captured barcode is decoded locally and checked against the catalogue before
  any photo-transfer consent, AI request or OCR load. A known catalogue report
  opens directly. Research-only barcode matches remain explicit source candidates;
  ambiguous or missing identities are never silently merged.
- Front/back captures begin reading automatically. The normal Enter package label
  route and manual barcode sheet have been removed. Unknown products request a
  clearer or missing photo instead of mandatory transcription.
- Optional backend Gemini/OpenAI extraction requires visible transfer consent.
  Unavailable or declined cloud reading falls back to conservative local OCR.
  Browser OCR reuses a warm worker across a short capture session and releases it
  on inactivity, cancellation or completion. Camera initialization does not wait
  for interrupted-gallery recovery or OCR/model startup.
- Detected normalized photo regions and actual barcode decoder anchors are drawn
  over the captured image with contain-fit mapping. The primary action changes to
  View results when useful information is available. These are post-capture
  highlights; continuous live-feed recognition is not implemented.
- Product results follow the supplied identity card, mint botanical summary,
  findings/claims, nutrition, ingredients, declarations and sources hierarchy.
  Mobile stacks these cards; desktop uses a main and supporting column. The
  summary counts available facts and preserves evidence states, rather than
  presenting the illustrative 85/100 or a fabricated Good Choice verdict.
- A session front photograph can appear in the current result. Sourced product
  photos use validated descriptors; missing images have an honest fallback.
  Photos and raw OCR remain outside saved reports and private account sync.
- Optional one-tap acceptance creates a separate confirmed structured observation.
  Both package sides and a usable identity are required. Unknown preparation or
  multiple tables need a choice; duplicate nutrient names and bounded qualifiers
  do not become exact public rows. A barcode disagreement blocks acceptance.

Fresh artwork was generated for desktop Home, its empty state, the result botanical
decoration and the corrected pale mint sidebar leaves. Its dimensions, hashes and
generation provenance are in the [artwork record](../../frontend/assets/artwork/README.md).
Decorative barcodes and packages are never product evidence or database identities.

## Verification state

The final full suite passed **207 Flutter tests**, six browser OCR bridge tests,
clean Flutter analysis and a release web build. Desktop result navigation invokes
every destination; acceptance retries retain one observation ID and never post
before confirmation. Cancellation aborts client upload/waits without replay.
Barcode/checksum, local fallback, immutable parsing, qualified-row acceptance,
stale response, camera lifecycle and responsive result regressions are present.

Home, current report, researched product, extracted result and captured Scan
were rendered at **390/1440/1728 px** and compared with the user's references.
The dense old botanical/sidebar and busy initial hero were replaced with fresh
reference artwork; desktop vertical gaps were tightened, mobile fact rows grouped,
and the result header adapted to the desktop reference. This is a source-dependent
Flutter adaptation, not pixel equality or a reproduction of illustrative health scores.
The [render review](../research/FRONTEND_V0_6_0_RENDER.json) records screenshots,
measured visible semantics and the limitations of canvas geometry. A passing widget or web fixture does not establish physical
Android/iOS camera startup, real-package OCR accuracy or the 3–5 second target.

The warm known-product 3–5 second journey is a measurement target. Cold permission,
camera, asset download, network and unknown-package reading remain separate cases.
Cancellation currently suppresses late session results and releases local work;
it does not prove cancellation of a provider request already admitted by the backend.

See the [automatic scan plan](AUTOMATIC_SCAN_PLAN.md),
[backend v0.12 local review](BACKEND_V0_12_0_REVIEW.md) and
[interface contract](../../DESIGN.md).

The pinned Flutter web SDK does not implement encoded ImageDescriptor dimensions.
A bounded shared decoder replaces that unsupported path in barcode, OCR, photo
preparation and highlight geometry. Actual browser ZXing decoded the owned EAN-13
8901764051258 with two anchors; photo preparation and Tesseract recognized the
owned label name, ingredients and nutrition. The local preview intercepted gzipped
model responses as downloads; the corrected test supplied the identical verified
model bytes inline. Production and the standard preview now specify inline binary
model headers without Content-Encoding. This fixture is separate from real-package
accuracy, native permission/camera time and hosted provider generation.

[Warm decoder benchmark](../research/AUTOMATIC_SCAN_SYNTHETIC_PERFORMANCE.json):
cold 60.653 ms; warm p50 2.89 ms, p95 9.976 ms, using in-process HTTP and cache.
It proves barcode-first/no-photo-upload ordering, not internet or shop scan latency.
