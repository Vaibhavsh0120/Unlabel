import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/unlabel_repository.dart';
import 'report_presentation.dart';
import 'ui_components.dart';
import '../../../core/widgets/search_skeleton.dart';

/// Name search replaces the app header and keeps typing independent of requests.
class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    required this.repository,
    required this.onOpenReport,
    required this.onEnterLabel,
    this.focusNode,
    this.autofocus = true,
    this.onClose,
    this.active = true,
    super.key,
  });
  final UnlabelRepository repository;
  final Future<void> Function(ProductReport) onOpenReport;
  final VoidCallback onEnterLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onClose;
  final bool active;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final _input = TextEditingController();
  late final _focus = widget.focusNode ?? FocusNode();
  final _reports = <String, Future<ProductReport?>>{};
  final _thumbnails = <_ThumbnailJob>[];
  int _thumbnailRequests = 0;
  final _items = <SearchCandidate>[];
  Timer? _debounce;
  SearchPage? _page;
  String _query = '';
  String _resultsQuery = '';
  final _noThumbnail = Future<ProductReport?>.value(null);
  String? _error, _opening;
  bool _busy = false;
  int _request = 0;

  @override
  void dispose() {
    _request++;
    _debounce?.cancel();
    _discardThumbnails();
    _input.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      _request++;
      _debounce?.cancel();
      _busy = false;
      _discardThumbnails();
      _reports.clear();
    }
    if (widget.active && !oldWidget.active && _query.length >= 2) {
      unawaited(_search());
    }
  }

  void _discardThumbnails() {
    for (final job in _thumbnails) {
      _reports.remove(job.code);
      job.result.complete(null);
    }
    _thumbnails.clear();
  }

  void _close() {
    _focus.unfocus();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _discardThumbnails();
    _request++; // Invalidate the old response before the debounce elapses.
    final query = value.trim();
    setState(() {
      _query = query;
      _error = null;
      _busy = query.length >= 2;
      if (query.length < 2) {
        _items.clear();
        _page = null;
        _reports.clear();
        _resultsQuery = '';
      }
    });
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 280), () => _search());
    }
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    if (_query.length < 2 || !widget.active) return;
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
      if (!more) {
        _discardThumbnails();
        _reports.clear();
      }
      setState(() {
        _page = page;
        _resultsQuery = query;
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

  Future<ProductReport?> _report(String code, {bool selected = false}) {
    // Retained rows remain readable while a changed query is pending, without
    // launching fresh background work for the obsolete results.
    if (!selected && _query != _resultsQuery) {
      return _reports[code] ?? _noThumbnail;
    }
    if (!_reports.containsKey(code) && _reports.length >= 40) {
      _reports.remove(_reports.keys.first);
    }
    return _reports.putIfAbsent(code, () {
      final job = _ThumbnailJob(code);
      if (selected) {
        unawaited(_loadThumbnail(job));
      } else {
        _thumbnails.add(job);
        _pumpThumbnails();
      }
      return job.result.future;
    });
  }

  void _pumpThumbnails() {
    while (mounted &&
        widget.active &&
        _query == _resultsQuery &&
        _thumbnailRequests < 2 &&
        _thumbnails.isNotEmpty) {
      unawaited(_loadThumbnail(_thumbnails.removeAt(0)));
    }
  }

  Future<void> _loadThumbnail(_ThumbnailJob job) async {
    _thumbnailRequests++;
    try {
      job.result.complete(await widget.repository.loadReport(job.code));
    } catch (error, stack) {
      if (_reports[job.code] == job.result.future) _reports.remove(job.code);
      job.result.completeError(error, stack);
    } finally {
      _thumbnailRequests--;
      _pumpThumbnails();
    }
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
      // A chosen result starts immediately instead of waiting behind photos.
      final queued = _thumbnails.indexWhere((job) => job.code == item.barcode);
      if (queued >= 0) unawaited(_loadThumbnail(_thumbnails.removeAt(queued)));
      final report = await _report(item.barcode, selected: true);
      if (!mounted || request != _request || report == null) return;
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
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
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
                onPressed: _close,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  key: const Key('product-search-input'),
                  controller: _input,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
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
                        if (_busy && _items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SearchSkeleton(),
                          ),
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
                            title: 'Search products',
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
  final Future<ProductReport?> report;
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
                child: FutureBuilder<ProductReport?>(
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
                            cacheWidth: 216,
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

class _ThumbnailJob {
  _ThumbnailJob(this.code);
  final String code;
  final result = Completer<ProductReport?>();
}
