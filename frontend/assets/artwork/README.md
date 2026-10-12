## Current optimized assets — 12 October 2026

The 30 preceding illustrations still used by screens total 2,875,132 bytes,
compared with 15,806,186 bytes for their original PNGs (81.81% smaller). Ten large
decorations use WebP quality 90 and display-appropriate dimensions; the entire
canvas is resized with its aspect ratio preserved and no crop. Their alpha
channels exactly match the resized originals. All 20 Insight images retain
lossless WebP, their original dimensions and every decoded RGBA pixel.

The two distinct [History and Saved illustrations](empty-state-generation.json)
are additional lossless WebP assets, 512×341 pixels and 141,320 bytes combined.
Platform icons remain PNG. Four unused assets were removed after the user asked
for a complete artwork-use audit: desktop-insight-bowl.png, desktop-insight-banner.webp,
desktop-empty-scans.webp and label-leaf.webp. The prohibited botanical-corner
branch was also removed everywhere. Historical bytes remain in Git.

[Optimization manifest](optimized-assets.json) records original PNG paths/hashes,
current WebP paths/hashes, byte counts, per-asset encoding and dimensions, and the
source Git revision. Original PNGs remain recoverable from that revision.
For the ten resized decorations, it also records preceding lossless WebP
hashes and RGB PSNR against each resized original (34.462–45.774 dB, measured
over pixels with source alpha at least 128). Exact alpha equality and before/after
light/dark reviews complement that compression metric. The generation descriptions
and original hashes below are historical provenance; they do not identify current
WebP file bytes. No illustration was cropped or had its content replaced.

To reproduce with Pillow, open the original at the manifest's source revision
and convert to RGBA. For an Insight, save with `lossless=True, method=6,
exact=True` and compare decoded RGBA bytes. For a delivery decoration, apply
`thumbnail(bounds, Image.Resampling.LANCZOS)` using its recorded bounds, then save
with `quality=90, alpha_quality=100, lossless=False, method=6, exact=True`.
Compare dimensions and decoded alpha bytes, and review the image at its display
size. The two new library illustrations have their own generation provenance.

Sources has seven distinct new illustrations; its five introductory/source
images are recorded in [Sources provenance](sources-generation.json), with two
additional cards in [redesigned-state provenance](redesigned-state-generation.json).
The latter also records fresh Recent scans and 404 illustrations. No decorative
asset is shared between unrelated screens. The newly authored
[Recent scans botanical SVG](recent-scans-botanical.svg) is exclusive to that card.
The same product identity/avatar, app logo or article image stays consistent
where that same entity appears in navigation, a preview or its reader.

> Maintenance, 12 October 2026: unreferenced breakfast-leaf.png and
> welcome-garden.png were removed from the current bundle. Their generation
> provenance below records historical assets recoverable from older Git revisions.
> Later unused-artwork cleanup also removed desktop-insight-bowl.png from the
> current bundle. Dated receipts still identify its recoverable historical bytes.

# Unlabel decorative artwork

## Fresh desktop Home, results and corrected sidebar — 8 October 2026

These five assets were newly generated with the built-in `image_gen.imagegen`
tool for the latest supplied screens. They are not reuses of the older Welcome,
Profile or dark glossy botanical assets below. The final originals were copied
byte-for-byte into this folder; original/output equality and PNG dimensions were
checked with the standard library. The hero is opaque RGB; the four cutouts are
RGBA with transparent backgrounds. No external image service, product-photo
download, API-key fallback or post-generation bitmap editing was used.

The first desktop hero was rejected during screenshot comparison because its
busy photographic backdrop differed from the supplied pale mint reference.
`desktop-scan-hero.png` now contains the replacement described below. The sidebar
branch was generated specifically from the user's later pale mint leaf reference
and replaces the unsuitable dark dense bouquet in the desktop footer.
Final app-layout comparison is recorded separately in the
[frontend local review](../../../docs/planning/FRONTEND_V0_6_0_REVIEW.md).

