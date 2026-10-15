part of 'product_info_page.dart';

class _ResearchContent extends StatelessWidget {
  const _ResearchContent({
    required this.product,
    this.repository,
    this.frontClaims = const [],
  });
  final ResearchedProduct product;
  final UnlabelRepository? repository;
  final List<String> frontClaims;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflicts = product.metadata['conflicts'];
    final hasConflict =
        product.conflictFields.isNotEmpty ||
        (conflicts is List && conflicts.isNotEmpty);
    return ProductResultsLayout(
      main: [
        ResultsIdentityCard(
          name: product.name,
          brand: product.brand,
          variant: product.variant,
          quantity: product.quantity,
          imageUrl: product.imageUrl,
          imageDescription:
              '${product.imageAttribution ?? ''}. ${product.imageLicense ?? ''}',
        ),
        const SizedBox(height: 16),
        ResultsSummaryCard(
          count: product.tables.fold<int>(
            0,
            (count, table) =>
                count +
                (table['rows'] as List)
                    .where(
                      (row) =>
                          row is JsonMap &&
                          row['value'] != null &&
                          row['qualifier'] != 'unknown',
                    )
                    .length,
          ),
          heading: 'Sourced product information',
          message: 'Dated website facts for this product and variant.',
          qualification: 'Check your package. No health score is assigned.',
        ),
        const SectionTitle('What the source shows'),
        ResultsFactsGrid(
          children: [
            ResultsFact(
              icon: 'document-text',
              title: 'Ingredient declaration',
              detail: product.section('ingredients') == null
                  ? 'Not declared in this source'
                  : 'Source wording and completeness retained.',
              status: product.section('ingredients') == null
                  ? 'Unknown'
                  : 'Recorded',
              uncertain: product.section('ingredients') == null,
            ),
            ResultsFact(
              icon: 'fire',
              title: 'Nutrition tables',
              detail:
                  '${product.tables.length} directly reported tables with their own basis.',
              status: product.tables.isEmpty
                  ? 'Unavailable'
                  : 'Source attached',
              uncertain: product.tables.isEmpty,
            ),
          ],
        ),
        const SectionTitle('Nutrition'),
        SectionCard(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (product.tables.isEmpty)
                const Text('Nutrition table unavailable.'),
              for (final table in product.tables) ...[
                Text(
                  basisDescription(table['basis'], table['preparation']),
                  style: theme.textTheme.titleMedium,
                ),
                Text(switch (table['source']) {
                  'retailer_transcription' => 'Values reported by the retailer',
                  'packaging' => 'Recorded package table',
                  _ => 'Manufacturer declaration',
                }, style: theme.textTheme.bodySmall),
                _provenance(table['provenance'] as JsonMap, theme),
                const SizedBox(height: 8),
                for (final row in table['rows'] as List)
                  _nutrient(row as JsonMap),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ],
      aside: [
        if (repository != null && product.barcode != null)
          _CatalogueClaims(
            repository: repository!,
            barcode: product.barcode!,
            claims: frontClaims,
          ),
        if (repository != null && product.barcode != null)
          _ProductSupplements(
            repository: repository!,
            barcode: product.barcode!,
          ),
        SectionCard(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                '${researchProviderLabel(product.provider)} · collected ${_day(product.retrievedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(switch (product.match) {
                'exact_sku' => 'Dated information. Check your current package.',
                'brand_family_only' =>
                  'Variant information. Barcode unconfirmed.',
                _ => 'Package unconfirmed. Check the variant and size.',
              }),
              if (hasConflict) ...[
                const SizedBox(height: 12),
                const Text('Sources disagree. Read the source notes.'),
              ],
              for (final warning in product.warnings.map(_warning).toSet()) ...[
                const SizedBox(height: 8),
                Text(warning),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResultsAllergenNotice(
          contains: product.section('contains'),
          mayContain: product.section('may_contain'),
        ),
        SectionCard(
          padding: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (key, title) in [
                ('ingredients', 'Ingredients'),
                ('contains', 'Contains'),
                ('may_contain', 'May contain'),
              ]) ...[
                SectionTitle(title),
                _selectable(
                  product.section(key) ?? 'Not declared in this source',
                ),
                if (product.sectionInfo(key) case final info?) ...[
                  const SizedBox(height: 6),
                  Text(switch (info['completeness']) {
                    'partial' => 'Partial declaration',
                    'unknown' => 'Declaration completeness unknown',
                    _ => 'Complete declaration',
                  }, style: theme.textTheme.bodySmall),
                  _provenance(info['provenance'] as JsonMap, theme),
                ],
              ],
            ],
          ),
        ),
        const SectionTitle('Source'),
        _selectable(product.sourceUrl),
        TextButton.icon(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: product.sourceUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Source link copied')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not copy the link. You can select it above.',
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy source link'),
        ),
        Text(
          product.sourceUpdatedAt == null
              ? 'No product update date provided.'
              : 'Source updated ${_day(product.sourceUpdatedAt!)}',
        ),
        Text(
          product.barcode == null
              ? 'Barcode unknown'
              : 'Barcode ${product.barcode}',
        ),
        if (product.metadata.isNotEmpty ||
            product.conflictFields.isNotEmpty) ...[
          const SizedBox(height: 20),
          ExpansionTile(
            title: const Text('Source notes and missing information'),
            children: [
              if (product.conflictFields.isNotEmpty)
                _note(
                  'Fields where sources disagree',
                  product.conflictFields.map(_field).join('\n'),
                  theme,
                ),
              for (final entry in product.metadata.entries)
                if (entry.key == 'candidate_numeric_table')
                  _candidateTable(entry.value, theme)
                else if (entry.key == 'candidate_numeric_table_alternatives' &&
                    entry.value is List)
                  for (final table in entry.value as List)
                    _candidateTable(table, theme, alternative: true)
                else
                  _note(_label(entry.key), _describe(entry.value), theme),
            ],
          ),
        ],
      ],
    );
  }

  Widget _candidateTable(
    Object? value,
    ThemeData theme, {
    bool alternative = false,
  }) {
    if (value is! JsonMap || value['rows'] is! List) {
      return _note('Reported website nutrition', _describe(value), theme);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            alternative
                ? 'Alternative website values'
                : 'Reported website values',
            style: theme.textTheme.titleSmall,
          ),
          const Text('Unconfirmed website values. Check your package.'),
          Text(basisDescription(value['basis'], value['preparation'])),
          if (value['source_url'] is String)
            _selectable(value['source_url'] as String),
          if (value['retrieved_at'] is String)
            Text('Collected ${value['retrieved_at']}'),
          for (final row in value['rows'] as List)
            if (row is JsonMap) _nutrient(row, candidate: true),
          for (final entry in value.entries)
            if (!const [
              'rows',
              'basis',
              'preparation',
              'source_url',
              'retrieved_at',
            ].contains(entry.key))
              Text('${_label(entry.key)}: ${_describe(entry.value)}'),
        ],
      ),
    );
  }

  Widget _nutrient(JsonMap row, {bool candidate = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            '${row['raw_label'] ?? row['nutrient'] ?? 'Nutrient unknown'}'
                .replaceAll('_', ' '),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 2,
          child: Text(
            _value(row, candidate: candidate),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _provenance(JsonMap source, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${researchProviderLabel(source['provider'] as String)} · collected ${_day(source['retrieved_at'] as String)}',
          style: theme.textTheme.bodySmall,
        ),
        if (source['source_updated_at'] != null)
          Text(
            'Source updated ${_day(source['source_updated_at'] as String)}',
            style: theme.textTheme.bodySmall,
          ),
        if (source['url'] != product.sourceUrl)
          _selectable(
            source['url'] as String,
            style: theme.textTheme.bodySmall,
          ),
      ],
    ),
  );

  Widget _note(String title, String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        _selectable(text.isEmpty ? 'Unknown' : text),
      ],
    ),
  );

  Widget _selectable(String text, {TextStyle? style}) =>
      ResultsSelectableText(text, style: style);

  String _day(String value) => value.substring(0, 10);
  String _warning(String code) => switch (code) {
    'researched_web_facts_not_current_package_confirmation' =>
      'Website facts do not confirm your current package.',
    'allergen_safety_not_assessed' => 'Allergen safety has not been assessed.',
    _ => 'Some source information is unavailable.',
  };
  String _value(JsonMap row, {bool candidate = false}) {
    if (row['value'] == null || row['qualifier'] == 'unknown') return 'Unknown';
    final prefix = switch (row['qualifier']) {
      'less_than' => 'Less than ',
      'less_than_or_equal' => 'At most ',
      'greater_than' => 'More than ',
      'greater_than_or_equal' => 'At least ',
      'approximate' => 'About ',
      null when !candidate => 'Unknown ',
      _ => '',
    };
    return '$prefix${row['value']} ${row['unit'] ?? ''}'.trim();
  }

  String _field(String key) => key
      .replaceAll('candidate_numeric_table.', 'reported nutrition: ')
      .replaceAll('sections.', '')
      .replaceAll('_', ' ');
  String _label(String key) => switch (key) {
    'conflicts' => 'Source disagreements',
    'unknowns' => 'Missing information',
    'notes' => 'Notes',
    'identity_note' => 'Package identity',
    'evidence' => 'Source evidence',
    'candidate_numeric_table' => 'Retailer nutrition record',
    'candidate_numeric_table_alternatives' =>
      'Alternative retailer nutrition records',
    'field' => 'Field',
    'status' => 'Status',
    'alternatives' => 'Reported alternatives',
    'resolution' => 'How this is handled',
    'source' => 'Source',
    'source_url' => 'Source link',
    'retrieved_at' => 'Collected',
    'source_updated_at' => 'Updated',
    'raw_label' => 'Label wording',
    _ => _field(key),
  };
  String _describe(Object? value) => value is List
      ? value.map(_describe).where((item) => item.isNotEmpty).join('\n\n')
      : value is Map
      ? value.entries
            .map(
              (item) =>
                  '${_label(item.key.toString())}: ${_describe(item.value)}',
            )
            .join('\n')
      : value == null
      ? 'Unknown'
      : switch (value) {
          'unconfirmed_retailer_candidate_not_runtime_nutrition' =>
            'Unconfirmed; check your package.',
          'retailer_attributes' => 'Retailer product details',
          'retailer_nutrition_information' => 'Retailer nutrition summary',
          _ => value.toString().replaceAll('_', ' '),
        };
}
