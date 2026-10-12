/// Reviewed editorial guidance, separate from product observations and reports.
/// Pictures are illustrations, and an article never establishes product safety,
/// allergy suitability, legal compliance or the contents of a current package.
enum InsightTopic {
  all('All'),
  sugar('Sugar'),
  fibre('Fibre'),
  protein('Protein'),
  claims('Claims'),
  ingredients('Ingredients'),
  tips('Tips'),
  swaps('Swaps');

  const InsightTopic(this.label);
  final String label;
}

class InsightSection {
  const InsightSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

class InsightSource {
  const InsightSource({required this.title, required this.url});
  final String title;
  final String url;
}

class InsightArticle {
  const InsightArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.topic,
    required this.readMinutes,
    required this.sections,
    required this.takeaway,
    required this.sources,
    this.quickTip = false,
  });

  final String id;
  final String title;
  final String summary;
  final InsightTopic topic;
  final int readMinutes;
  final bool quickTip;
  final List<InsightSection> sections;
  final String takeaway;
  final List<InsightSource> sources;
  String get asset => 'assets/artwork/insights/$id.webp';
  String get reviewedOn => '9 October 2026';
}

const _labelSource = InsightSource(
  title: 'FSSAI: Labelling and Display Regulations, Version VIII (2025)',
  url: 'https://fssai.gov.in/upload/uploadfiles/files/Comp_Labelling%20Display_Version%20VIII_09_09_2025.pdf',
);
const _claimsSource = InsightSource(
  title: 'FSSAI: Advertising and Claims Regulations, Version IV (2022)',
  url: 'https://www.fssai.gov.in/upload/uploadfiles/files/Compendium_Advertising_Claims_Regulations_14_12_2022.pdf',
);
const _dietSource = InsightSource(
  title: 'WHO: Healthy diet',
  url: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
);
const _carbohydrateSource = InsightSource(
  title: 'WHO: Guidance on fats and carbohydrates (2023)',
  url: 'https://www.who.int/news/item/17-07-2023-who-updates-guidelines-on-fats-and-carbohydrates',
);
const _sodiumSource = InsightSource(
  title: 'WHO: Sodium reduction',
  url: 'https://www.who.int/news-room/fact-sheets/detail/sodium-reduction',
);
const _additiveSource = InsightSource(
  title: 'Codex Alimentarius: Food additive functional classes',
  url: 'https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-functional-classes',
);

