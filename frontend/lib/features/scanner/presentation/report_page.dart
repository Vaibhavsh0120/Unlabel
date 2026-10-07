import 'package:flutter/material.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import 'ui_components.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.report,
    required this.store,
    required this.onChanged,
    super.key,
  });

  final ProductReport report;
  final LocalStore store;
  final VoidCallback onChanged;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _saved = false;
  bool _saving = false;
  bool _checkingSaved = true;
  String? _savedError;

  @override
  void initState() {
    super.initState();
    _readSaved();
  }

  Future<void> _readSaved() async {
    setState(() {
      _checkingSaved = true;
      _savedError = null;
    });
    try {
      final items = await widget.store.saved();
      if (mounted) {
        setState(
          () => _saved = items.any((item) => item.id == widget.report.id),
        );
      }
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() => _savedError = error.userMessage);
      }
    } finally {
      if (mounted) setState(() => _checkingSaved = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (_saving || _checkingSaved || _savedError != null) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        await widget.store.removeSaved(widget.report.id);
      } else {
        await widget.store.save(widget.report);
      }
      if (!mounted) return;
      setState(() => _saved = !_saved);
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _saved ? 'Saved on this device' : 'Removed from saved products',
          ),
        ),
      );
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Label report')),
      body: PageBody(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.name, style: theme.textTheme.headlineMedium),
                if (report.brand?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.brand!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (report.variant?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(report.variant!),
                ],
                if (report.quantity?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(report.quantity!),
                ],
                if (report.barcode != null) ...[
                  const SizedBox(height: 8),
                  Text('Barcode ${report.barcode}'),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const Key('save-report'),
                  onPressed: _saving || _checkingSaved || _savedError != null
                      ? null
                      : _toggleSaved,
                  icon: _saving || _checkingSaved
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
                  label: Text(
                    _checkingSaved
                        ? 'Checking saved status…'
                        : _saving
                        ? 'Saving…'
                        : _saved
                        ? 'Saved · remove'
                        : 'Save on this device',
                  ),
                ),
                if (_savedError != null) ...[
                  const SizedBox(height: 12),
                  Text('Saved status could not be loaded. $_savedError'),
                  TextButton(
                    onPressed: _readSaved,
                    child: const Text('Retry saved status'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeatureIcon('leaf', size: 32),
                const SizedBox(height: 16),
                Text(
                  report.basisLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.isHistorical
                      ? 'These are dated catalogue observations. They may differ from the package in your hand.'
                      : 'This report uses the package facts you confirmed. Missing or conflicting facts stay unknown.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Nutrition snapshot'),
          if (report.nutrients.isEmpty)
            const StatusNotice(
              title: 'Nutrition is not available',
              message: 'No usable printed nutrient rows were found. Check the nutrition table on your package.',
            )
          else
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < report.nutrients.length;
                    index++
                  ) ...[
                    _NutrientRow(report.nutrients[index]),
                    if (index < report.nutrients.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          if (report.sugar != null) ...[
            const SectionTitle('Sugar in context'),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About ${_number(report.sugar!.cubes)} sugar cubes',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_number(report.sugar!.grams)} g total sugars · ${report.sugar!.basisLabel}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'An approximate visual conversion using 4 g per cube. Total sugar alone does not tell us how much sugar was added.',
                  ),
                ],
              ),
            ),
          ],
          const SectionTitle('Ingredients & allergens'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Declaration('Ingredients', report.ingredients),
                const Divider(),
                _Declaration('Contains', report.contains),
                const Divider(),
                _Declaration('May contain', report.mayContain),
                const SizedBox(height: 16),
                Text(
                  'Missing allergen information does not mean allergy-safe. Read the current package.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => IngredientPage(report: report),
                    ),
                  ),
                  icon: const FeatureIcon('document-text', size: 20),
                  label: const Text('Explore ingredient functions'),
                ),
              ],
            ),
          ),
          const SectionTitle('Package claims'),
          if (report.claims.isEmpty)
            StatusNotice(
              title: report.isHistorical
                  ? 'Current claims need the current label'
                  : 'No front claims captured',
              message: report.isHistorical
                  ? 'Catalogue nutrient values cannot establish claims on a current package.'
                  : 'Enter the printed front claims with enough back-label facts to check them.',
            )
          else
            for (final claim in report.claims) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(claim.text, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      _human(claim.status),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(claim.reason),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          if (!report.isHistorical) ...[
            const SectionTitle('Catalogue update'),
            StatusNotice(
              title: _storageTitle(report.storageStatus),
              message: _storageMessage(report.storageStatus),
            ),
          ],
          if (report.missingInputs.isNotEmpty ||
              report.warnings.isNotEmpty) ...[
            const SectionTitle('What is still unknown'),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in <dynamic>{
                    ...report.missingInputs,
                    ...report.warnings,
                  })
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('• ${_human(item)}'),
                    ),
                ],
              ),
            ),
          ],
          const SectionTitle('Sources & evidence'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.sourceLabels.isEmpty)
                  const Text('Source details are unavailable in this report.')
                else
                  for (final source in report.sourceLabels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(source),
                    ),
                const SizedBox(height: 8),
                const Text(
                  'These explanations describe the supplied label facts. They do not establish a health score, allergy safety or regulatory compliance.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow(this.nutrient);

  final ReportNutrient nutrient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_human(nutrient.name), style: theme.textTheme.titleMedium),
            Text(
              nutrient.value == null
                  ? _human(nutrient.state)
                  : '${_number(nutrient.value!)} ${nutrient.unit}',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          nutrient.basisLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (nutrient.evidenceState != null) ...[
          const SizedBox(height: 8),
          Text(
            _evidence(nutrient.evidenceState!),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (nutrient.observedOn != null) ...[
          const SizedBox(height: 6),
          Text('Observed ${nutrient.observedOn}'),
        ],
        if (nutrient.sourceUpdatedAt != null) ...[
          const SizedBox(height: 6),
          Text('Source updated ${nutrient.sourceUpdatedAt}'),
        ],
        if (nutrient.sourceIds.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Source references'),
            children: [
              for (final source in nutrient.sourceIds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(source),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Declaration extends StatelessWidget {
  const _Declaration(this.title, this.section);

  final String title;
  final ReportSection section;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        section.text ??
            '${_human(section.status)} — check the current package.',
      ),
      if (section.completeness == 'partial') ...[
        const SizedBox(height: 8),
        const Text('This declaration was only partially captured.'),
      ],
      if (section.evidenceState != null) ...[
        const SizedBox(height: 8),
        Text(_evidence(section.evidenceState!)),
      ],
      if (section.sourceIds.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Source references'),
          children: [
            for (final source in section.sourceIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(source),
                ),
              ),
          ],
        ),
    ],
  );
}

class IngredientPage extends StatelessWidget {
  const IngredientPage({required this.report, super.key});

  final ProductReport report;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ingredient insights')),
    body: PageBody(
      children: [
        StatusNotice(
          title: 'What an ingredient does',
          message: 'These entries explain technological functions such as thickening or emulsifying. They do not establish health effects, allergy safety or permission for an Indian food category.',
          icon: Icons.menu_book_outlined,
        ),
        const SectionTitle('Matched ingredient functions'),
        if (report.ingredientInsights.isEmpty)
          const StatusNotice(
            title: 'No glossary match for this label',
            message: 'The current glossary covers three reviewed entries. An unmatched ingredient is unknown, not harmful or safe.',
          )
        else
          for (final insight in report.ingredientInsights) ...[
            Card(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                title: Text(insight.name),
                subtitle: Text('Label text: ${insight.matchedText}'),
                children: [
                  if (insight.nameHi != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        insight.nameHi!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(insight.function),
                  ),
                  if (insight.functionHi != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(insight.functionHi!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Source references: ${insight.sourceIds.join(', ')}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        const SectionTitle('Printed ingredient declaration'),
        SectionCard(child: _Declaration('Ingredients', report.ingredients)),
      ],
    ),
  );
}

String _number(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _human(String value) {
  final text = switch (value) {
    'sugars' => 'Total sugars',
    'added_sugars' => 'Added sugars',
    'energy' => 'Energy',
    _ => value.replaceAll('_', ' '),
  };
  return text.isEmpty
      ? 'Unknown'
      : '${text[0].toUpperCase()}${text.substring(1)}';
}

String _evidence(String value) => switch (value) {
  'open_food_facts_community_data' => 'Open Food Facts community observation',
  'submitter_confirmed_not_moderator_reviewed' =>
    'Submitter confirmed, unreviewed',
  'moderator_accepted_community_assertion' =>
    'Community assertion with recorded acceptance',
  'user_confirmed_label' => 'Your confirmed label',
  _ => _human(value),
};

String _storageTitle(String status) => switch (status) {
  'saved' => 'Structured facts saved automatically',
  'rate_limited' => 'Catalogue update limit reached',
  'conflict' => 'Conflicting catalogue facts',
  'needs_correction' => 'Some facts need correction',
  'authentication_required' => 'Automatic catalogue update could not sign in',
  _ => 'Catalogue update is unavailable',
};

String _storageMessage(String status) => switch (status) {
  'saved' => 'Your confirmed structured package facts were stored. Qualified community facts retain their evidence state; photos and raw text extraction are not shared.',
  'rate_limited' => 'The analysis is available. The structured catalogue update could not be saved within the current free-tier limits.',
  'conflict' => 'The analysis is available. Disagreements remain unresolved; one source is not silently substituted for another.',
  'needs_correction' => 'The analysis is available. Recheck the printed values before these facts can enter the shared catalogue.',
  'authentication_required' => 'The analysis is available. Automatic scanner sign-in failed, so structured facts were not saved.',
  _ => 'The analysis is available. Structured facts could not be stored at this time.',
};