| Asset | Use / composition | Dimensions | Bytes | SHA-256 |
| --- | --- | --- | --- | --- |
| desktop-scan-hero.png | Quiet left 53% for live copy/action; pale mint background and translucent botanicals; tilted beige pouch and decorative barcode on right | 2172 × 724 | 1,689,460 | 497cf524a3dd0324d4a6f43f3e79e45e30c46ea89d80c636149228bf4fde15e7 |
| desktop-insight-bowl.png | Granola/berries bowl with mint details for the reference insight banner | 1536 × 1024 | 1,844,510 | 2566adf22efdc376c52dadb49c3f59cba9b4b3800504924ed758c2ee7c6bd227 |
| desktop-empty-scans.png | Mint pouch, decorative barcode, soft leaves and small accents for a truthful empty-history state | 1536 × 1024 | 2,107,491 | c170cde9874c42861a2b1a10856fe0e46fab1ac9b814b9b510d1ee3515f38498 |
| results-botanical.png | Broad forest/translucent mint leaves on right, quiet left area; landscape replacement matching results reference | 2172 × 724 | 536,920 | 50018a4e1dd7fbca11cdb302e2d7e9c6c420592d0060131fa6c4217a976a2751 |
| sidebar-mint-leaves.png | Three airy pale mint watercolor leaves on a slender curved stem; reference sidebar footer decoration | 1026 × 1532 | 454,998 | 3cbf0e2a79e542f14de6d6b79fec5e8435dbc9a75801fd5c5ca7268bf29f9b4b |

Original built-in output IDs:

- Hero: `exec-a0f7e37b-52f7-4017-bc1d-fa3ae8d2cd93.png`.
- Insight: `exec-64c27d32-507f-446a-858f-7c854a45f0bd.png`.
- Empty scans: `exec-f7a4014e-6b70-4b47-88a3-a982424fe6ad.png`.
- Results: `exec-856d3d4b-aa1e-4929-b9a0-d17c45c8ead4.png`.
- Sidebar: `exec-06914392-eaef-4c37-9e6e-2adf54aadf8e.png`.

Generation briefs for hero/insight/empty/results summarize the requested
composition, rather than claiming to reproduce their complete original prompts:

- Hero: match the supplied desktop Home reference `codex-clipboard-f53e5e24…png`;
  keep the left 53% quiet and near white/mint, add pale translucent botanical
  shapes, and place a beige pouch tilted on the right around 71% of the width.
  Its barcode has no usable digits or product identity. Avoid a photographic
  background, nutrition/health claims, scores and baked-in UI controls.
- Insight: isolated premium bowl of granola with strawberries, blueberries and
  mint, suited to the screenshot's wide insight banner; no text, brands or UI.
- Empty scans: an isolated mint paper pouch with a decorative barcode, soft
  botanical shapes and restrained sparkle accents; no product digits, brands,
  nutritional claims or text. This decorates a genuine empty state.
- Results: landscape transparent botanical decoration with broad forest and translucent
  mint leaves growing from the right edge; quiet left area, no product, words,
  scores, factual claims or UI.

The sidebar asset used the supplied crop `codex-clipboard-9c3d9d97…png`. Its exact
generation prompt was:

~~~text
Create the sidebar botanical decoration from this reference as a transparent PNG cutout asset. Closely match ONLY its soft pale mint-green watercolor leaves and slender curved mint stem on the left edge: three elongated pointed oval leaves with understated translucent washes, faint simple veins, no dark-green glossy leaves, no photorealism, no dense bouquet, no flowers. Main branch rises from lower left and leans gently toward upper right with broad quiet empty space to its right. Use the same desaturated airy mint style as this exact reference. Include just the branch and its 3 leaves, not the small separate leaf lower right. Remove all text, underline, white background, rounded panel and UI. All non-leaf pixels must be transparent. Portrait asset with branch toward left, no shadows.
~~~

These are interface decorations, never actual catalogue images, a scanned
package, a verified GTIN, a nutrition observation or a health/safety endorsement.
Headings, buttons, footer copy, source information and result states are live
Flutter UI. Real product imagery retains its separate source URL, attribution
and reuse qualifications; generated art cannot satisfy missing-image coverage.


## Themed scan-banner backgrounds — 7 October 2026

Generated with the built-in image generation tool; no external product photograph or product record is implied. The barcode is decorative and is never used for lookup. Both PNGs are 1774 × 887 px and are used beneath live text/buttons. Their backgrounds are intentionally opaque. Their composition was visually reviewed; the dark variant changes lighting/background while retaining the light asset's package.

