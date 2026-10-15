part of 'product_info_page.dart';

/// Supplementary sources remain outside ProductReport and all library writes.
class _ProductSupplements extends StatefulWidget {
  const _ProductSupplements({required this.repository, required this.barcode});
  final UnlabelRepository repository;
  final String barcode;
  @override
  State<_ProductSupplements> createState() => _ProductSupplementsState();
}

class _ProductSupplementsState extends State<_ProductSupplements>
    with WidgetsBindingObserver {
  LiveProductLookup? _live;
  MachineProductLookup? _machine;
  Timer? _expiry;
  int _generation = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant _ProductSupplements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barcode != widget.barcode ||
        oldWidget.repository != widget.repository) {
      _expiry?.cancel();
      _live = null;
      _machine = null;
      _error = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    var failed = false;
    // Independent sources must not suppress each other on a vendor outage.
    await Future.wait([
      () async {
        try {
          final value = await widget.repository.liveProduct(widget.barcode);
          if (!mounted || generation != _generation) return;
          _live = value;
          final expires = value.product?.expiresAt;
          if (expires != null) {
            _expiry?.cancel();
            final remaining = expires.difference(DateTime.now().toUtc());
            if (remaining <= Duration.zero) {
              _live = const LiveProductLookup('expired');
            } else {
              _expiry = Timer(remaining, _expire);
            }
          }
        } catch (_) {
          failed = true;
        }
      }(),
      () async {
        try {
          final value = await widget.repository.machineProduct(widget.barcode);
          if (mounted && generation == _generation) _machine = value;
        } catch (_) {
          failed = true;
        }
      }(),
    ]);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      _error = failed
          ? 'Some additional sources are unavailable. The catalogue information is still shown.'
          : null;
    });
  }

  void _expire() {
    if (!mounted) return;
    // Drop all vendor fields, not merely their rendered text.
    setState(() => _live = const LiveProductLookup('expired'));
    _expiry?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final expires = _live?.product?.expiresAt;
    if (expires != null && !DateTime.now().toUtc().isBefore(expires)) _expire();
  }

  @override
  void dispose() {
    _generation++;
    _expiry?.cancel();
    _live = null;
    _machine = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = _live?.product;
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
        if (product != null &&
            DateTime.now().toUtc().isBefore(product.expiresAt)) ...[
          const SectionTitle('Live product lookup'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Data by NutriGraphAPI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      try {
                        if (await launchUrl(
                          Uri.parse('https://nutrigraphapi.com'),
                          mode: LaunchMode.externalApplication,
                        )) {
                          return;
                        }
                      } catch (_) {
                        // The selectable source URL below remains available.
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open the source. Copy its link to your browser.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Visit NutriGraphAPI'),
                  ),
                ),
                const ResultsSelectableText('https://nutrigraphapi.com'),
                const SizedBox(height: 8),
                const Text(
                  'Unverified provider facts. Check your current package. These facts are not saved.',
                ),
                if (product.name != null) Text(product.name!),
                if (product.brand != null) Text(product.brand!),
                for (final field in product.fields)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        ResultsSelectableText(field.value),
                        if (field.sources.isNotEmpty)
                          Text(
                            field.sources.join('\n'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                if (product.sources.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Provider sources'),
                    children: [
                      ResultsSelectableText(product.sources.join('\n')),
                    ],
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Missing allergen information does not mean allergen-free.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (const [
          'rate_limited',
          'unavailable',
          'expired',
        ].contains(_live?.status)) ...[
          StatusNotice(
            title: 'Live lookup unavailable',
            message: _live?.status == 'rate_limited'
                ? 'The provider request allowance has been reached. Local catalogue results remain available.'
                : 'Live facts are unavailable or have expired. Reopen this product to try again.',
          ),
          const SizedBox(height: 16),
        ],
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
