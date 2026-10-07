import 'package:flutter/material.dart';

import '../../../core/network/unlabel_repository.dart';
import 'ui_components.dart';

class LookupPage extends StatefulWidget {
  const LookupPage({
    required this.repository,
    required this.barcodeMode,
    required this.onOpenReport,
    required this.onEnterLabel,
    super.key,
  });

  final UnlabelRepository repository;
  final bool barcodeMode;
  final Future<void> Function(ProductReport) onOpenReport;
  final VoidCallback onEnterLabel;

  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  final _form = GlobalKey<FormState>();
  final _input = TextEditingController();
  late bool _barcodeMode;
  bool _busy = false;
  String? _error;
  String? _errorKind;
  SearchPage? _page;
  final List<SearchCandidate> _candidates = [];
  String _submittedQuery = '';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _barcodeMode = widget.barcodeMode;
  }

  @override
  void dispose() {
    _request++;
    _input.dispose();
    super.dispose();
  }

  void _changeMode(bool barcode) {
    if (_barcodeMode == barcode) return;
    _request++;
    setState(() {
      _barcodeMode = barcode;
      _busy = false;
      _error = null;
      _errorKind = null;
      _page = null;
      _candidates.clear();
      _input.clear();
    });
    _form.currentState?.reset();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _submittedQuery = _input.text.trim();
    if (_barcodeMode) {
      await _loadReport(_submittedQuery);
    } else {
      await _search();
    }
  }

  Future<void> _search({bool more = false}) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _errorKind = null;
      if (!more) {
        _page = null;
        _candidates.clear();
      }
    });
    try {
      final result = await widget.repository.search(
        _submittedQuery,
        cursor: more ? _page?.nextCursor : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = result;
        if (!more) _candidates.clear();
        final codes = _candidates.map((item) => item.barcode).toSet();
        for (final item in result.candidates) {
          if (codes.add(item.barcode) && _candidates.length < 100) {
            _candidates.add(item);
          }
        }
      });
    } on AppFailure catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error.userMessage;
          _errorKind = error.kind;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _loadReport(String barcode) async {
    if (_busy) return;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
      _errorKind = null;
    });
    try {
      final report = await widget.repository.loadReport(barcode);
      if (!mounted || request != _request) return;
      setState(() => _busy = false);
      await widget.onOpenReport(report);
    } on AppFailure catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error.userMessage;
          _errorKind = error.kind;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Find a product')),
      body: PageBody(
        maxWidth: 860,
        children: [
          const Text('Enter the barcode, or search by name and brand.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Barcode'),
                selected: _barcodeMode,
                onSelected: (_) => _changeMode(true),
              ),
              ChoiceChip(
                label: const Text('Name or brand'),
                selected: !_barcodeMode,
                onSelected: (_) => _changeMode(false),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('lookup-input'),
                  controller: _input,
                  maxLength: _barcodeMode ? 14 : 128,
                  keyboardType: _barcodeMode
                      ? TextInputType.number
                      : TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _barcodeMode
                        ? 'Printed barcode'
                        : 'Product name or brand',
                    hintText: _barcodeMode
                        ? '8, 12, 13 or 14 digits'
                        : 'For example, oats or a brand name…',
                    suffixIcon: _input.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search text',
                            onPressed: () => setState(() => _input.clear()),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (_barcodeMode) {
                      return RegExp(r'^(?:[0-9]{8}|[0-9]{12,14})$')
                              .hasMatch(text)
                          ? null
                          : 'Enter an 8, 12, 13 or 14 digit barcode.';
                    }
                    return text.length >= 2 && text.length <= 128
                        ? null
                        : 'Enter at least 2 characters from the name or brand.';
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('lookup-submit'),
                  onPressed: _busy ? null : _submit,
                  icon: _barcodeMode
                      ? const Icon(Icons.search)
                      : FeatureIcon(
                          'leaf',
                          color: theme.colorScheme.onPrimary,
                          size: 22,
                        ),
                  label: Text(
                    _busy
                        ? 'Looking up…'
                        : _barcodeMode
                        ? 'Look up barcode'
                        : 'Search catalogue',
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const BusyNotice('Finding sourced catalogue information…'),
          if (_error != null) ...[
            const SizedBox(height: 24),
            StatusNotice(
              key: const Key('lookup-error'),
              title: _errorKind == 'not_found'
                  ? 'No catalogue report for this code'
                  : 'Lookup could not be completed',
              message: _error!,
              action: _errorKind == 'not_found'
                  ? OutlinedButton(
                      onPressed: widget.onEnterLabel,
                      child: const Text('Enter this package label'),
                    )
                  : OutlinedButton(
                      onPressed: _busy ? null : _submit,
                      child: const Text('Retry lookup'),
                    ),
            ),
          ],
          if (!_barcodeMode && _page != null) ...[
            const SizedBox(height: 24),
            if (_page!.status == 'refine_query')
              const StatusNotice(
                title: 'Narrow your search',
                message: 'This query matches too many products. Add the brand or a more specific product name.',
              )
            else if (_page!.status == 'unavailable')
              StatusNotice(
                title: 'Catalogue search is unavailable',
                message: 'Please try again later. You can still enter the facts printed on your package.',
                action: OutlinedButton(
                  onPressed: widget.onEnterLabel,
                  child: const Text('Enter a package label'),
                ),
              )
            else if (_candidates.isEmpty)
              StatusNotice(
                title: 'No matches for “$_submittedQuery”',
                message: 'Check the spelling, try fewer words or use the barcode. A missing match does not mean the product is unsafe.',
                action: OutlinedButton(
                  onPressed: widget.onEnterLabel,
                  child: const Text('Enter a package label'),
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  'Choose a matching package',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_candidates.length} shown${_page!.matchedCount == null ? '' : ' of ${_page!.matchedCount} matches'} for “$_submittedQuery”. Names alone do not confirm identity.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Dated observations may differ from your current package.',
              ),
              const SizedBox(height: 20),
              for (final item in _candidates) ...[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.titleLarge),
                      if (item.brand != null) ...[
                        const SizedBox(height: 8),
                        Text(item.brand!),
                      ],
                      if (item.quantity != null) ...[
                        const SizedBox(height: 6),
                        Text(item.quantity!),
                      ],
                      const SizedBox(height: 8),
                      SelectableText('Barcode ${item.barcode}'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _loadReport(item.barcode),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Open dated report'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_page!.nextCursor != null && _candidates.length < 100)
                OutlinedButton(
                  onPressed: _busy ? null : () => _search(more: true),
                  child: const Text('Show more matches'),
                ),
              if (_candidates.length >= 100)
                const Text(
                  'Refine the name or brand to find more specific matches.',
                ),
            ],
          ],
        ],
      ),
    );
  }
}
