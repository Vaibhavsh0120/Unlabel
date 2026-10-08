import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/unlabel_repository.dart';
import '../../../core/storage/local_store.dart';
import 'ui_components.dart';

JsonMap _map(Object? value) => value is JsonMap ? value : {};
List<dynamic> _list(Object? value) => value is List ? value : const [];
String _basisKey(JsonMap basis, String? preparation) =>
    '${basis['kind']}:${basis['amount'] is num ? (basis['amount'] as num).toDouble() : null}:${basis['unit']}:$preparation';

bool _originalRowIsUsable(Object? value) {
  final row = _map(value);
  final basis = _map(row['basis']);
  final amount = basis['amount'];
  final unit = basis['unit'];
  final nutrient = row['nutrient'];
  final number = row['value'];
  return row['table_id'] is String &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$').hasMatch(row['table_id']) &&
      const [
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
      ].contains(nutrient) &&
      const ['quantity', 'serving'].contains(basis['kind']) &&
      ((amount == null && unit == null && basis['kind'] == 'serving') ||
          (amount is num &&
              amount.isFinite &&
              amount > 0 &&
              amount <= 100000 &&
              const ['g', 'mL'].contains(unit))) &&
      const ['as_sold', 'as_prepared'].contains(row['preparation']) &&
      (number == null ||
          (number is num &&
              number.isFinite &&
              number >= 0 &&
              number <= 1000000)) &&
      (nutrient == 'energy'
          ? const ['kcal', 'kJ'].contains(row['unit'])
          : const ['g', 'mg', 'ug'].contains(row['unit']));
}

void _addValue(
  Map<String, ComparisonValue> values,
  String name,
  ComparisonValue value,
) {
  final previous = values[name];
  values[name] = previous == null
      ? value
      : previous.conflict ||
            value.conflict ||
            previous.value != value.value ||
            previous.unit != value.unit
      ? const ComparisonValue(null, null, conflict: true)
      : previous;
}

class ComparisonValue {
  const ComparisonValue(this.value, this.unit, {this.conflict = false});
  final double? value;
  final String? unit;
  final bool conflict;
  String get label => conflict
      ? 'Conflicting values'
      : value == null
      ? 'Unknown'
      : '${formatNumber(value!)} $unit';
}

/// The two products keep their own original table context. No serving size,
/// preparation, mass/volume conversion or whole-product ranking is inferred.
class ComparisonTable {
  const ComparisonTable({
    required this.id,
    required this.basis,
    required this.preparation,
    required this.values,
  });
  final String id;
  final JsonMap basis;
  final String? preparation;
  final Map<String, ComparisonValue> values;
  String get label => basisDescription(basis, preparation);

  bool compatibleWith(ComparisonTable other) =>
      const ['quantity', 'serving'].contains(basis['kind']) &&
      basis['kind'] == other.basis['kind'] &&
      basis['amount'] is num &&
      other.basis['amount'] is num &&
      basis['amount'] == other.basis['amount'] &&
      const ['g', 'mL'].contains(basis['unit']) &&
      basis['unit'] == other.basis['unit'] &&
      const ['as_sold', 'as_prepared'].contains(preparation) &&
      preparation == other.preparation;
}

