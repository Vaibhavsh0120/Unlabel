part of 'product_info_page.dart';

class _CatalogueClaims extends StatefulWidget {
  const _CatalogueClaims({
    required this.repository,
    required this.barcode,
    required this.claims,
  });
  final UnlabelRepository repository;
  final String barcode;
  final List<String> claims;
  @override
  State<_CatalogueClaims> createState() => _CatalogueClaimsState();
}

class _CatalogueClaimsState extends State<_CatalogueClaims> {
  Future<CatalogueClaimCheck>? _check;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final claims = widget.claims.toSet().toList(growable: false);
    _check = claims.isEmpty
        ? null
        : widget.repository.catalogueClaims(widget.barcode, claims);
  }

  @override
  void didUpdateWidget(covariant _CatalogueClaims oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.barcode != widget.barcode ||
        oldWidget.claims.join('\n') != widget.claims.join('\n')) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_check == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Front claims and catalogue evidence'),
        const Text(
          'Photo-read claims checked against dated sources. Check your current package; this is not a compliance verdict.',
        ),
        const SizedBox(height: 12),
        FutureBuilder<CatalogueClaimCheck>(
          future: _check,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Semantics(
                liveRegion: true,
                child: const Text('Checking catalogue evidence…'),
              );
            }
            if (snapshot.hasError || snapshot.data?.status != 'ready') {
              return const StatusNotice(
                title: 'Claim evidence unavailable',
                message: 'There is not enough sourced information to check these claims. Your package readings are still available.',
              );
            }
            final data = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in data.assessments)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row['text'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Insufficient information for this claim'),
                        for (final reason in row['reasons'] as List)
                          Text(_claimReason(reason.toString())),
                        if ((row['comparisons'] as List).isNotEmpty)
                          ExpansionTile(
                            title: const Text('Sourced numbers and criteria'),
                            children: [
                              for (final cell in row['comparisons'] as List)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${cell['nutrient'].toString().replaceAll('_', ' ')}: ${cell['value'] ?? 'unknown'} ${cell['unit']}',
                                  ),
                                  subtitle: Text(
                                    '${cell['basis'].toString().replaceAll('_', ' ')} · criterion ${cell['operator'] == 'gte' ? '≥' : '≤'} ${cell['threshold']} ${cell['unit']}\n${cell['source_id']} · ${cell['table_id']}\n${cell['outcome'].toString().replaceAll('_', ' ')}',
                                  ),
                                ),
                            ],
                          ),
                        if ((row['rule_source_ids'] as List).isNotEmpty)
                          ResultsSelectableText(
                            'Rule sources: ${(row['rule_source_ids'] as List).join(', ')}',
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

String _claimReason(String reason) => switch (reason) {
  'current_package_not_confirmed' =>
    'Your package may differ from catalogue sources.',
  'food_category_and_form_not_established' =>
    'Product category and form are unknown.',
  'claim_not_implemented_with_reviewed_evidence' =>
    'This claim is outside the reviewed rules.',
  'reviewed_source_not_current' => 'The rule source needs a current review.',
  'catalogue_identity_conflict' =>
    'Catalogue sources disagree about the product identity.',
  'catalogue_table_limit' =>
    'There are too many source tables to compare reliably.',
  'direct_nutrition_table_missing' =>
    'A directly sourced nutrition table is missing.',
  _ => reason.replaceAll('_', ' '),
};
