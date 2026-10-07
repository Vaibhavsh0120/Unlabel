import 'dart:math';

import 'app_failure.dart';
import 'product_report.dart';

String newSubmissionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String? _optional(String? input) =>
    input == null || input.trim().isEmpty ? null : input.trim();
// Layout line breaks are represented as spaces; no words are dropped or inferred.
String _labelText(String input) =>
    input.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();

class DraftSection {
  const DraftSection({
    this.status = 'not_captured',
    this.text = '',
    this.complete = false,
  });
  final String status;
  final String text;
  final bool complete;

  JsonMap toJson() {
    if (!const ['present', 'not_observed', 'not_captured'].contains(status)) {
      throw const AppFailure(
        'invalid_input',
        'Choose how each package section was captured.',
      );
    }
    final value = _labelText(text);
    if (status == 'present' && (value.isEmpty || value.length > 16000)) {
      throw const AppFailure(
        'invalid_input',
        'Enter the whole printed text for each present section (up to 16,000 characters).',
      );
    }
    return {
      'status': status,
      'text': status == 'present' ? value : null,
      'completeness': status != 'not_captured' && complete
          ? 'complete'
          : 'partial',
      'origin': 'independently_transcribed_package',
    };
  }
}

class DraftBasis {
  const DraftBasis({this.kind = 'quantity', this.amount, this.unit});
  final String kind;
  final double? amount;
  final String? unit;

  JsonMap toJson() {
    if (!const ['quantity', 'serving'].contains(kind) ||
        ((amount == null) != (unit == null)) ||
        (kind == 'quantity' && amount == null) ||
        (amount != null &&
            (!amount!.isFinite || amount! <= 0 || amount! > 100000)) ||
        (unit != null && !const ['g', 'mL'].contains(unit))) {
      throw const AppFailure(
        'invalid_input',
        'Enter the table’s printed basis, such as 100 g, or choose a serving with unknown size.',
      );
    }
    return {'kind': kind, 'amount': amount, 'unit': unit};
  }
}

class DraftNutrient {
  const DraftNutrient({required this.name, this.value, required this.unit});
  static const names = [
    'energy',
    'fat',
    'saturated_fat',
    'carbohydrates',
    'carbohydrates_total',
    'sugars',
    'added_sugars',
    'fibre',
    'protein',
    'sodium',
    'salt',
  ];
  final String name;
  final double? value;
  final String unit;

  JsonMap toJson(int index, DraftBasis basis, String preparation) {
    final energy = name == 'energy';
    if (!names.contains(name) ||
        !(energy ? const ['kcal', 'kJ'] : const ['g', 'mg', 'ug']).contains(
          unit,
        ) ||
        (value != null &&
            (!value!.isFinite || value! < 0 || value! > 1000000))) {
      throw const AppFailure(
        'invalid_input',
        'Nutrient values must be nonnegative numbers with the printed unit. Leave an unreadable value empty.',
      );
    }
    return {
      'row_id': 'row-${index + 1}',
      'table_id': 'back-panel',
      'nutrient': name,
      'value': value,
      'unit': unit,
      'basis': basis.toJson(),
      'preparation': preparation,
    };
  }
}

/// Independent package transcription, including corrected local OCR suggestions.
/// No catalogue data is accepted as
/// copied public package evidence. One instance keeps its UUID across retries.
class LabelDraft {
  LabelDraft({
    required this.name,
    this.brand,
    this.variant,
    this.quantity,
    this.barcode,
    this.language = 'en',
    this.ingredients = const DraftSection(),
    this.contains = const DraftSection(),
    this.mayContain = const DraftSection(),
    List<String> claims = const [],
    List<DraftNutrient> rows = const [],
    this.basis = const DraftBasis(),
    this.preparation = 'as_sold',
    this.nutritionComplete = false,
    this.foodCategory = 'unknown',
    this.foodForm = 'unknown',
    this.frontConfirmed = false,
    this.backConfirmed = false,
    this.samePackageConfirmed = false,
    this.captureMethod = 'manual',
    String? submissionId,
    DateTime? observedAt,
  }) : submissionId = submissionId ?? newSubmissionId(),
       observedOn = (observedAt ?? DateTime.now())
           .toUtc()
           .toIso8601String()
           .substring(0, 10),
       claims = List.unmodifiable(claims),
       rows = List.unmodifiable(rows);

