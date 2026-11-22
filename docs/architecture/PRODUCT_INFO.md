# One product information destination

`frontend/lib/features/scanner/presentation/product_info_page.dart` owns
`ProductInfoPage`, the destination for scanning, catalogue search, research
matches, history and saved products. Its report/research/extracted/barcode
constructors select private content widgets, with one page title and navigation
shell. Product results reuse `ShellPage` and `ShellNavigation`, including the
normal desktop sidebar/header and compact Home/Scan/Compare/Saved navigation.
Search stays inside that shell too. Desktop result routes have no whole-page
transition. Research search rows load the same validated image descriptor as
the detail page; cross-origin web images use Flutter's HTML-image fallback.
Missing source photos remain unavailable rather than using decorative art.

The approved Label Studio redesign uses a forest product identity band,
neutral image inset, Save/Compare actions, sticky section navigation, four mint
nutrient tiles, ingredient and sugar cards, and a compact evidence summary.
Desktop uses three columns; phone and enlarged text stack cards inside the same
shell. Section navigation scrolls to content rather than replacing the facts.
Full tables, claim checks, allergens, glossary, conflicts and source notes remain
available. Reviewed, researched and machine-read pages share this composition.

Source-specific facts remain distinct. A dated catalogue snapshot is not a
current-package check; a model reading is not human-confirmed. Original source
sections, nutrition bases, claims, allergens, ingredient explanations and sugar
approximations retain the existing report contracts. Missing fields remain unknown.

Front/back extraction searches both indexed catalogues by the read name. The
person selects a matching brand, variant and pack size; the app does not choose
an arbitrary first result. Barcode-only capture opens a known report/research
record or an unknown-product view that can request optional live sources.

Public machine readings are separate additions with provider/date and explicit
conflict information. Their creation belongs to the backend's validated automatic
admission path, never a client-created confirmed draft.

The NutriGraph integration was removed at the operator's request after its
refreshed key failed the documented lookup and alias. Product results use the
licensed catalogue, research, Open Food Facts, community and separate machine
readings. No request to the retired vendor is made.

Photographed front claims travel with the explicit candidate selection. The
read-only `POST /v1/claims/catalogue-check` sends the selected barcode and claim
text, never uploaded nutrition or a fabricated confirmation flag. The backend
compares exact sourced numbers with reviewed criteria. Product category/form and
current-package context remain unknown, so the overall claim remains insufficient;
numeric comparisons and original source/table references are visible separately.


## Reusable design prompt

> Redesign Unlabel's product result page as Label Studio, keeping its forest
> green, mint, white and dark themes, Manrope headings and Inter body text.
> Retain the desktop sidebar and search/profile header; retain mobile
> Home/Scan/Compare/Saved navigation. Build a forest identity band with a neutral
> product-image inset, name, brand, variant, pack quantity, barcode, Save and
> Compare. Below it, place sticky Overview, Nutrition, Ingredients, Claims and
> Sources tabs that scroll to sections. Use a desktop bento layout with four
> mint nutrient tiles (energy, protein, total sugars, fat), a readable ingredient
> card, a sugar illustration using approximately 4 g per cube on the original
> table basis, and a compact evidence summary. Below, include every original
> nutrition table with basis, units and qualifiers; Contains/May contain;
> claim criteria and evidence; ingredient-function glossary; source links,
> dates, conflicts and missing facts. On mobile, stack the same cards with
> comfortable touch targets and no horizontal page overflow. Respect enlarged
> text and light/dark themes. Unknown is unknown, never zero. Distinguish dated
> sources, confirmed package facts and unverified machine readings. Do not
> invent scores, health/allergy-safety verdicts, compliance claims or product
> photos. Preserve the app's actual data and functional actions.
