# Six reviewed ingredient functions

Reviewed **8 October 2026**. The current official Codex GSFA individual records
were checked for exact names, INS codes and technological functions. The earlier
three-entry `backend/app/reports/glossary-v1.json` remains historical; v0.9.0 loads
the separate six-entry `glossary-v2.json`, version `ingredients-2026-10-08.1`.

| Entry | INS | Reviewed function used | Official record |
| --- | --- | --- | --- |
| Lecithin | 322(i) | Emulsifier | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=117ae6b8-249a-f111-b8dc-70a8a5613865) |
| Citric acid | 330 | Acidity regulator | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=d8e9e6be-249a-f111-b8dc-70a8a5613865) |
| Xanthan gum | 415 | Thickener and stabilizer | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=f979e6b8-249a-f111-b8dc-70a8a5613865) |
| Guar gum | 412 | Thickener and stabilizer | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=cf79e6b8-249a-f111-b8dc-70a8a5613865) |
| Sodium benzoate | 211 | Preservative | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=0deae6be-249a-f111-b8dc-70a8a5613865) |
| Potassium sorbate | 202 | Preservative | [Codex GSFA](https://codex.fao.org/codex-texts/codex-online-databases/gsfa/food-additives-list/food-additive-details?additiveId=d379e6b8-249a-f111-b8dc-70a8a5613865) |

The migrated `codex.fao.org` pages returned HTTP 200 during this review. Earlier
`www.fao.org/gsfaonline` URLs returned 403 to the available fetchers; historical
receipts retain their original references. The new projection uses the verified
canonical record URLs. Review date is not a regulatory publication/effective date.

Only factual identifiers/functions and independently authored English/Hindi
explanations are projected. No source HTML, logo, complete article or GSFA database
is bundled. The project does not claim a blanket Creative Commons licence or FAO
endorsement; broader copying/adaptation requires its own rights review under
[FAO terms](https://www.fao.org/contact-us/terms/en/). English/Hindi descriptions
explain the reviewed functions; they are not official Codex translations.

The bounded projection is 5,741 bytes with SHA-256
`dcddf20de8627d14b94c796683412b01665afc27b9d8d0cbb41a6f3e908fe1ce`.
The loader independently pins canonical reviewed-content SHA-256
`51f1029fbaf07f0f677c73a22c8a20af4354bd2977ba5c6b5d7aa54ff429766e`,
so whitespace may change without allowing altered evidence/explanations under
the same version. Runtime responses retain their actual raw hash/byte/count.
Names, codes, aliases, own-source references and review dates are validated.
Callers receive independent copies of entries and source models.

Coverage remains partial: six entries do not establish Indian-market ingredient
coverage, safety, allergy status, Indian permission, nutritional benefit or a
product verdict. Unsupported subtypes and similar Unicode prefixes do not match;
unknown text remains unchanged. Requests read only the bundled projection and
perform no remote evidence fetch, image upload or paid service operation.