| File | SHA-256 | Original output |
| --- | --- | --- |
| scan-hero-light.png | 3ae23be9daf49118804374902c2ab6bc4bdadc13037c81f3f5a428317a86a352 | exec-b0d9debd-79cf-4462-a388-8980c713d365.png |
| scan-hero-dark.png | 71211363e363b1025100384fd8716575ff1e2026759980ea8bd8a0fa0bd30431 | exec-b31c0c55-b1bb-4767-8c09-4c539dc9970c.png |

Light generation prompt:

```text
Use case: product-mockup. Generate a polished wide raster BACKGROUND for Unlabel food-label scanner app hero card, landscape 2:1 composition. Inspired by elegant botanical food packaging advertising: a realistic cream paper standing oat-food pouch with deep forest-green botanical leaf print and a simple black decorative barcode framed by a soft mint scanner glow, on the RIGHTMOST 40 percent. Keep the entire pouch within that right area with a little edge breathing room; no cute mascot. A few elegant green leaves surround it. LEFT 60 percent must be almost empty very pale mint fading to warm white, quiet low contrast so live dark text and buttons can be placed there. Soft studio light, sophisticated friendly natural textures, gently dimensional. Background fills whole rectangle, no border, no rounded card, no UI, no buttons, absolutely NO TEXT, letters, numbers, claims, logos or watermark. Do not generate a screenshot; only the decorative full bleed background artwork. Make package large in right area without crossing into left copy space. Light mode palette warm white, soft mint, forest green.
```

Dark variant prompt (light output supplied as edit reference):

```text
Create the DARK MODE counterpart of this exact Unlabel app hero background. Change ONLY backdrop and lighting, preserve the same 2:1 composition, exact cream botanical pouch, its full silhouette, decorative barcode/scanner glow, rightmost 40% placement and left 60% negative space. Dark theme background should be subtle charcoal #171B1E fading to #101214, forest green leaves with a gentle mint rim glow. Left text area must be almost flat quiet charcoal for live white text with NO foreground objects there. Maintain pouch texture and brightness so it is clearly visible. No text, letters, numbers, UI, buttons, border, rounded frame, logos or watermark. Background fills rectangle. This is decorative packaging artwork, not actual product facts.
```

User refinement: complete cutout illustrations now fit within motion padding; the earlier oversize corner-cropping brief is superseded. The Home hero instead uses these full-card botanical backgrounds with reserved live-copy space.


The original two transparent illustrations were generated with the built-in ImageGen tool on 7 October 2026 for the Unlabel interface. They are bundled locally and load without an image service.

- `label-leaf.png`: cream kraft food pouch, forest green leaves, a small smiling leaf mascot, decorative barcode and mint scan brackets. Used by supporting scan/label illustrations; Home's main banner now uses the two themed backgrounds above.
- `breakfast-leaf.png`: white bowl of oats, strawberries and blueberries with a small leaf mascot and soft mint accents. Used for the educational Home insight.

Direction: cute, warm, spacious food illustration with realistic materials, transparent background, no health scores, no brand or regulatory endorsement. These images are decorative illustrations, never product evidence, catalogue photos or user scans. Actual catalogue product images retain their validated official URL descriptors.

## Additional interface cutouts — 7 October 2026

Exactly three additional raster assets were generated through the built-in `image_gen.imagegen` tool, using `transparent_background: true`. No external image service, API-key fallback, stock photography, source-image input or post-generation image editing was used. The original built-in outputs were copied byte-for-byte into this directory; SHA-256 checks identify the committed candidates. These are project-authored AI-generated decorative assets, not third-party licensed catalogue photographs, factual food observations or a regulatory endorsement.

All three outputs were visually inspected. Read-only bitmap inspection confirmed 32-bit ARGB PNGs and genuine fully transparent pixels alongside partial-alpha subject edges. The transparent alpha was preserved. Shapes can be scaled, rotated slightly and clipped inside rounded UI cards without baking a theme background into the files.

### `welcome-garden.png`

- Intended use: First-use Welcome garden cutout: cream breakfast bowl and mint/forest foliage.
- Dimensions: 1254 × 1254 px.
- SHA-256: `436a5db9a741c55c1d928924a37caa1f59677718e61edf9f80312fce1a10e9d5`.
- Original built-in output: `exec-a6773439-950f-4e05-8bc9-2beea8d7c4b1.png`.
- Transparency: 32-bit ARGB with zero-alpha background pixels; no opaque backdrop.

