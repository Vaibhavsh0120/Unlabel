import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/interaction/ui_feedback.dart';
import 'report_presentation.dart';
import 'product_results_layout.dart';
import 'ui_components.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.report,
    required this.store,
    required this.onChanged,
    this.sessionPhoto,
    this.navigation,
    super.key,
  });

  final ProductReport report;
  final LocalStore store;
  final VoidCallback onChanged;
  // Never serialized into history, saved products or account synchronization.
  final Uint8List? sessionPhoto;
  final ResultsNavigation? navigation;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
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
      unawaited(UiFeedback.confirmed());
      widget.onChanged();
      _messenger.currentState!.showSnackBar(
        SnackBar(
          content: Text(
            _saved ? 'Saved on this device' : 'Removed from saved products',
          ),
        ),
      );
    } on AppFailure catch (error) {
      if (mounted) {
        _messenger.currentState!.showSnackBar(
          SnackBar(content: Text(error.userMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _saveAction() => OutlinedButton.icon(
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
  );

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final theme = Theme.of(context);
    final photo = ReportImageDescriptor.fromReport(report);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: ResultsAppBar(
          title: 'Scan Results',
          navigation: widget.navigation,
        ),
        body: ProductResultsLayout(
          main: [
            SectionCard(
              key: const Key('report-product-card'),
              padding: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductIdentity(
                    report: report,
                    photo: photo,
                    sessionPhoto: widget.sessionPhoto,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _saveAction(),
                      if (report.barcode != null)
                        Text(
                          'Barcode ${report.barcode}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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
            const SizedBox(height: 16),
            _ReportSummary(report: report),
            const SectionTitle('Evidence at a glance'),
            _EvidenceOverview(report: report),
            const SectionTitle('Claim check'),
            if (report.claims.isEmpty)
              StatusNotice(
                title: report.isHistorical
                    ? 'Current claims need the current label'
                    : 'No front claims captured',
                message: report.isHistorical
                    ? 'Catalogue nutrient values cannot establish claims on a current package.'
                    : 'Photograph the front and back labels to check printed claims.',
              )
            else
              SectionCard(
                padding: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < report.claims.length;
                      index++
                    ) ...[
                      _ClaimRow(report.claims[index]),
                      if (index < report.claims.length - 1) const Divider(),
                    ],
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
              _NutritionSnapshot(nutrients: report.nutrients),
            if (report.sugar != null) ...[
              const SectionTitle('Sugar reality'),
              _SugarReality(sugar: report.sugar!),
            ],
          ],
          aside: [
            _IngredientPreview(report: report),
            const SizedBox(height: 16),
            ResultsAllergenNotice(
              contains: report.contains.text,
              mayContain: report.mayContain.text,
            ),
            const SectionTitle('Ingredients & allergens'),
            SectionCard(
              padding: 18,
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
                padding: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in <String>{
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
              padding: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.sourceLabels.isEmpty)
                    const Text('Source details are unavailable in this report.')
                  else
                    for (final source in report.sourceLabels)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ResultsSelectableText(source),
                      ),
                  if (photo != null) ...[
                    const SizedBox(height: 4),
                    ResultsSelectableText(
                      '${photo.attribution} · ${photo.license}',
                    ),
                    ResultsSelectableText(photo.licenseUrl),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'These explanations describe the supplied label facts. They do not establish a health score, allergy safety or regulatory compliance.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductIdentity extends StatelessWidget {
  const _ProductIdentity({
    required this.report,
    required this.photo,
    this.sessionPhoto,
  });
  final ProductReport report;
  final ReportImageDescriptor? photo;
  final Uint8List? sessionPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final size = constraints.maxWidth < 450 ? 76.0 : 100.0;
        final fallback = Semantics(
          label: 'Product photo unavailable',
          child: const Center(child: FeatureIcon('document-text', size: 32)),
        );
        final picture = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: size,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerLow,
              child: sessionPhoto != null
                  ? Image.memory(
                      sessionPhoto!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Your current package photo',
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : photo == null
                  ? fallback
                  : Image.network(
                      photo!.url,
                      fit: BoxFit.contain,
                      semanticLabel:
                          'Product photo of ${report.name}. ${photo!.attribution}. ${photo!.license}.',
                      loadingBuilder: (_, image, progress) =>
                          progress == null ? image : fallback,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.name, style: theme.textTheme.titleLarge),
            if (report.brand?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                report.brand!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (report.variant?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(report.variant!),
            ],
            if (report.quantity?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                report.quantity!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
        return largeText && constraints.maxWidth < 500
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [picture, const SizedBox(height: 12), copy],
              )
            : Row(
                children: [
                  picture,
                  const SizedBox(width: 16),
                  Expanded(child: copy),
                ],
              );
      },
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});
  final ProductReport report;

  @override
  Widget build(BuildContext context) => ResultsSummaryCard(
    key: const Key('report-evidence-summary'),
    count: report.nutrients.where((item) => item.value != null).length,
    heading: report.isHistorical ? 'Dated catalogue facts' : 'Confirmed label',
    message: report.isHistorical
        ? 'Dated observations may differ from the package in your hand.'
        : 'Your confirmed facts, with missing or conflicting information kept unknown.',
    qualification:
        'Recorded values describe this label; they are not a health score.',
  );
}

class _EvidenceOverview extends StatelessWidget {
  const _EvidenceOverview({required this.report});
  final ProductReport report;

  @override
  Widget build(BuildContext context) {
    final available = report.nutrients
        .where((item) => item.value != null)
        .length;
    final unknown = report.nutrients.length - available;
    return ResultsFactsGrid(
      children: [
        ResultsFact(
          icon: 'document-text',
          title: 'Nutrition facts',
          detail:
              '$available available${unknown == 0 ? '' : ' · $unknown unknown or unresolved'}',
          status: available > 0 ? 'Recorded' : 'Unknown',
          uncertain: available == 0,
        ),
        ResultsFact(
          icon: 'shield',
          title: 'Claim evidence',
          detail: report.claims.isEmpty
              ? 'No current-package claim assessments'
              : '${report.claims.length} recorded assessments',
          status: report.claims.isEmpty
              ? 'Not assessed'
              : 'Checked against evidence',
          uncertain: report.claims.isEmpty,
        ),
        ResultsFact(
          icon: 'leaf',
          title: 'Ingredient declaration',
          detail: report.ingredients.text == null
              ? 'No usable declaration available.'
              : report.ingredients.completeness == 'partial'
              ? 'Part of the printed declaration is available.'
              : 'The recorded ingredient text is available.',
          status: report.ingredients.text == null
              ? 'Unknown'
              : report.ingredients.completeness == 'partial'
              ? 'Partial'
              : 'Recorded',
          uncertain: report.ingredients.text == null,
        ),
        ResultsFact(
          icon: 'history',
          title: 'Package context',
          detail: report.isHistorical
              ? 'Dates and sources stay attached.'
              : 'Package context preserved.',
          status: report.isHistorical
              ? 'Dated observations'
              : 'Confirmed package facts',
          uncertain: report.isHistorical,
        ),
      ],
    );
  }
}

class _IngredientPreview extends StatelessWidget {
  const _IngredientPreview({required this.report});
  final ProductReport report;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const FeatureIcon('document-text', size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ingredient insights',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Reviewed explanations of what matched ingredients do.'),
        if (report.ingredientInsights.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('No reviewed glossary match for this label.'),
          ),
        for (final insight in report.ingredientInsights)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(insight.name),
            subtitle: Text('Label text: ${insight.matchedText}'),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(insight.function),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow(this.claim);
  final ReportClaimView claim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (claim.status) {
      'supported' => theme.colorScheme.primary,
      'contradicted' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (claim.status) {
      'supported' => Icons.check_circle_outline,
      'contradicted' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(claim.text, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _human(claim.status),
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(claim.reason),
      ],
    );
  }
}

class _NutritionSnapshot extends StatelessWidget {
  const _NutritionSnapshot({required this.nutrients});
  final List<ReportNutrient> nutrients;

  // Keep the overview short. Every row, including alternate table bases and
  // unresolved fields, remains available in the evidence disclosure below.
  List<ReportNutrient> get _overview {
    final selected = <ReportNutrient>[];
    for (final names in const [
      ['energy'],
      ['protein'],
      ['carbohydrates', 'carbohydrates_total'],
      ['fat'],
      ['sodium'],
      ['sugars'],
    ]) {
      for (final item in nutrients) {
        if (names.contains(item.name)) {
          selected.add(item);
          break;
        }
      }
    }
    return selected.isEmpty ? nutrients.take(6).toList() : selected;
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    key: const Key('report-nutrition-snapshot'),
    padding: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final minimum = largeText ? 220.0 : 110.0;
            final columns = (constraints.maxWidth / minimum).floor().clamp(
              1,
              5,
            );
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 20,
              children: [
                for (var index = 0; index < _overview.length; index++)
                  SizedBox(
                    width: width,
                    child: _SnapshotValue(_overview[index], index: index),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        ExpansionTile(
          key: const Key('report-nutrient-evidence'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: const Text('All nutrients, evidence & sources'),
          children: [
            for (var index = 0; index < nutrients.length; index++) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _NutrientRow(nutrients[index]),
              ),
              if (index < nutrients.length - 1) const Divider(),
            ],
          ],
        ),
      ],
    ),
  );
}

class _SnapshotValue extends StatelessWidget {
  const _SnapshotValue(this.nutrient, {required this.index});
  final ReportNutrient nutrient;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: Key('report-nutrient-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _human(nutrient.name),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          nutrient.value == null
              ? _human(nutrient.state)
              : '${_number(nutrient.value!)} ${nutrient.unit}',
          style: nutrient.value == null
              ? theme.textTheme.titleMedium
              : theme.textTheme.titleLarge?.copyWith(fontSize: 25),
        ),
        const SizedBox(height: 5),
        Text(nutrient.basisLabel, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SugarReality extends StatelessWidget {
  const _SugarReality({required this.sugar});
  final SugarView sugar;

  @override
  Widget build(BuildContext context) => SectionCard(
    key: const Key('report-sugar-reality'),
    padding: 18,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 550 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final artwork = SizedBox(
          width: wide ? 150 : 100,
          child: CornerArtwork(
            asset: 'assets/artwork/sugar-cubes.webp',
            height: wide ? 120 : 88,
            animate: false,
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About ${_number(sugar.cubes)} sugar cubes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${_number(sugar.grams)} g total sugars · ${sugar.basisLabel}',
            ),
            const SizedBox(height: 10),
            const Text(
              'An approximate visual conversion using 4 g per cube. Total sugar alone does not tell us how much sugar was added.',
            ),
          ],
        );
        return wide
            ? Row(
                children: [
                  artwork,
                  const SizedBox(width: 20),
                  Expanded(child: copy),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [artwork, const SizedBox(height: 8), copy],
              );
      },
    ),
  );
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
                    child: ResultsSelectableText(source),
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
                  child: ResultsSelectableText(source),
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
            message: 'This glossary covers a limited set of reviewed entries. An unmatched ingredient is unknown, not harmful or safe.',
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
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(insight.name),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Matched label text: ${insight.matchedText}',
                              ),
                              const SizedBox(height: 16),
                              if (insight.nameHi != null) Text(insight.nameHi!),
                              Text(insight.function),
                              if (insight.functionHi != null)
                                Text(insight.functionHi!),
                              const SizedBox(height: 16),
                              const Text('Reviewed source references'),
                              for (final source in insight.sourceIds)
                                SelectableText(source),
                              for (final source in report.ingredientSources(
                                insight,
                              )) ...[
                                const SizedBox(height: 8),
                                Text(source['title'] as String),
                                Text('Reviewed ${source['reviewed_on']}'),
                                SelectableText(source['url'] as String),
                              ],
                              const SizedBox(height: 16),
                              const Text(
                                'This explains a technological function. It does not establish health effects, allergy safety, ingredient quantity or permission in a food category.',
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Read ingredient evidence'),
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
