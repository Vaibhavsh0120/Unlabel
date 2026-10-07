# Unlabel decorative artwork


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