Final generation prompt:

```text
Use case: stylized-concept.
Asset type: transparent decorative Welcome illustration for a premium food-label app.
Primary request: A charming, cute, softly dimensional botanical food garden cutout. One tiny warm-cream ceramic breakfast bowl holding oats with a few blueberries and one strawberry, cradled by three graceful leafy stems and broad rounded mint and forest-green leaves, with a couple of small floating leaf accents. Food and plants only; no people, faces or branded packaging.
Style/medium: premium soft 3D editorial illustration, tactile matte ceramic and gently detailed leaves, friendly and calm with rounded silhouettes, polished rather than childish.
Composition/framing: square canvas, cohesive single vignette filling most of the image with breathing room around the outermost leaves, arranged in a rising garden arc; usable at a large size in a mobile welcome screen. Fully visible outer edges.
Lighting/mood: soft diffuse daylight, subtle dimensional shadows that remain inside the cutout, quiet joyful mood.
Color palette: mint #70EBBA, forest #155B4B, soft pale green, warm cream with tiny natural berry accents.
Constraints: actual transparent alpha background; no opaque square, coloured backdrop, sky, text, logo, watermark, letters, health claims or numbers.
```

### `botanical-corner.png`

- Intended use: Large botanical accent for rounded bottom/right card corners; decorative only.
- Dimensions: 1254 × 1254 px.
- SHA-256: `0167ee9683683f957e5c46aba33fed0e39072eb08c1b895d4b1ae4b96af88e93`.
- Original built-in output: `exec-982f28cd-90eb-41e7-a1bb-583b0d959079.png`.
- Transparency: 32-bit ARGB with zero-alpha background pixels; no opaque backdrop.

Final generation prompt:

```text
Use case: stylized-concept.
Asset type: transparent botanical corner artwork for a premium mobile food-label app.
Primary request: A single graceful green botanical branch with seven broad soft dimensional leaves, naturally curved stem, delicate vein detail and two small new buds. Friendly rounded leaf silhouettes, alternating forest, jade and mint greens. The stem begins at the lower right and the branch arcs gracefully toward the upper left, with the visually heaviest leaf cluster at lower right. No bowl or food.
Style/medium: premium soft 3D botanical editorial illustration, matte softly tactile leaves, elegant detailed surfaces, quiet and cute rather than childish.
Composition/framing: square canvas. Isolated entire branch with a small transparent margin; designed to be enlarged and cropped at a rounded card's bottom/right corner. Cohesive branch rather than scattered confetti. No UI elements.
Lighting/mood: gentle diffused daylight with natural soft shading entirely within the subject.
Color palette: forest #155B4B, jade, mint #70EBBA and soft pale green accents.
Constraints: genuinely transparent alpha background, no opaque coloured field, no sky, no text, logo, watermark, faces, numbers or claims.
```

### `sugar-cubes.png`

- Intended use: Three solid cubes and one dashed outline as a decorative illustration; the displayed quantity must come from the report's original basis and approximate 4 g/cube convention, not this picture.
- Dimensions: 1774 × 887 px.
- SHA-256: `6e4095b123f8059ef2e117bd0e8f6997e3632784a76bad2dcb46cc1f29aab6fa`.
- Original built-in output: `exec-34d3528a-7cb7-4fd4-b9c5-75470122d817.png`.
- Transparency: 32-bit ARGB with zero-alpha background pixels; no opaque backdrop.

Final generation prompt:

```text
Use case: scientific-educational.
Asset type: transparent sugar-cube illustration for an educational mobile food-label report card.
Primary request: Exactly THREE physical cream-white sugar cubes standing in a loose horizontal row, and ONE additional subtle dashed mint line cube outline to the right. The dashed outline has no solid fill and is clearly an illustrative guide rather than a fourth physical cube. All three solid cubes are distinct and countable, with slightly rounded edges and delicate granular sugar texture. No leaves or other food.
Style/medium: premium soft 3D editorial cutout, tactile matte sugar crystals, clean gentle dimensional form.
Composition/framing: landscape-oriented compact group on a transparent canvas, viewed from a three-quarter slightly elevated angle, fully visible cubes separated by small comfortable gaps. Plenty of transparent space above and around the outer edges. Cube outline uses restrained pale mint/forest dashed edges and same perspective as the solids.
Lighting/mood: soft warm diffuse studio daylight with subtle contact shadows limited to the cube group.
Color palette: warm off-white and cream cubes, tiny pale mint outline accent.
Constraints: actual transparent alpha background; exactly three solid sugar cubes and one empty dashed outline; no plate, opaque background, labels, numbers, text, logos, watermark, medical or nutritional claims. This is decorative illustrative artwork; no asserted quantity or serving equivalence.
```