List<ComparisonTable> comparisonTables(ProductReport report) {
  final grouped = <String, (JsonMap, String?, Map<String, ComparisonValue>)>{};
  if (report.isHistorical) {
    for (final item in _list(report.raw['resolved_nutrients'])) {
      final field = _map(item);
      final basis = _map(field['basis']);
      if (basis.isEmpty) continue;
      final prep = field['preparation'] is String
          ? field['preparation'] as String
          : null;
      final key = _basisKey(basis, prep);
      final entry = grouped.putIfAbsent(key, () => (basis, prep, {}));
      final name = (field['field'] as String).split('.').last;
      final selected = const [
        'single_source',
        'agreement',
      ].contains(field['state']);
      _addValue(
        entry.$3,
        name,
        ComparisonValue(
          selected && field['value'] is num
              ? (field['value'] as num).toDouble()
              : null,
          field['unit'] as String?,
          conflict: field['state'] == 'conflict',
        ),
      );
    }
  } else {
    final rows = _map(report.raw['nutrition'])['original_rows'];
    // The existing report reader validates normalized tables. This screen also
    // checks the original rows before using their unconverted values.
    if (rows is! List ||
        rows.length > 64 ||
        !rows.every(_originalRowIsUsable)) {
      return [];
    }
    for (final item in rows) {
      final row = _map(item);
      final basis = _map(row['basis']);
      final prep = row['preparation'] as String?;
      final key = '${row['table_id']}:${_basisKey(basis, prep)}';
      final entry = grouped.putIfAbsent(key, () => (basis, prep, {}));
      final name = row['nutrient'] as String?;
      if (name == null) continue;
      final value = row['value'] is num
          ? (row['value'] as num).toDouble()
          : null;
      final unit = row['unit'] as String?;
      _addValue(entry.$3, name, ComparisonValue(value, unit));
    }
  }
  return [
    for (final entry in grouped.entries)
      ComparisonTable(
        id: entry.key,
        basis: entry.value.$1,
        preparation: entry.value.$2,
        values: entry.value.$3,
      ),
  ];
}

class NutritionComparison {
  const NutritionComparison({
    required this.name,
    required this.left,
    required this.right,
    required this.compatible,
    this.sourcedDifference,
    this.sourcedSummary,
  });
  final String name;
  final ComparisonValue left;
  final ComparisonValue right;
  final bool compatible;
  final double? sourcedDifference;
  final String? sourcedSummary;
  double? get difference =>
      sourcedDifference ??
      (compatible && left.value != null && right.value != null
          ? right.value! - left.value!
          : null);
  String get summary {
    if (sourcedSummary != null) return sourcedSummary!;
    final delta = difference;
    if (left.conflict || right.conflict) {
      return 'Conflicting facts need correction';
    }
    if (left.value == null || right.value == null) {
      return 'More label information needed';
    }
    if (!compatible) return 'Different units or table basis';
    if (delta == 0) return 'Same amount';
    return '${formatNumber(delta!.abs())} ${left.unit} more in ${delta > 0 ? 'B' : 'A'}';
  }
}

List<NutritionComparison> compareTables(
  ComparisonTable? left,
  ComparisonTable? right,
) {
  final names = <String>{
    'sugars',
    'protein',
    'fibre',
    'sodium',
    'energy',
    ...?left?.values.keys,
    ...?right?.values.keys,
  };
  return [
    for (final name in names)
      NutritionComparison(
        name: name,
        left: left?.values[name] ?? const ComparisonValue(null, null),
        right: right?.values[name] ?? const ComparisonValue(null, null),
        compatible:
            left != null &&
            right != null &&
            left.compatibleWith(right) &&
            left.values[name]?.unit != null &&
            left.values[name]?.unit == right.values[name]?.unit,
      ),
  ];
}

class ComparePage extends StatefulWidget {
  const ComparePage({
    required this.store,
    required this.repository,
    this.onOpenReport,
    this.sessionReports = const [],
    super.key,
  });
  final LocalStore store;
  final UnlabelRepository repository;
  final ValueChanged<ProductReport>? onOpenReport;
  final List<ProductReport> sessionReports;
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final _reports = <ProductReport?>[null, null];
  final _tableIds = <String?>[null, null];
  final _sourceIds = <String?>[null, null];
  final _sourceOptions = <List<ComparisonOption>>[[], []];
  String _sessionId = newSubmissionId();
  int _inputRevision = 0;
  bool _comparing = false;
  SourcedComparison? _sourced;
  String? _comparisonError;

