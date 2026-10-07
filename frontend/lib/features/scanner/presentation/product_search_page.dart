import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/unlabel_repository.dart';
import 'report_presentation.dart';
import 'ui_components.dart';

/// Name search replaces the app header and keeps typing independent of requests.
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    required this.repository,
    required this.onOpenReport,
    required this.onEnterLabel,
    super.key,
  });
  final UnlabelRepository repository;
  final Future<void> Function(ProductReport) onOpenReport;
  final VoidCallback onEnterLabel;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _reports = <String, Future<ProductReport>>{};
  final _items = <SearchCandidate>[];
  Timer? _debounce;
  SearchPage? _page;
  String _query = '';
  String? _error, _opening;
  bool _busy = false;
  int _request = 0;

  @override
  void dispose() {
    _request++;
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _request++; // Invalidate the old response before the debounce elapses.
    final query = value.trim();
    setState(() {
      _query = query;
      _error = null;
      _busy = query.length >= 2;
      if (query.length < 2) {
        _items.clear();
        _page = null;
      }
    });
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 280), () => _search());
    }
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    if (_query.length < 2) return;
    final query = _query;
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.repository.search(
        query,
        cursor: more ? _page?.nextCursor : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = page;
        if (!more) _items.clear();
        final codes = _items.map((item) => item.barcode).toSet();
        for (final item in page.candidates) {
          if (codes.add(item.barcode) && _items.length < 100) _items.add(item);
        }
      });
    } on AppFailure catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.userMessage);
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<ProductReport> _report(String code) {
    if (!_reports.containsKey(code) && _reports.length >= 40) {
      _reports.remove(_reports.keys.first);
    }
    return _reports.putIfAbsent(code, () => widget.repository.loadReport(code));
  }

  Future<void> _open(SearchCandidate item) async {
    if (_opening != null) return;
    final request = _request;
    _focus.unfocus();
    setState(() {
      _opening = item.barcode;
      _error = null;
    });
    try {
      final report = await _report(item.barcode);
      if (!mounted || request != _request) return;
      await widget.onOpenReport(report);
    } on AppFailure catch (error) {
      _reports.remove(item.barcode);
      if (mounted && request == _request) {
        setState(() => _error = error.userMessage);
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _page?.status == 'ready';
    final showItems = _query.length >= 2 && _items.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(14) > 21
              ? 112
              : 72,
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: Row(
            children: [
              IconButton(
                tooltip: 'Close search',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  key: const Key('product-search-input'),
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: 128,
                  textInputAction: TextInputAction.search,
                  onChanged: _changed,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Product name or brand',
                    hintText: 'Try oats or a brand…',
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _input.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _input.clear();
                              _changed('');
                              _focus.requestFocus();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_busy) const LinearProgressIndicator(minHeight: 2),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          StatusNotice(
                            title: 'Search could not be completed',
                            message: _error!,
                            action: TextButton(
                              onPressed: _busy ? null : _search,
                              child: const Text('Retry search'),
                            ),
                          ),
                        ],
                        if (_query.length < 2)
                          const StatusNotice(
                            title: 'Find a product',
                            message: 'Search by product name or brand. Choose the matching package to open its label report.',
                            icon: Icons.search_rounded,
                          )
                        else if (!_busy &&
                            _page != null &&
                            (!ready || _items.isEmpty))
                          StatusNotice(
                            title: switch (_page!.status) {
                              'refine_query' =>
                                'Add a more specific name or brand',
                              'unavailable' =>
                                'Catalogue search is unavailable',
                              _ => 'No matches for “$_query”',
                            },
                            message: _page!.status == 'unavailable'
                                ? 'Try again later, or enter the facts on your package.'
                                : 'Try fewer words, check the spelling, or enter the package label.',
                            action: TextButton(
                              onPressed: widget.onEnterLabel,
                              child: const Text('Enter a package label'),
                            ),
                          ),
                        if (showItems) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _busy
                                  ? 'Updating matches…'
                                  : '${_items.length} products shown${_page?.matchedCount == null ? '' : ' · ${_page!.matchedCount} matches'}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Match the package name and size. Catalogue labels may be dated.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showItems)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProductResult(
                            key: ValueKey(item.barcode),
                            item: item,
                            report: _report(item.barcode),
                            opening: _opening == item.barcode,
                            onTap: _opening != null || _busy
                                ? null
                                : () => _open(item),
                          ),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    child:
                        _page?.nextCursor != null &&
                            showItems &&
                            _items.length < 100
                        ? OutlinedButton(
                            onPressed: _busy ? null : () => _search(more: true),
                            child: const Text('Show more products'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductResult extends StatelessWidget {
  const _ProductResult({
    required this.item,
    required this.report,
    required this.opening,
    required this.onTap,
    super.key,
  });
  final SearchCandidate item;
  final Future<ProductReport> report;
  final bool opening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                key: Key('search-image-${item.barcode}'),
                width: 72,
                height: 88,
                child: FutureBuilder<ProductReport>(
                  future: report,
                  builder: (context, snapshot) {
                    final descriptor = snapshot.hasData
                        ? ReportImageDescriptor.fromReport(snapshot.data!)
                        : null;
                    final fallback = Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.inventory_2_outlined, size: 30),
                      ),
                    );
                    return descriptor == null
                        ? fallback
                        : Image.network(
                            descriptor.url,
                            fit: BoxFit.contain,
                            semanticLabel: 'Product photo of ${item.name}',
                            errorBuilder: (_, _, _) => fallback,
                          );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.name, style: theme.textTheme.titleMedium),
                    if (item.brand != null)
                      Text(item.brand!, style: theme.textTheme.bodyMedium),
                    if (item.quantity != null)
                      Text(item.quantity!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      'Open label report',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (opening)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
