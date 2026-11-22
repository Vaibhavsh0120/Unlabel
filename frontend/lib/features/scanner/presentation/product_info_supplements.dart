part of 'product_info_page.dart';

/// Supplementary sources remain outside ProductReport and all library writes.
class _ProductSupplements extends StatefulWidget {
  const _ProductSupplements({required this.repository, required this.barcode});
  final UnlabelRepository repository;
  final String barcode;
  @override
  State<_ProductSupplements> createState() => _ProductSupplementsState();
}

class _ProductSupplementsState extends State<_ProductSupplements> {
  MachineProductLookup? _machine;
  int _generation = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProductSupplements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barcode != widget.barcode ||
        oldWidget.repository != widget.repository) {
      _machine = null;
      _error = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    var failed = false;
    try {
      final value = await widget.repository.machineProduct(widget.barcode);
      if (!mounted || generation != _generation) return;
      _machine = value;
    } catch (_) {
      failed = true;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _error = failed
          ? 'Some additional sources are unavailable. The catalogue information is still shown.'
          : null;
    });
  }

  @override
  void dispose() {
    _generation++;
    _machine = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readings = _machine?.readings ?? const <MachineProductReading>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: const Text('Checking additional product sources…'),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: StatusNotice(
              title: 'Additional sources unavailable',
              message: _error!,
            ),
          ),
        if (readings.isNotEmpty) ...[
          const SectionTitle('Additional label readings'),
          const Text(
            'Automatically read from package photos. Unverified readings are kept separate from original catalogue sources.',
          ),
          if (_machine!.conflicts.isNotEmpty)
            StatusNotice(
              title: 'Sources disagree',
              message:
                  'Unresolved fields: ${_machine!.conflicts.join(', ')}. No reading is selected as the correct one.',
            ),
          for (final reading in readings)
            SectionCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  reading.label.identity['name'] ?? 'Package reading',
                ),
                subtitle: Text(
                  '${reading.provider} · ${reading.date.toIso8601String().substring(0, 10)} · unverified',
                ),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reading.conflicts.isNotEmpty)
                        Text('Disagreements: ${reading.conflicts.join(', ')}'),
                      ResultsSelectableText(
                        'Ingredients: ${reading.label.ingredients ?? 'Unknown'}',
                      ),
                      ResultsAllergenNotice(
                        contains: reading.label.contains,
                        mayContain: reading.label.mayContain,
                      ),
                      for (final table in reading.label.nutritionTables) ...[
                        Text(
                          '${table['basis']['printed_text']} · ${table['preparation']}',
                        ),
                        for (final row in table['rows'] as List)
                          Text('${row['nutrient']}: ${row['printed_text']}'),
                      ],
                      if (reading.label.frontClaims.isNotEmpty)
                        Text(
                          'Printed claims (unverified): ${reading.label.frontClaims.join(', ')}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