  @override
  void didUpdateWidget(ComparePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.repository != widget.repository) {
      _inputRevision++;
      _sessionId = newSubmissionId();
      _reports.fillRange(0, 2, null);
      _tableIds.fillRange(0, 2, null);
      _sourceIds.fillRange(0, 2, null);
      _sourceOptions[0] = [];
      _sourceOptions[1] = [];
      _sourced = null;
      _comparisonError = null;
      _comparing = false;
    }
  }

  @override
  void dispose() {
    _inputRevision++;
    super.dispose();
  }

  ComparisonOption? _source(int index) {
    final report = _reports[index];
    if (report == null) return null;
    return _sourceOptions[index]
        .where((option) => option.id == _sourceIds[index])
        .firstOrNull;
  }

  Future<void> _compare() async {
    final revision = ++_inputRevision;
    final a = _source(0), b = _source(1);
    setState(() {
      _sourced = null;
      _comparisonError = null;
      _comparing = a != null && b != null;
    });
    if (a == null || b == null) return;
    try {
      final result = await widget.repository.compare(
        a,
        b,
        requestId: newSubmissionId(),
        sessionId: _sessionId,
        revision: revision,
      );
      if (mounted && revision == _inputRevision) {
        setState(() => _sourced = result);
      }
    } on AppFailure catch (error) {
      if (mounted && revision == _inputRevision) {
        setState(() => _comparisonError = error.userMessage);
      }
    } catch (_) {
      if (mounted && revision == _inputRevision) {
        setState(
          () => _comparisonError =
              'The sourced amounts could not be compared. Please try again.',
        );
      }
    } finally {
      if (mounted && revision == _inputRevision) {
        setState(() => _comparing = false);
      }
    }
  }

  Future<void> _choose(int index) async {
    final store = widget.store;
    final selected = await showDialog<ProductReport>(
      context: context,
      builder: (_) => _ProductPicker(
        store: widget.store,
        repository: widget.repository,
        side: index == 0 ? 'A' : 'B',
        sessionReports: widget.sessionReports,
      ),
    );
    if (selected == null || !mounted || store != widget.store) return;
    final other = _reports[1 - index];
    if (other != null && other.id == selected.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a different product for comparison.'),
        ),
      );
      return;
    }
    setState(() {
      _reports[index] = selected;
      _tableIds[index] = comparisonTables(selected).firstOrNull?.id;
      _sourceOptions[index] = sourcedComparisonOptions(selected);
      _sourceIds[index] = _sourceOptions[index].firstOrNull?.id;
    });
    _compare();
  }

  ComparisonTable? _table(int index) {
    final report = _reports[index];
    if (report == null) return null;
    return comparisonTables(report)
        .where((table) => table.id == _tableIds[index])
        .firstOrNull;
  }

  void _swap() {
    setState(() {
      final first = _reports[0];
      _reports[0] = _reports[1];
      _reports[1] = first;
      final firstId = _tableIds[0];
      _tableIds[0] = _tableIds[1];
      _tableIds[1] = firstId;
      final source = _sourceIds[0];
      _sourceIds[0] = _sourceIds[1];
      _sourceIds[1] = source;
      final options = _sourceOptions[0];
      _sourceOptions[0] = _sourceOptions[1];
      _sourceOptions[1] = options;
    });
    _compare();
  }

  @override
  Widget build(BuildContext context) {
    final both = _reports.every((report) => report != null);
    final theme = Theme.of(context);
    final comparisons = compareTables(_table(0), _table(1));
    final sourcePair = _source(0) != null && _source(1) != null;
    return PageBody(
      children: [
        Text('Compare products', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Choose two products to see their nutrition side by side.'),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = MediaQuery.textScalerOf(context).scale(16) > 22;
            final cards = [
              for (var index = 0; index < 2; index++)
                _productCard(
                  index,
                  compact: !stack && constraints.maxWidth < 540,
                  alignFooter: !stack,
                ),
            ];
            return stack
                ? Column(
                    children: [cards[0], const SizedBox(height: 12), cards[1]],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  );
          },
        ),
        if (both) ...[
          const SizedBox(height: 20),
          _sourcedPanel(),
          if (!sourcePair) ...[
            const SizedBox(height: 20),
            _comparisonSummary(),
            const SizedBox(height: 20),
            SectionCard(
              padding: MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        'Nutrition comparison',
                        style: theme.textTheme.titleLarge,
                      ),
                      TextButton.icon(
                        onPressed: _swap,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Swap'),
                      ),
                    ],
                  ),
                  Text(
                    'Original table values',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Text(
                    'Device comparison · matching original amounts only',
                  ),
                  const SizedBox(height: 8),
                  for (final row in comparisons) ...[
                    _comparisonRow(row),
                    if (row.name != comparisons.last.name)
                      const Divider(height: 24),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SectionCard(
            padding: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeatureIcon('shield'),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A little context matters',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sourced amounts use a common 100 g or 100 mL basis and the same preparation. Original values keep their printed basis. Unknown values stay unknown. Bars show relative amounts, not an overall health score.',
                      ),
                      if (_reports.any(
                        (report) => report?.isHistorical ?? false,
                      )) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Dated catalogue information may differ from the package you have.',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 24),
          const StatusNotice(
            title: 'Two labels, a clearer picture',
            message: 'Pick a product for A and B from your library, or look one up by barcode.',
            icon: Icons.balance_outlined,
          ),
        ],
      ],
    );
  }

  Widget _productCard(
    int index, {
    required bool compact,
    required bool alignFooter,
  }) {
    final report = _reports[index];
    final theme = Theme.of(context);
    final side = index == 0 ? 'A' : 'B';
    final tables = report == null
        ? <ComparisonTable>[]
        : comparisonTables(report);
    final image = report == null ? null : _productImage(report);
    final sources = _sourceOptions[index];
    return SectionCard(
      key: ValueKey('compare-product-$side'),
      padding: compact ? 12 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _sideBadge(side),
              if (report != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _choose(index),
                      child: Text('Change $side'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            key: ValueKey('compare-report-$side'),
            borderRadius: BorderRadius.circular(12),
            onTap: report == null
                ? () => _choose(index)
                : widget.onOpenReport == null
                ? null
                : () => widget.onOpenReport!(report),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: compact ? 108 : 170,
                    child: image == null
                        ? _productPlaceholder(selected: report != null)
                        : Image.network(
                            image,
                            fit: BoxFit.contain,
                            semanticLabel:
                                '${report!.name} product image from Open Food Facts',
                            errorBuilder: (_, _, _) =>
                                _productPlaceholder(selected: true),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : _productPlaceholder(
                                    selected: true,
                                    loading: true,
                                  ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  report?.name ?? 'Choose a product',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: compact ? 15 : 20,
                    height: 1.3,
                  ),
                ),
                if (report?.brand case final String brand) ...[
                  const SizedBox(height: 4),
                  Text(
                    brand,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  report.isHistorical ? 'Catalogue facts' : 'Current label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _source(index)?.basisLabel ??
                  _table(index)?.label ??
                  'Nutrition table unavailable',
              style: theme.textTheme.bodySmall,
            ),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'source-$index:${report.id}:${_sourceIds[index]}',
                ),
                initialValue: _sourceIds[index],
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Source & table'),
                itemHeight: null,
                selectedItemBuilder: (_) => [
                  for (final source in sources)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        source.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                items: [
                  for (final source in sources)
                    DropdownMenuItem(
                      value: source.id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(source.label),
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _sourceIds[index] = value);
                  _compare();
                },
              ),
            ] else if (tables.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('$index:${report.id}:${_tableIds[index]}'),
                initialValue: _tableIds[index],
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Table for $side'),
                items: [
                  for (final table in tables)
                    DropdownMenuItem(
                      value: table.id,
                      child: Text(
                        table.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _tableIds[index] = value),
              ),
            ],
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text('Label details', style: theme.textTheme.bodySmall),
                children: [
                  Text(report.basisLabel, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  for (final source in report.sourceLabels)
                    Text(source, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
          if (alignFooter) const Spacer(),
          if (report == null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _choose(index),
              child: Text('Choose $side'),
            ),
          ],
          if (report != null && widget.onOpenReport != null)
            TextButton(
              onPressed: () => widget.onOpenReport!(report),
              child: Text('Open report $side'),
            ),
        ],
      ),
    );
  }

  Widget _productPlaceholder({bool selected = false, bool loading = false}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FeatureIcon(selected ? 'leaf' : 'barcode', size: 36),
                    const SizedBox(height: 8),
                    Text(
                      selected ? 'No product photo' : 'Add a label',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      );

  Widget _sideBadge(String side) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: side == 'A'
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
      ),
      child: Text(side, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _comparisonSummary() {
    final theme = Theme.of(context);
    final left = _table(0);
    final right = _table(1);
    final compatible =
        left != null && right != null && left.compatibleWith(right);
    final title = left == null || right == null
        ? 'More label information needed'
        : compatible
        ? 'Matching label amounts'
        : 'Different label amounts';
    final body = compatible
        ? left.label
        : 'Choose matching amounts and preparation to compare. Each original value stays visible below.';
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artwork =
                constraints.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(16) < 24;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(body, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (artwork) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: constraints.maxWidth < 400 ? 72 : 100,
                    child: const CornerArtwork(
                      asset: 'assets/artwork/botanical-corner.png',
                      height: 110,
                      animate: false,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sourcedPanel() {
    final result = _sourced;
    final hasSources = _source(0) != null && _source(1) != null;
    return SectionCard(
      key: const Key('sourced-comparison'),
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Sourced comparison',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (hasSources)
                TextButton.icon(
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Swap'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasSources)
            Text(
              _reports.any(
                    (report) =>
                        report != null &&
                        !report.isHistorical &&
                        report.confirmedComparisonObservation == null,
                  )
                  ? 'Review this label again to compare its amounts. Original values remain below.'
                  : 'An exact public source and nutrition table are needed for each product. Original values remain below.',
            ),
          if (_comparing) const BusyNotice('Comparing sourced amounts…'),
          if (_comparisonError != null) ...[
            Text(_comparisonError!),
            TextButton.icon(
              onPressed: _compare,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry sourced comparison'),
            ),
          ],
          if (result != null) ...[
            Text(
              result.status == 'not_comparable'
                  ? 'These tables cannot be compared'
                  : result.basisLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Numeric differences describe amounts only; they do not select a healthier product.',
            ),
            const SizedBox(height: 12),
            for (final row in result.rows) ...[
              _comparisonRow(
                NutritionComparison(
                  name: row.name,
                  left: ComparisonValue(row.a.value, row.a.unit),
                  right: ComparisonValue(row.b.value, row.b.unit),
                  compatible: row.difference != null,
                  sourcedDifference: row.difference,
                  sourcedSummary: row.difference == null
                      ? comparisonReason(
                          row.reason ?? row.a.reason ?? row.b.reason,
                        )
                      : null,
                ),
              ),
              if (row.name != result.rows.last.name) const Divider(height: 24),
            ],
            ExpansionTile(
              title: const Text('Original rows & source references'),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final pair in [('A', result.a), ('B', result.b)])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${pair.$1} · ${pair.$2.sourceLabel}'),
                        const SizedBox(height: 8),
                        for (final value in pair.$2.originalRows)
                          Text(
                            '${(value as JsonMap)['nutrient'].toString().replaceAll('_', ' ')}: ${value['value'] == null ? 'Unknown' : '${formatNumber((value['value'] as num).toDouble())} ${value['unit']}'} · ${basisDescription(value['basis'], value['preparation'])}',
                          ),
                        const SizedBox(height: 8),
                        SelectableText('Table: ${pair.$2.tableId}'),
                        if (pair.$2.raw['requested_reference'] != null)
                          SelectableText(
                            'Source reference: ${pair.$2.raw['requested_reference']}',
                          ),
                        for (final warning in (pair.$2.raw['warnings'] as List))
                          Text(comparisonReason(warning as String)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonRow(NutritionComparison row) {
    final theme = Theme.of(context);
    final labels = {
      'sugars': 'Sugar',
      'added_sugars': 'Added sugar',
      'fibre': 'Fibre',
      'protein': 'Protein',
      'sodium': 'Sodium',
      'energy': 'Energy',
      'fat': 'Total fat',
      'saturated_fat': 'Saturated fat',
      'carbohydrates': 'Carbohydrates',
      'carbohydrates_total': 'Total carbohydrates',
      'salt': 'Salt',
    };
    final maximum = [
      row.left.value ?? 0,
      row.right.value ?? 0,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    final icon = switch (row.name) {
      'protein' => 'dumbbell',
      'fibre' => 'leaf',
      'energy' => 'fire',
      _ => 'document-text',
    };
    final heading = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FeatureIcon(icon, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            labels[row.name] ?? row.name,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
    final amounts = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _amount('A', row.left, row.difference != null, maximum),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _amount('B', row.right, row.difference != null, maximum),
        ),
      ],
    );
    return Semantics(
      container: true,
      child: Padding(
        key: ValueKey('compare-nutrient-${row.name}'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(16) <= 22;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 200, child: heading),
                      const SizedBox(width: 20),
                      Expanded(child: amounts),
                    ],
                  )
                else ...[
                  heading,
                  const SizedBox(height: 12),
                  amounts,
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: wide ? 220 : 0),
                  child: Text(
                    row.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _amount(
    String side,
    ComparisonValue value,
    bool compatible,
    double maximum,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$side · ${value.label}',
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      if (compatible && value.value != null) ...[
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: maximum == 0 ? 0 : value.value! / maximum,
              color: side == 'A'
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
            ),
          ),
        ),
      ],
    ],
  );

  String? _productImage(ProductReport report) {
    final url = _map(
      _map(
        _map(_map(report.raw['resolved'])['off_snapshot'])['details'],
      )['image'],
    )['url'];
    if (url is! String ||
        !RegExp(
          r'^https://images\.openfoodfacts\.org/images/products/[0-9/]+/front_[a-z]{2,3}\.[0-9]+\.(?:200|400)\.jpg$',
        ).hasMatch(url)) {
      return null;
    }
    return url;
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({
    required this.store,
    required this.repository,
    required this.side,
    required this.sessionReports,
  });
  final LocalStore store;
  final UnlabelRepository repository;
  final String side;
  final List<ProductReport> sessionReports;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final _barcode = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<LocalReport> _items = [];
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final saved = await widget.store.saved();
      final history = await widget.store.history();
      final seen = <String>{};
      final liveReports = {
        for (final report in widget.sessionReports) report.id: report,
      };
      if (mounted) {
        setState(
          () => _items = [...saved, ...history]
              .where((item) => seen.add(item.id))
              .map((item) {
                // Match the exact stored report, never just its barcode. Clearing
                // both lists also removes access to session confirmations.
                final candidate = liveReports[item.id];
                final live =
                    candidate != null &&
                        jsonEncode(candidate.raw) == jsonEncode(item.report.raw)
                    ? candidate
                    : null;
                return live == null
                    ? item
                    : LocalReport(
                        id: item.id,
                        report: live,
                        storedAt: item.storedAt,
                      );
              })
              .toList(),
        );
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your library could not be read. You can still look up a barcode.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookup() async {
    if (_fetching || !_form.currentState!.validate()) return;
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final report = await widget.repository.loadReport(_barcode.text.trim());
      if (mounted) Navigator.pop(context, report);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The product could not be loaded. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Choose product ${widget.side}'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _form,
              child: TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                maxLength: 14,
                decoration: const InputDecoration(labelText: 'Product barcode'),
                validator: (value) =>
                    RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$')
                        .hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter an 8, 12, 13 or 14 digit barcode.',
                onFieldSubmitted: (_) => _lookup(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _fetching ? null : _lookup,
              icon: _fetching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FeatureIcon(
                      'barcode',
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              label: Text(_fetching ? 'Looking up…' : 'Look up barcode'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Your saved and recent products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_loading)
              const BusyNotice('Loading your library…')
            else if (_items.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('Your library is empty. Look up a barcode above.'),
            ] else
              for (final item in _items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.report.name),
                  subtitle: Text(item.report.basisLabel),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: _fetching
                      ? null
                      : () => Navigator.pop(context, item.report),
                ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
