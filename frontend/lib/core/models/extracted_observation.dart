import 'extracted_label.dart';
import 'label_draft.dart';

/// A human acceptance creates a distinct confirmed observation. Machine output
/// never sets confirmation flags by itself. Qualified bounds remain in private
/// staging and on the extraction screen; they cannot become exact public rows.
LabelDraft? acceptedLabelDraft(
  ExtractedLabel label, {
  String? barcode,
  String? preparation,
  int tableIndex = 0,
}) {
  final name = label.identity['name'] as String?;
  if (name == null) return null;
  final printedBarcode = label.identity['barcode'] as String?;
  if (barcode != null && printedBarcode != null && barcode != printedBarcode) {
    return null;
  }
  if (label.nutritionTables.isNotEmpty &&
      (tableIndex < 0 || tableIndex >= label.nutritionTables.length)) {
    return null;
  }
  String? short(String key) {
    final value = label.identity[key] as String?;
    return value != null && value.length <= 128 ? value : null;
  }

  final table = label.nutritionTables.isEmpty
      ? null
      : label.nutritionTables[tableIndex];
  final selectedPreparation = preparation ?? table?['preparation'];
  if (table != null &&
      !const ['as_sold', 'as_prepared'].contains(selectedPreparation)) {
    return null;
  }
  final rows = <DraftNutrient>[];
  if (table != null) {
    final counts = <String, int>{};
    for (final row in table['rows'] as List) {
      counts.update(row['nutrient'], (count) => count + 1, ifAbsent: () => 1);
    }
    for (final row in table['rows'] as List) {
      if (!const ['exact', 'unknown'].contains(row['qualifier']) ||
          counts[row['nutrient']] != 1) {
        continue;
      }
      rows.add(
        DraftNutrient(
          name: row['nutrient'],
          unit: row['unit'],
          value: (row['value'] as num?)?.toDouble(),
        ),
      );
    }
  }
  if (rows.isEmpty &&
      label.ingredients == null &&
      label.contains == null &&
      label.mayContain == null) {
    return null;
  }
  DraftSection section(String? value) => value == null
      ? const DraftSection()
      : DraftSection(status: 'present', text: value, complete: false);
  return LabelDraft(
    name: name,
    brand: short('brand'),
    variant: short('variant'),
    quantity: short('quantity'),
    barcode: barcode ?? label.identity['barcode'],
    ingredients: section(label.ingredients),
    contains: section(label.contains),
    mayContain: section(label.mayContain),
    claims: label.frontClaims,
    rows: rows,
    basis: table == null
        ? const DraftBasis()
        : DraftBasis(
            kind: table['basis']['kind'],
            amount: (table['basis']['amount'] as num?)?.toDouble(),
            unit: table['basis']['unit'],
          ),
    preparation: selectedPreparation ?? 'as_sold',
    captureMethod: 'ocr_corrected',
    frontConfirmed: true,
    backConfirmed: true,
    samePackageConfirmed: true,
  );
}