class InsightCatalogue {
  static const articles = <InsightArticle>[
    InsightArticle(
      id: 'added-sugar',
      title: 'Understanding added sugar',
      summary:
          'Learn what added sugar means and how to spot it on food labels.',
      topic: InsightTopic.sugar,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Start with the added sugar row',
          body: 'Added sugar describes sugar put into a food or drink. The nutrition table can declare it separately from total sugars. Find both rows on your current package, then check the amount of food the table describes before comparing numbers.',
        ),
        InsightSection(
          heading: 'Try a label calculation',
          body: 'Imagine a table declares 12 g total sugars and 8 g added sugars per 100 g. Those are separate facts about the same amount. Do not add them together: added sugar is already included in total sugars. These invented numbers are a reading example, not a product report.',
        ),
        InsightSection(
          heading: 'Keep missing information unknown',
          body: 'If only total sugars is readable, it does not establish the added sugar amount. Check the ingredient list for context and look for a clearer table. Unlabel should keep an unreadable or missing row unknown rather than estimate it from a product name.',
        ),
      ],
      takeaway: 'Read total sugars and added sugars separately on the same printed basis.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'total-sugar',
      title: 'Total sugar tells a different story',
      summary:
          'See why a total sugar number does not reveal how much was added.',
      topic: InsightTopic.sugar,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'One total, several possible sources',
          body: 'A total sugars value covers the sugars present in the food, including sugars that may already occur in its ingredients. An added sugars value describes a different part of that total. Milk or fruit in a recipe does not make every sugar in the finished product added sugar.',
        ),
        InsightSection(
          heading: 'Compare the actual rows',
          body: 'Two products can have the same total sugars and different declared added sugars. Put their labels side by side and write down both rows per 100 g, per 100 ml or another matching amount. If one row is absent, keep that comparison incomplete.',
        ),
        InsightSection(
          heading: 'Names cannot replace the table',
          body: 'A fruit picture, a milk ingredient or the word natural cannot tell you the total sugar quantity in a particular packet. Use the declared numbers, unit and basis. If a catalogue record differs from the label in your hand, retain the disagreement and check the current package.',
        ),
      ],
      takeaway: 'An ingredient story and a nutrition quantity answer different questions.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'sugar-names',
      title: 'Sugar has more than one name',
      summary: 'Recognise syrup, honey and other sugar ingredients without guessing amounts.',
      topic: InsightTopic.sugar,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Read beyond the word sugar',
          body: 'Ingredient lists may name glucose, sucrose, honey, molasses or syrups. FSSAI uses these as examples when explaining sugar non-addition claims. A different ingredient name does not automatically turn a sweetening ingredient into a sugar-free choice.',
        ),
        InsightSection(
          heading: 'Notice the full list',
          body: 'A recipe may list several sweet ingredients separately. Read to the end, including bracketed ingredients inside chocolate pieces, fillings or other compound ingredients. Finding a name gives context, but the list alone does not let you calculate grams of total or added sugars.',
        ),
        InsightSection(
          heading: 'Use the table for quantity',
          body: 'After spotting an unfamiliar name, return to the nutrition table. Record total sugars and added sugars with their printed basis. Do not convert the position of a syrup in the list into a percentage, and do not assume a sweet taste proves any particular sugar quantity.',
        ),
      ],
      takeaway: 'Recognise sugar ingredients, then use declared rows for their quantities.',
      sources: [_claimsSource, _labelSource],
    ),
    InsightArticle(
      id: 'sugary-drinks',
      title: 'Check the whole drink',
      summary: 'A small per-100 ml number can add up across a bottle.',
      topic: InsightTopic.sugar,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'The bottle and the table may differ',
          body: 'Find the volume printed beside the nutrition values, then the bottle volume. In an invented example, 6 g sugars per 100 ml becomes 18 g for 300 ml if you drink all of it. This calculation needs a clear volume and a matching liquid basis.',
        ),
        InsightSection(
          heading: 'No added sugar is a separate question',
          body: 'WHO includes sugars in fruit juice within its free-sugars definition, even when no sugar has been added. Free sugars and the added sugars row on a package are different concepts. Keep the terms separate instead of treating a no-added-sugar statement as a zero-sugar number.',
        ),
        InsightSection(
          heading: 'Choose using the amount you drink',
          body: 'If you compare drinks, start with equal volumes. You can then calculate the amount for your glass or bottle when its volume is known. Water is a simple alternative to a sweetened drink; do not assign a sugar number to an unmeasured homemade drink.',
        ),
      ],
      takeaway: 'Check the basis, the bottle volume and the amount you actually drink.',
      sources: [_labelSource, _dietSource],
    ),
    InsightArticle(
      id: 'fibre-foods',
      title: 'Finding fibre in everyday foods',
      summary: 'Look for whole grains, pulses, fruit and vegetables across your meals.',
      topic: InsightTopic.fibre,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Think across food groups',
          body: 'WHO points to whole grains, vegetables, fruits and pulses as sources of naturally occurring dietary fibre. Oats and lentils are useful examples to recognise. This general food guidance cannot tell you how many grams of fibre are in a particular branded breakfast or ready meal.',
        ),
        InsightSection(
          heading: 'Try one familiar addition',
          body: 'Look at a meal you already eat. Could you include a vegetable, a pulse dish or a whole-grain option that fits your preferences? Start with something available and affordable. The illustration offers an idea; it is not an exact recipe, serving instruction or measured nutrition table.',
        ),
        InsightSection(
          heading: 'Check packaged food separately',
          body: 'For a cereal or snack, look for a declared fibre value and its basis. If the fibre row is missing, keep it unknown. The appearance of oats on the front does not establish the fibre amount of the whole product or justify filling a missing row with generic oat data.',
        ),
      ],
      takeaway: 'Use food groups for meal ideas and the current label for a packaged food value.',
      sources: [_carbohydrateSource, _labelSource],
    ),
    InsightArticle(
      id: 'whole-grains',
      title: 'Look closer at whole grains',
      summary: 'Read the grain ingredients rather than rely on a brown colour or packet picture.',
      topic: InsightTopic.fibre,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Look for a named grain',
          body: 'Whole grains are one of the food groups highlighted in WHO carbohydrate guidance. On a packaged bread or cereal, read how the grain ingredient is actually described. A brown colour, rustic name or picture of grain does not identify its quantity in the recipe.',
        ),
        InsightSection(
          heading: 'Read any printed proportions',
          body: 'If the package prints a percentage for a grain, keep that percentage attached to the named ingredient. If no proportion is available, do not invent it from the ingredient order. Compare two packets using the actual wording rather than assume all multigrain products have the same ingredients.',
        ),
        InsightSection(
          heading: 'Finish with the nutrition table',
          body: 'A grain description and a fibre quantity are separate facts. Check any declared fibre row on a matching basis, along with the other information you want to compare. Leave missing fibre values unknown and do not give an overall health rating from the grain name alone.',
        ),
      ],
      takeaway: 'A named ingredient, its proportion and a fibre value are three distinct facts.',
      sources: [_carbohydrateSource, _labelSource],
    ),
    InsightArticle(
      id: 'fibre-labels',
      title: 'What a fibre claim can tell you',
      summary:
          'Read a fibre claim with the declared number and its amount of food.',
      topic: InsightTopic.fibre,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'A claim names one property',
          body: 'FSSAI sets specific conditions for nutrient-content claims such as source of fibre or high fibre. Seeing that wording is a reason to inspect the supporting information. It does not establish every other nutrient value or turn a packet into an overall health or allergy verdict.',
        ),
        InsightSection(
          heading: 'Bring the number back to the portion',
          body: 'Imagine a label declares 8 g fibre per 100 g. For a known 25 g amount, proportional arithmetic gives 2 g. Keep the original row visible beside your calculation. These invented values demonstrate how the printed basis affects the amount you read.',
        ),
        InsightSection(
          heading: 'Do not fill in the gaps',
          body: 'A claim with an unreadable table is incomplete evidence in Unlabel. Check a clearer image or the physical package. A fibre-rich generic ingredient cannot supply a missing number for the finished packet, and an old catalogue value should not silently replace a conflicting current label.',
        ),
      ],
      takeaway:
          'Check the claim, the declared fibre row and the portion separately.',
      sources: [_claimsSource, _labelSource],
    ),
    InsightArticle(
      id: 'protein-basics',
      title: 'Protein comes from varied foods',
      summary: 'Look beyond a protein badge and read the whole product label.',
      topic: InsightTopic.protein,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'One nutrient in a varied diet',
          body: 'Protein supplies building blocks used by the body. WHO notes that protein can come from both plant and animal foods. A lentil bowl and an egg are familiar examples; their illustration cannot supply a measured protein value for your meal.',
        ),
        InsightSection(
          heading: 'Read a packaged food as a whole',
          body: 'For a packaged snack, find the declared protein grams and their basis. Then read the other rows relevant to your comparison, such as sugars or sodium. A large protein word on the front does not answer those separate questions about the same product.',
        ),
        InsightSection(
          heading: 'Keep needs and label facts separate',
          body: 'The table describes the food; it does not calculate your personal daily requirement. Unlabel does not infer that you need a supplement or that a higher-protein packet is suitable for everyone. Use your current package for quantities and personalised professional guidance when you need an individual plan.',
        ),
      ],
      takeaway: 'Check the protein amount without treating one nutrient as an overall verdict.',
      sources: [_dietSource, _labelSource],
    ),
    InsightArticle(
      id: 'protein-portions',
      title: 'Put protein in portion context',
      summary:
          'A per-100 g headline and the amount you eat are different views.',
      topic: InsightTopic.protein,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Find the denominator',
          body: 'A protein number needs an amount of food beside it. Is it per 100 g, per serving or per pack? Imagine 20 g protein per 100 g of a product. That does not mean every small packet or spoonful contains 20 g of protein.',
        ),
        InsightSection(
          heading: 'Calculate only with a known amount',
          body: 'In that invented example, a measured 30 g portion would contain 6 g protein by proportional calculation. Write down the portion and keep the original table basis. If the portion weight is unknown, show the printed value instead of pretending a household spoon has an exact weight.',
        ),
        InsightSection(
          heading: 'Compare like with like',
          body: 'For two packaged foods, compare declared protein on the same basis before looking at your intended portions. Keep dry and prepared values separate. Adding milk or another ingredient changes the finished meal, and the packet table does not automatically describe that new combination.',
        ),
      ],
      takeaway: 'A protein figure becomes useful when its food amount and preparation basis are clear.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'claim-check',
      title: 'Claim check basics',
      summary:
          'Learn how to read front-of-pack claims with their supporting facts.',
      topic: InsightTopic.claims,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Identify the exact statement',
          body: 'Start with the words actually printed: high protein, reduced sugar or no added salt, for example. FSSAI distinguishes different kinds of claims and sets conditions for their use. A general impression from colours or a sporty picture is not the same as a specific statement.',
        ),
        InsightSection(
          heading: 'Find what supports it',
          body: 'Turn to the nutrition table, ingredient list and any nearby explanation. A reduced claim needs a comparison context; a nutrient amount needs its unit and basis. If the supporting part of the label is unreadable, keep the claim unverified rather than mark it as a pass.',
        ),
        InsightSection(
          heading: 'Keep the conclusion narrow',
          body: 'Even a well-supported claim concerns a particular property. It cannot establish allergy suitability, your current package condition or every other nutritional quality. Unlabel can show the statement and its evidence without declaring the product approved or giving it a universal score.',
        ),
      ],
      takeaway: 'Read the exact claim, find its evidence and keep the conclusion specific.',
      sources: [_claimsSource],
    ),
    InsightArticle(
      id: 'no-added-sugar',
      title: 'No added sugar is not zero sugar',
      summary: 'Check the total sugars row even when a packet makes a non-addition claim.',
      topic: InsightTopic.claims,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Read the wording precisely',
          body: 'A no-added-sugar statement concerns sugar addition. FSSAI allows such claims under specific conditions and recognises that naturally occurring sugars may still be present. This differs from a sugar-free claim, which has its own conditions. Keep the phrases distinct.',
        ),
        InsightSection(
          heading: 'Look at total sugars too',
          body: 'Find the total sugars row and its printed basis. An invented product could show 0 g added sugars and 7 g total sugars per 100 g; those numbers are not automatically contradictory. If either number is absent, do not supply it from the front claim alone.',
        ),
        InsightSection(
          heading: 'Check all parts of the package',
          body: 'Read any naturally-occurring-sugars statement, ingredients and preparation instructions. The presence of a claim does not prove it satisfies every applicable rule. Unlabel keeps the package wording and declared values as separate evidence, especially when different sources disagree.',
        ),
      ],
      takeaway: 'No added sugar and sugar-free answer different questions; check the total sugars row.',
      sources: [_claimsSource, _labelSource],
    ),
    InsightArticle(
      id: 'front-back-labels',
      title: 'Turn the packet around',
      summary: 'Connect a front-of-pack message with the details elsewhere on the label.',
      topic: InsightTopic.claims,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Start with a question',
          body: 'A front image may attract attention to fruit, grains or protein. Decide what you want to know: the named ingredient, a declared proportion or a nutrient amount. Then look for the relevant information elsewhere on the same packet instead of answering from its illustration.',
        ),
        InsightSection(
          heading: 'Match the supporting detail',
          body: 'An ingredient list explains composition; a nutrition table gives declared quantities; preparation instructions explain how to use the product. Read any qualifications close to the claim. FSSAI requires claims to be meaningful and consistent with the label, but Unlabel does not establish regulatory compliance from appearance.',
        ),
        InsightSection(
          heading: 'Keep the current packet in view',
          body: 'Use the exact variant and quantity you are holding. A website photograph or old scan may show another version. When a current label and a stored record differ, preserve both sources and their dates; a familiar brand name is not enough to resolve the disagreement.',
        ),
      ],
      takeaway: 'Let the front prompt a question, then find its specific evidence on the label.',
      sources: [_labelSource, _claimsSource],
    ),
    InsightArticle(
      id: 'ingredient-order',
      title: 'Reading ingredient lists',
      summary:
          'Understand ingredient order and the smaller lists inside a recipe.',
      topic: InsightTopic.ingredients,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Order gives composition context',
          body: 'FSSAI generally requires ingredients to appear in descending order of their amount at manufacture, by weight or volume as applicable. Start at the beginning and continue to the end. Position gives context, but it does not supply an exact percentage for every ingredient.',
        ),
        InsightSection(
          heading: 'Read the brackets',
          body: 'A filling, seasoning or chocolate component can have its own ingredients listed in brackets. Keep those words attached to their parent ingredient. Do not mistake a component list for the order of the entire product, and do not merge two differently described recipes into one list.',
        ),
        InsightSection(
          heading: 'Keep unclear words visible',
          body: 'If a scan cuts off the end of a list or misreads a word, check the package rather than silently repair it with a guess. For an unfamiliar additive, look up its technological function separately. Ingredient order alone cannot determine product safety or allergy suitability.',
        ),
      ],
      takeaway: 'Read the whole list, keep bracketed ingredients together and never infer unprinted amounts.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'additive-functions',
      title: 'Why an additive is in the recipe',
      summary: 'Learn what words such as emulsifier and stabilizer describe.',
      topic: InsightTopic.ingredients,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'A function describes a job',
          body: 'Codex groups additives by technological function. An emulsifier helps form or maintain an emulsion; a thickener increases viscosity; a stabilizer helps keep components dispersed. These names explain a role in food making. They do not describe a universal health effect.',
        ),
        InsightSection(
          heading: 'Keep the ingredient identity',
          body: 'Read the exact name or INS number and any declared functional class together. Similar names and different suffixes can refer to different entries. If Unlabel does not have a reviewed entry for that exact ingredient, the explanation should remain unavailable rather than borrow one from a similar-looking word.',
        ),
        InsightSection(
          heading: 'Function is one piece of evidence',
          body: 'A function explanation does not establish the amount used, permission for that food category or personal allergy suitability. Keep those questions separate. You can understand why a recipe may need texture or separation control without labelling an unfamiliar ingredient automatically good or bad.',
        ),
      ],
      takeaway: 'Learn the technological role without turning it into a safety or permission verdict.',
      sources: [_additiveSource, _labelSource],
    ),
    InsightArticle(
      id: 'allergen-statements',
      title: 'Read allergen wording carefully',
      summary: 'Check the current package and keep uncertain or missing details unresolved.',
      topic: InsightTopic.ingredients,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Find the specific statement',
          body: 'Look for the allergen declaration on your actual package, then read its ingredient list. FSSAI provides allergen-labelling requirements and distinguishes a contains declaration from may-contain wording for cross-contamination. Record the exact words; do not collapse them into the same statement.',
        ),
        InsightSection(
          heading: 'Absence is not assurance',
          body: 'A cut-off photo, missing catalogue field or OCR failure cannot establish that an allergen is absent. A vegetarian symbol also does not answer every allergy question. If the label is unclear or your required information is unavailable, treat the question as unresolved.',
        ),
        InsightSection(
          heading: 'Check each new package',
          body: 'Variants and recipes can differ, so keep the precise package identity attached to the wording you read. Unlabel does not issue an allergy-safe verdict from an article, image or older record. For a food allergy, follow your clinician’s plan and contact the manufacturer when package information is uncertain.',
        ),
      ],
      takeaway: 'Use exact current-package wording; incomplete information cannot establish allergy suitability.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'serving-size',
      title: 'Start with the serving size',
      summary: 'Read the amount behind a nutrition number before using it.',
      topic: InsightTopic.tips,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Find the table basis first',
          body: 'Look above or beside the numbers for per 100 g, per 100 ml, per serving or per pack. Keep that phrase with every nutrient value. A number without its amount of food is incomplete, even when the unit beside the nutrient is clearly readable.',
        ),
        InsightSection(
          heading: 'A serving is not always a packet',
          body: 'Check the serving measure and the number of servings printed on the package. In an invented example, a 60 g packet could list a 30 g serving. If you use all 60 g, that is two of those label servings; it does not change the printed serving size.',
        ),
        InsightSection(
          heading: 'Keep preparation separate',
          body: 'Some values describe dry food and others describe food prepared according to instructions. Do not mix the two bases. If you add another ingredient or prepare a different amount, keep the original table and your calculation separate rather than relabel a printed value.',
        ),
      ],
      takeaway: 'Read the basis, the serving measure and the number of servings before the nutrient rows.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'same-amount',
      title: 'Compare the same amount',
      summary: 'Make nutrition comparisons useful by matching their units and basis.',
      topic: InsightTopic.tips,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Match food amounts',
          body: 'A 20 g serving and a 50 g serving describe different amounts of food. Before comparing their nutrient numbers, find a shared basis such as per 100 g. Keep solids in grams and liquids in millilitres unless you have reliable information for a conversion.',
        ),
        InsightSection(
          heading: 'Try a fair comparison',
          body: 'Imagine product A lists 4 g sugar per 20 g serving, while B lists 6 g per 50 g serving. On a 100 g basis, A is 20 g and B is 12 g by proportional arithmetic. Simply comparing 4 with 6 would hide the serving-size difference.',
        ),
        InsightSection(
          heading: 'Respect incompatible evidence',
          body: 'Only calculate when the printed basis and quantity are known. Dry versus prepared food, mismatched variants or missing nutrient rows may make a comparison incomplete. Show that limit instead of averaging conflicting values or treating a missing row as zero.',
        ),
      ],
      takeaway: 'Match the nutrient, unit, food amount and preparation basis before comparing.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'sodium-salt',
      title: 'Sodium and salt use different units',
      summary: 'Keep milligrams of sodium separate from grams of salt.',
      topic: InsightTopic.tips,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Read the row and the unit',
          body: 'Sodium is a component of salt, but sodium and salt values are not interchangeable. WHO gives 2 g sodium as equivalent to 5 g salt. A package may declare sodium in milligrams; do not compare that number directly with a salt value in grams.',
        ),
        InsightSection(
          heading: 'Keep conversions labelled',
          body: 'For an invented example, 400 mg sodium is 0.4 g sodium, equivalent to about 1 g salt using the 2.5 factor. If you make that calculation, label it as a calculated salt equivalent and keep the original sodium row with its printed food basis.',
        ),
        InsightSection(
          heading: 'Compare the complete amounts',
          body: 'Compare sodium values for equal food amounts before considering the portions you use. Do not infer the sodium quantity from how salty something tastes or from the position of salt in the ingredient list. Missing sodium information should stay unknown.',
        ),
      ],
      takeaway: 'Read sodium in its printed unit, and clearly label any calculated salt equivalent.',
      sources: [_sodiumSource, _labelSource],
    ),
    InsightArticle(
      id: 'snack-portions',
      title: 'Smart snack label tips',
      summary: 'Check the portion you plan to eat before comparing two snacks.',
      topic: InsightTopic.tips,
      readMinutes: 2,
      quickTip: true,
      sections: [
        InsightSection(
          heading: 'Pause at the portion',
          body: 'Before using a snack’s table, check whether it describes a serving or the whole pack. A bowl in an illustration is not a measured serving. If you know the amount you plan to eat, keep that amount separate from the packet’s printed reference.',
        ),
        InsightSection(
          heading: 'Use two views of the same label',
          body: 'A matching per-100 g basis helps compare products. Your known portion helps interpret what you actually eat. Keep both views visible: a small declared serving should not make an unequal comparison look fair, and a large pack does not have to equal one occasion.',
        ),
        InsightSection(
          heading: 'Let the rest of the label help',
          body: 'Read the ingredients and the nutrient rows relevant to your choice. If you combine a snack with fruit or plain yogurt, that makes a new meal; the snack label alone cannot describe its totals. Choose familiar options that fit your needs without assigning the combination an invented score.',
        ),
      ],
      takeaway: 'For a snack, check the printed basis, your known portion and the rest of the label.',
      sources: [_labelSource],
    ),
    InsightArticle(
      id: 'everyday-swaps',
      title: 'Small everyday food swaps',
      summary:
          'Choose one practical change and check what it actually changes.',
      topic: InsightTopic.swaps,
      readMinutes: 2,
      sections: [
        InsightSection(
          heading: 'Start with a clear aim',
          body: 'WHO favours unsaturated fats over saturated fats and describes a varied eating pattern. That can inspire a practical swap, such as using a small amount of an unsaturated oil in a recipe. It does not mean one pictured ingredient gives every person the same benefit.',
        ),
        InsightSection(
          heading: 'Make a comparison you can explain',
          body: 'For two packaged dips or spreads, compare the same amount and read the ingredients and relevant nutrient rows. Name the particular change you can support, such as a lower declared sodium value on a matched basis. Keep missing rows and other differences visible.',
        ),
        InsightSection(
          heading: 'Choose a repeatable change',
          body: 'Pick a change that fits your budget, food preferences and routine. A homemade avocado dip is only an illustration here, not a measured recipe or universal healthier replacement. If you change ingredients, the old packet table cannot become the nutrition table of your new dish.',
        ),
      ],
      takeaway: 'Choose an achievable swap and describe its supported difference rather than an overall score.',
      sources: [_dietSource, _labelSource],
    ),
  ];

  static InsightArticle? byId(String id) {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  /// Same four throughout the device's local calendar day, including restart.
  /// Date-seeded shuffling chooses four distinct topics and one article in each.
  /// This is editorial rotation, not personalized dietary advice or tracking.
  static List<InsightArticle> daily(DateTime date) {
    final local = date.toLocal();
    final random = _DailyShuffle(
      local.year * 10000 + local.month * 100 + local.day,
    );
    final topics = InsightTopic.values
        .where((topic) => topic != InsightTopic.all)
        .toList();
    random.shuffle(topics);
    final picks = <InsightArticle>[];
    for (final topic in topics.take(4)) {
      final choices = articles
          .where((article) => article.topic == topic)
          .toList();
      picks.add(choices[random.next(choices.length)]);
    }
    random.shuffle(picks);
    return List.unmodifiable(picks);
  }
}

/// Park-Miller generator uses exact integer ranges on both Dart VM and web.
/// Explicit algorithm avoids depending on platform Random implementation order.
class _DailyShuffle {
  _DailyShuffle(int seed) : _state = (seed ^ 0x45d9f3b) % 2147483646 + 1;
  int _state;

  int next(int max) {
    _state = (_state * 48271) % 2147483647;
    return _state % max;
  }

  void shuffle<T>(List<T> values) {
    for (var index = values.length - 1; index > 0; index--) {
      final other = next(index + 1);
      final value = values[index];
      values[index] = values[other];
      values[other] = value;
    }
  }
}