## Reference welcome and native startup artwork — 8 October 2026

The user-selected mobile/desktop welcome and app startup references guided two project-authored raster assets made with the built-in `image_gen.imagegen` tool. Both final outputs were visually inspected and copied byte-for-byte from the default built-in destination into this directory. No external image service, API-key fallback, stock photo download, bitmap UI text or post-generation image editing was used. These illustrations are decorative and convey no real product, nutrition, safety or regulatory evidence.

| File | Use | Dimensions | SHA-256 | Original final output |
| --- | --- | --- | --- | --- |
| welcome-scan-package.png | Unframed welcome package hero on mobile and desktop; transparent alpha preserved | 1254 × 1254 px | aae2a399b29faf1b32581803fc2cf0bdb04aaec36edd1c01c3055f3e254c58a0 | exec-5420febf-95ec-4fb9-b3bc-1c89d612f27d.png |
| splash-botanical.png | Native app startup background while real startup work is pending; website has no branded loading screen | 941 × 1672 px | b62382569a2eee2c5b77c872a4c10492141a0fbbc85a09f000faf6925385a41f | exec-937c58c7-970e-417c-85ee-aecf5eee6680.png |

Read-only bitmap inspection confirmed the welcome PNG uses 32-bit ARGB, a fully transparent top-left pixel and partially transparent subject pixels. The splash is an intentionally opaque 24-bit RGB background. Wordmarks, supporting copy, actions and loading dots are rendered as live Flutter widgets; decorative barcodes are never used for lookup. The existing `botanical-corner.png` cutout supplies the welcome page edge decoration without modifying that historical asset.

Welcome hero initial prompt:

```text
Use case: stylized-concept. Asset type: square transparent hero artwork for Unlabel welcome screen. Primary request: isolated premium softly dimensional botanical food pouch illustration: one tall unbranded warm white cream paper stand-up resealable food pouch leaning slightly clockwise, visible folded bottom, subtle matte paper folds and top zipper seal. One simple mint green leaf emblem high on the pouch; one black decorative barcode lower on front surrounded by luminous bright mint green four-corner scanner brackets. Five graceful broad emerald and mint leaves on thin stems frame pouch left and right, a small floating leaf above, one tiny mint green heart upper right, two elegant mint four-point sparkle outlines and a few small mint dots. Soft translucent mint circular halo behind pouch and thin mint contact shadow below are part of the cutout. All leaves and accents fully visible with little transparent margin. Match sophisticated calm reference artwork for a food label scanner welcome, elegant soft 3D editorial illustration, delicate leaf veins, no faces or characters. Palette: dark forest #07594b, jade, mint #61cca0, pale mint halo, near-white cream pouch. Constraints: actual transparent alpha outside vignette; no opaque white square or rectangular backdrop; absolutely no text, letters, numbers, UI controls, watermarks, real brands, nutrition claims or safety scores. Only decorative product illustration, not a screenshot. Save through default built-in image output mechanism.
```

The final welcome refinement used the initial generated hero as the edit target and the user-supplied mobile welcome screenshot as a style/composition reference only:

```text
Use case: style-transfer. Image 1 is the EDIT TARGET, our transparent welcome hero asset. Image 2 is ONLY a STYLE AND COMPOSITION REFERENCE containing mobile UI; DO NOT create its text, buttons, page, or status bar. Refine Image 1 to closely match JUST the central botanical package illustration in Image 2: smooth pale WHITE lightly dimensional pouch with simple few soft folds, NO beige color, wrinkles, photoreal fabric/plastic texture, glossy metallic zipper or crumpling. Elegant illustrated cream white pouch with subtle clean side/bottom folds, slightly clockwise lean as reference. Replace pouch plant drawing with ONE simple flat mint leaf emblem. Raise and enlarge black decorative barcode/scanner brackets to the lower CENTRAL front as reference, not near bottom edge. Simplify surrounding leaves to about five clean elongated mint/forest broad leaves with subtle sparse vein lines and softly shaded 3D illustration surfaces, NO photoreal intricate veins, branched dense bushes or dark heavy foliage. Keep small floating green heart, two simple outline sparkles, mint dots, pale mint translucent circle behind package and light contact shadow. Use reference's soft mint and gentle jade palette. Preserve transparent alpha outside illustration and full vignette silhouette with clear margins. No text, numbers, wordmarks, logos except simple leaf, UI, frames, status bars or fake health claims. Output the hero illustration only, on genuine transparent background.
```

