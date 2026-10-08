import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/extracted_observation.dart';
import '../../../core/network/unlabel_repository.dart';
import 'researched_product_page.dart';
import 'product_results_layout.dart';
import 'ui_components.dart';

class ExtractedProductPage extends StatefulWidget {
  const ExtractedProductPage({
    required this.label,
    this.photo,
    this.navigation,
    this.localFallback = false,
    this.repository,
    this.onAccepted,
    this.hasBothSides = false,
    this.barcode,
    this.candidates = const [],
    super.key,
  });
  final ExtractedLabel label;
  final Uint8List? photo;
  final ResultsNavigation? navigation;
  final bool localFallback;
  final UnlabelRepository? repository;
  final Future<void> Function(ProductReport)? onAccepted;
  final bool hasBothSides;
  final String? barcode;
  final List<ResearchedCandidate> candidates;
  @override
  State<ExtractedProductPage> createState() => _ExtractedProductPageState();
}

class _ExtractedProductPageState extends State<ExtractedProductPage> {
  ExtractedLabel get label => widget.label;
  bool get localFallback => widget.localFallback;
  Uint8List? get photo => widget.photo;
  bool _saving = false;
  String? _error, _preparation;
  LabelDraft? _draft;
  int _table = 0;
  Future<void> _accept() async {
    if (_saving) return;
    final draft =
        _draft ??
        acceptedLabelDraft(
          label,
          barcode: widget.barcode,
          preparation: _preparation,
          tableIndex: _table,
        );
    if (draft == null || widget.repository == null) return;
    _draft = draft; // Stable submission ID for explicit retries after uncertain writes.
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final report = await widget.repository!.checkLabel(draft);
      if (!mounted) return;
      await widget.onAccepted?.call(report);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'These facts could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    return Scaffold(
      appBar: ResultsAppBar(
        title: 'Scan Results',
        navigation: widget.navigation,
      ),
      body: ProductResultsLayout(
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
                status: label.ingredients != null
                    ? 'Read from photo'
                    : 'Unknown',
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
          if (widget.hasBothSides && widget.repository != null) ...[
            const SectionTitle('Keep these product facts'),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Check these readings against your front and back photos. Confirm only if they match the same package.',
                  ),
                  if (tables.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: _table,
                      decoration: const InputDecoration(
                        labelText: 'Table to keep',
                      ),
                      items: [
                        for (var i = 0; i < tables.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(tables[i]['basis']['printed_text']),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _table = value!;
                              _draft = null;
                              _preparation = null;
                            }),
                    ),
                  if (tables.isNotEmpty &&
                      tables[_table]['preparation'] == 'unknown')
                    DropdownButtonFormField<String>(
                      initialValue: _preparation,
                      decoration: const InputDecoration(
                        labelText: 'What does the printed table describe?',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'as_sold',
                          child: Text('Food as packaged'),
                        ),
                        DropdownMenuItem(
                          value: 'as_prepared',
                          child: Text('Food after preparation'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _preparation = value;
                              _draft = null;
                            }),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _saving ||
                            acceptedLabelDraft(
                                  label,
                                  barcode: widget.barcode,
                                  preparation: _preparation,
                                  tableIndex: _table,
                                ) ==
                                null
                        ? null
                        : _accept,
                    child: Text(
                      _saving
                          ? 'Saving checked facts…'
                          : 'These facts match my package',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        aside: [
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
          if (widget.candidates.isNotEmpty) ...[
            const SectionTitle('Possible catalogue matches'),
            SectionCard(
              child: Column(
                children: [
                  for (final candidate in widget.candidates.take(5))
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
                      onTap: () async {
                        try {
                          final product = await widget.repository!
                              .loadResearchProduct(candidate.entryId);
                          if (!context.mounted) return;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ResearchedProductPage(
                                product: product,
                                navigation: widget.navigation,
                              ),
                            ),
                          );
                        } on AppFailure catch (error) {
                          if (mounted) {
                            setState(() => _error = error.userMessage);
                          }
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
                  ? 'These unverified readings have not changed public catalogue facts. Checked facts can be added without typing.'
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
      ),
    );
  }
}
