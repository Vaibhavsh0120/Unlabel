part of 'product_info_page.dart';

class _ExtractedContent extends StatefulWidget {
  const _ExtractedContent({
    required this.label,
    this.photo,
    this.navigation,
    this.localFallback = false,
    this.repository,
    this.onOpenReport,
    this.catalogueCandidates = const [],
    this.barcode,
    this.candidates = const [],
    super.key,
  });
  final ExtractedLabel label;
  final Uint8List? photo;
  final ResultsNavigation? navigation;
  final bool localFallback;
  final UnlabelRepository? repository;
  final Future<void> Function(ProductReport)? onOpenReport;
  final List<SearchCandidate> catalogueCandidates;
  final String? barcode;
  final List<ResearchedCandidate> candidates;
  @override
  State<_ExtractedContent> createState() => _ExtractedContentState();
}

class _ExtractedContentState extends State<_ExtractedContent> {
  ExtractedLabel get label => widget.label;
  bool get localFallback => widget.localFallback;
  Uint8List? get photo => widget.photo;
  String? _error;
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final tables = label.nutritionTables;
    final barcodeConflict =
        widget.barcode != null &&
        label.identity['barcode'] != null &&
        widget.barcode != label.identity['barcode'];
    final count = tables.fold<int>(
      0,
      (count, table) =>
          count +
          (table['rows'] as List).where((row) => row['value'] != null).length,
    );
    return ProductResultsLayout(
      main: [
        ResultsIdentityCard(
          name: label.identity['name'] ?? 'Your package',
          brand: label.identity['brand'],
          variant: label.identity['variant'],
          quantity: label.identity['quantity'],
          photo: photo,
        ),
        const SizedBox(height: 16),
        ResultsSummaryCard(
          count: count,
          heading: 'Label read automatically',
          message: localFallback
              ? 'Read on this device from your package photo.'
              : 'Read from your package photos by the configured AI service.',
          qualification: 'Machine-read facts · check the photo. This is not a health score.',
        ),
        const SectionTitle('Facts found on your package'),
        ResultsFactsGrid(
          children: [
            ResultsFact(
              icon: 'document-text',
              title: 'Ingredients',
              detail: label.ingredients != null
                  ? 'Ingredient text found on the back label.'
                  : 'Add a clearer back-label photo.',
              status: label.ingredients != null ? 'Read from photo' : 'Unknown',
              uncertain: true,
            ),
            ResultsFact(
              icon: 'leaf',
              title: 'Front claims',
              detail: '${label.frontClaims.length} printed claims read.',
              status: 'Claims are not verified',
              uncertain: true,
            ),
          ],
        ),
        const SectionTitle('Claims found on product front'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label.frontClaims.isEmpty)
                const Text(
                  'No readable front claims. Add a front photo to check.',
                ),
              if (barcodeConflict)
                const StatusNotice(
                  title: 'Barcode readings disagree',
                  message: 'Retake the barcode and label photos from the same package before keeping these facts.',
                ),
              for (final claim in label.frontClaims)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const FeatureIcon('leaf'),
                  title: Text(claim),
                  subtitle: const Text('Printed claim · not verified'),
                ),
            ],
          ),
        ),
        const SectionTitle('Nutrition Snapshot'),
        if (tables.isEmpty)
          const StatusNotice(
            title: 'Nutrition unknown',
            message: 'Photograph the nutrition table clearly. Missing values are not zero.',
          ),
        for (final table in tables)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  table['basis']['printed_text'],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Preparation: ${table['preparation'].toString().replaceAll('_', ' ')}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final row in table['rows'] as List)
                      SizedBox(
                        width: 132,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['nutrient'].toString().replaceAll('_', ' '),
                            ),
                            Text(
                              row['value'] == null
                                  ? 'Unknown'
                                  : '${switch (row['qualifier']) {
                                      'less_than' => '< ',
                                      'less_than_or_equal' => '≤ ',
                                      'approximate' => '≈ ',
                                      _ => '',
                                    }}${row['value']} ${row['unit']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              row['printed_text'],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (label.contribution != null)
          StatusNotice(
            title: label.contribution!.shared
                ? 'Product reading added automatically'
                : 'Product reading kept separate',
            message: label.contribution!.shared
                ? 'Shared as an unverified machine reading. Original records are retained. '
                      '${label.contribution!.conflicts.isEmpty ? 'Check your current package before relying on them.' : 'Some fields disagree with other sources and remain unresolved.'}'
                : 'This reading could not be matched to the same product and pack size, or sharing is unavailable. It has not changed catalogue facts.',
          ),
      ],
      aside: [
        if (!barcodeConflict &&
            widget.repository != null &&
            widget.barcode != null)
          _CatalogueClaims(
            repository: widget.repository!,
            barcode: widget.barcode!,
            claims: label.frontClaims,
          ),
        if (widget.repository != null &&
            (widget.barcode ??
                    label.contribution?.barcode ??
                    label.identity['barcode']) !=
                null)
          _ProductSupplements(
            repository: widget.repository!,
            barcode:
                widget.barcode ??
                label.contribution?.barcode ??
                label.identity['barcode'],
          ),
        if (_error != null) ...[
          StatusNotice(
            title: 'Could not complete this action',
            message: _error!,
          ),
          const SizedBox(height: 16),
        ],
        const SectionTitle('Ingredient Insights'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingredients read from your photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ResultsSelectableText(
                label.ingredients ??
                    'Ingredient information unknown. Add a back-label photo.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.candidates.isNotEmpty ||
            widget.catalogueCandidates.isNotEmpty) ...[
          const SectionTitle('Choose your product and pack size'),
          SectionCard(
            child: Column(
              children: [
                const Text('Match your package’s brand, variant and size.'),
                for (final candidate in widget.catalogueCandidates.where(
                  (item) => !widget.candidates.any(
                    (research) => research.barcode == item.barcode,
                  ),
                ))
                  ListTile(
                    title: Text(candidate.name),
                    subtitle: Text(
                      [
                        candidate.brand,
                        candidate.quantity,
                        candidate.barcode,
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        _opening ||
                            widget.repository == null ||
                            widget.onOpenReport == null
                        ? null
                        : () async {
                            setState(() => _opening = true);
                            try {
                              final report = await widget.repository!
                                  .loadReport(candidate.barcode);
                              if (mounted) await widget.onOpenReport!(report);
                            } on AppFailure catch (error) {
                              if (mounted) {
                                setState(() => _error = error.userMessage);
                              }
                            } finally {
                              if (mounted) setState(() => _opening = false);
                            }
                          },
                  ),
                for (final candidate in widget.candidates)
                  ListTile(
                    title: Text(candidate.name),
                    subtitle: Text(
                      [
                        candidate.brand,
                        candidate.variant,
                        candidate.quantity,
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _opening || widget.repository == null
                        ? null
                        : () async {
                            setState(() => _opening = true);
                            try {
                              final product = await widget.repository!
                                  .loadResearchProduct(candidate.entryId);
                              if (!context.mounted) return;
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ProductInfoPage.research(
                                    product: product,
                                    frontClaims: label.frontClaims,
                                    repository: widget.repository,
                                    navigation: widget.navigation,
                                  ),
                                ),
                              );
                            } on AppFailure catch (error) {
                              if (mounted) {
                                setState(() => _error = error.userMessage);
                              }
                            } finally {
                              if (mounted) setState(() => _opening = false);
                            }
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (label.storageStatus != null)
          StatusNotice(
            title: label.storageStatus == 'private_unverified'
                ? 'Product facts staged privately'
                : 'Product facts could not be staged',
            message: label.storageStatus == 'private_unverified'
                ? 'A temporary private copy supports this reading. Any automatic shared contribution is listed separately above.'
                : 'Your reading is still shown here. Retake or retry to keep the new product information.',
          ),
        const SizedBox(height: 16),
        ResultsAllergenNotice(
          contains: label.contains,
          mayContain: label.mayContain,
        ),
        const SizedBox(height: 16),
        const StatusNotice(
          title: 'Your current package photo',
          message: 'Automatic reading can make mistakes. These facts are unverified and have not replaced catalogue records. Photos stay outside history and account sync.',
        ),
      ],
    );
  }
}