  final String name;
  final String? brand, variant, quantity, barcode;
  final String language;
  final DraftSection ingredients, contains, mayContain;
  final List<String> claims;
  final List<DraftNutrient> rows;
  final DraftBasis basis;
  final String preparation;
  final bool nutritionComplete,
      frontConfirmed,
      backConfirmed,
      samePackageConfirmed;
  final String foodCategory, foodForm;
  final String captureMethod;
  final String submissionId, observedOn;

  JsonMap toPayload() {
    if (name.trim().isEmpty ||
        name.trim().length > 256 ||
        [
          _optional(brand),
          _optional(variant),
          _optional(quantity),
        ].any((item) => item != null && item.length > 128) ||
        !const ['en', 'hi'].contains(language)) {
      throw const AppFailure(
        'invalid_input',
        'Enter the printed product name and check the identity fields.',
      );
    }
    final code = _optional(barcode);
    if (code != null &&
        !RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$').hasMatch(code)) {
      throw const AppFailure(
        'invalid_input',
        'Use an 8, 12, 13 or 14 digit barcode, or leave it empty.',
      );
    }
    if (!frontConfirmed || !backConfirmed || !samePackageConfirmed) {
      throw const AppFailure(
        'invalid_input',
        'Confirm the product front, corrected back-label facts, and that they belong to the same package.',
      );
    }
    if (!const ['manual', 'ocr_corrected'].contains(captureMethod) ||
        !const ['as_sold', 'as_prepared'].contains(preparation) ||
        !const [
          'ordinary_general_food',
          'special_food',
          'unknown',
        ].contains(foodCategory) ||
        !const ['solid', 'liquid', 'unknown'].contains(foodForm) ||
        rows.length > 64 ||
        rows.map((row) => row.name).toSet().length != rows.length ||
        claims.length > 16 ||
        claims.any(
          (claim) => claim.trim().isEmpty || claim.trim().length > 256,
        )) {
      throw const AppFailure(
        'invalid_input',
        'Check the table, product context and printed claims. Each nutrient may appear once in this table.',
      );
    }
    final sections = [
      ingredients.toJson(),
      contains.toJson(),
      mayContain.toJson(),
    ];
    if (rows.isEmpty &&
        sections.every((section) => section['status'] == 'not_captured')) {
      throw const AppFailure(
        'invalid_input',
        'Capture at least one back-package section or nutrient row.',
      );
    }
    return {
      'schema_version': '1',
      'observation': {
        'schema_version': '1',
        'barcode': code,
        'identity': {
          'name': name.trim(),
          'brand': _optional(brand),
          'variant': _optional(variant),
          'quantity': _optional(quantity),
          'language': language,
        },
        'ingredients': sections[0],
        'contains': sections[1],
        'may_contain': sections[2],
        'front_claims': claims.map((value) => value.trim()).toList(),
        'rows': [
          for (var index = 0; index < rows.length; index++)
            rows[index].toJson(index, basis, preparation),
        ],
        'nutrition_completeness': nutritionComplete ? 'complete' : 'partial',
        'nutrition_origin': 'independently_transcribed_package',
        'provider_references': <JsonMap>[],
        'revision_context': null,
        'observed_on': observedOn,
        'capture_method': captureMethod,
        'share_license': 'CC0-1.0',
        'market': 'india',
        'submission_id': submissionId,
        'observation_state': 'confirmed',
        'confirmed': true,
        'front_confirmed': frontConfirmed,
        'back_confirmed': backConfirmed,
        'same_product_confirmed': samePackageConfirmed,
      },
      'selected_table_id': rows.isEmpty ? null : 'back-panel',
      'context': {
        'food_category': foodCategory,
        'form': foodForm,
        'preparation': preparation,
      },
    };
  }
}