Splash background final prompt:

```text
Use case: stylized-concept. Asset type: portrait full-bleed botanical loading background for Unlabel app, about 9:16 portrait. Primary request: reproduce a very quiet soft near-white ivory/sage background with elegant pale sage botanical stems appearing only from the TOP LEFT corner and BOTTOM RIGHT corner. Top-left branch has three long translucent eucalyptus-like green leaves and extremely soft diffused leaf shadows drifting diagonally near the left edge; bottom-right branch has five slim broad pale sage leaves on a curved thin stem entering from the lower-right edge. Leaves partly cropped by canvas edges and delicate vein detail. Keep the CENTRAL 75 percent, especially middle and lower-middle, empty and smooth near-white for live dark green Unlabel logo and loading dots to be overlaid. No center objects. Match refined calm photographic botanical paper mood, not bright green cartoon. Lighting: diffuse natural daylight, subtle dreamy soft-focus botanical shadows only at corners, no vignette/dark borders. Palette: warm white #f8faf4, pale sage #b7c8b0, muted soft green. Constraints: no text, words, numbers, letters, logos, dots, loading indicators, status bar, phone frame, buttons, UI or watermark. This is only background art, all UI and branding will be rendered live. Save through default built-in image output mechanism.
```

## Profile reference artwork — 8 October 2026

Two project-authored decorative PNG assets were generated with the built-in ImageGen tool using `transparent_background: true`. Original outputs were visually inspected and copied byte-for-byte into this directory. Both have real transparent alpha. The generated avatar is anonymous placeholder artwork, never the user's photograph; botanical artwork conveys no product, nutrition or regulatory evidence. The images load locally without a paid image service. No third-party stock source or input-image reproduction was used.

### `profile-avatar.png`

- Original final output: `exec-5581eba3-8c6e-4f08-b064-7d134cb0dbb1.png`.
- SHA-256: `48797712123dc0ad933d8d4e58291739f343b22abacfd52b1d42c9926449b9bd`.
- Intended use: generic anonymous profile avatar inside a mint circular medallion.

Final built-in edit prompt (initial generic avatar was the edit target; the user's Profile screenshot supplied style guidance):

```text
Edit target: the first image, the circular anonymous illustrated avatar. Supporting style/reference: the profile screenshot in the second image, specifically its male avatar. Replace the long wavy hairstyle with the reference's short softly wavy dark forest-green male haircut and a faceless warm peach male head, with a dark green simple crew-neck T-shirt. Preserve the first image's centered shoulders-and-head composition inside a pale mint circular disc, clean smooth soft 3D editorial illustration, circular crop and transparent alpha outside the disc. Match the screenshot avatar closely: short dark hair lifted and swept slightly right, visible ears, clean-shaven smooth face without any eyes nose or mouth. No letters, no icons, no leaves, no heart, no UI, no square background. Deliver only this isolated circular avatar asset.
```

### `profile-botanical.png`

- Original output: `exec-48f8feb3-d726-4d73-8930-b2c21e6752c1.png`.
- SHA-256: `b2221f7daf6f63e55ddc53c98f73f6e484e1ba02d2c6c89077c8f8831fd38687`.
- Intended use: decorative mint/forest leaves inside Profile identity and Settings cards.

Final built-in generation prompt:

```text
Use case: stylized-concept. Asset type: isolated botanical decorative cluster for Unlabel profile identity and settings cards. Primary request: a graceful branch of seven broad elongated green leaves with softly detailed veins, three forest/jade leaves in upper right growing from lower right and four mint green leaves near bottom, tiny mint round accent dots. Style: polished softly dimensional editorial botanical illustration, clean smooth matte leaves, gentle natural shading, airy premium mobile app. Composition: square image, branch rises from bottom right toward upper right and upper center, left half mostly empty transparent space, all leaf silhouettes fully visible with small outer margin. Palette: forest #155B4B jade #318663 mint #A5E2C2. Constraints: actual transparent alpha background, no opaque backdrop, no food or people, no text, lettering, numbers, UI, logos or watermark. Calm cohesive branch, do not scatter isolated confetti.
```


## Insight banner correction — 8 October 2026

`desktop-insight-banner.png` is a fresh built-in image generation for the user's
wide Today’s Insight reference: pale mint botanical curves and a smaller cream
bowl with berries/oats at the right. It replaces the close crop in desktop Home.
It is decorative, with no product or nutrition evidence. Copied byte-for-byte;
no bitmap editing or stock image acquisition.

- Dimensions: 2172 × 724 px; 1,826,994 bytes.
- SHA-256: `80324b0733a1e5e3dca7fc7a8ea31d295a29029d81401561b6c80cdda043e67f`.
- Original output: `exec-7bb06f56-bc31-44bf-b26c-7786009b242a.png`.
- Prompt: new premium white/forest/mint wide 3:1 banner; modest right-hand cream
  granola/berry bowl, rim and food in the visible top band, quiet left space,
  translucent mint curves/leaves, no dark background, lettering or logos.
- Runtime: smaller right-hand banner slot with cover fit aligned to the top/right;
  card text remains live Flutter content and food artwork is excluded from semantics.

## Transparent insight replacement — 9 October 2026

The preceding opaque banner left a pale rectangular tile inside the dark card.
`desktop-insight-banner.png` now contains a **newly generated transparent 3:1
composition**, copied byte-for-byte from the built-in ImageGen output. The
preceding hash above identifies its historical Git revision.

- Dimensions: 2172 × 724 px, 1,837,292 bytes, 32-bit RGBA.
- SHA-256: `7935cb0e93e2e43f873980c84a127d0f2a2915de547825d63b25285d33a9e6f5`.
- Original output: `exec-9b10e2ed-b6ca-4f2a-91ab-1c33d28f3291.png`.
- True alpha is retained. Sampled corner alpha is 0–1/255; the bowl is opaque.
- Runtime uses contain fit with inner padding. The complete bowl and leaf sweep
  scale within their reserved slot. The card supplies the light/dark background;
  there is no separate opaque image panel. Live copy remains outside the art.
- Source: project-authored built-in generation, no stock images, external image
  API, provider-key fallback or post-generation bitmap editing. Decorative only.

Final built-in generation prompt (`transparent_background: true`):

```text
Use case: stylized-concept. Asset type: wide transparent decorative food illustration for the RIGHT SIDE of Unlabel's desktop Today's Insight card, roughly 3:1 landscape. Create a NEW refined editorial food-and-botanical composition on genuine transparent alpha, not a banner background: one modest warm ivory ceramic breakfast bowl with granola oats, a few bright sliced strawberries, blueberries and a sprig of mint, seen from a gentle three-quarter overhead angle; bowl and entire rim fully visible. Bowl occupies the right-center 40 percent of image width and about 80 percent of image height. A graceful low, horizontal sweep of softly shaded sage, mint and jade leaves on thin curved stems extends from behind the bowl toward the LEFT, occupying the remaining width with airy gaps and plenty of transparent space between leaves. A few leaves frame the bowl at far right, all leaf tips inside margins. Maintain about 5 percent transparent margin around the whole composition. Soft dimensional premium editorial illustration with realistic appetizing food texture and elegant restrained matte watercolor-like leaf shading, matching white/forest/mint food-label app reference. Bowl and fruit remain clear at an eventual 130 px rendered image height; avoid tiny intricate decoration. Lighting: soft natural neutral diffuse light; a subtle translucent contact shadow only beneath bowl. Strong clean silhouette and gently fading semitransparent leaf tips, suitable placed directly over BOTH a pale white/mint card and a deep charcoal forest card. Constraints: actual alpha transparent canvas; absolutely NO opaque white, cream, mint or dark rectangular background, no panel, no tile, no frame, no horizon, no background gradient, no broad filled halo, no white edge outline, no text, letters, numbers, branding, icons, UI or watermark. Do not generate a screenshot. Decorative illustration only; no product nutrition claims. Output landscape 3:1 transparent composition.
```
