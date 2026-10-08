import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/unlabel_repository.dart';
import 'report_presentation.dart';
import 'researched_product_page.dart';
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
  final _researchItems = <ResearchedCandidate>[];
  Timer? _debounce;
  SearchPage? _page;
  ResearchSearchPage? _researchPage;
  String _query = '';
  String _resultsQuery = '';
  final _noThumbnail = Future<ProductReport?>.value(null);
  String? _error, _opening;
  bool _busy = false;
  bool _offRetryPending = false, _researchRetryPending = false;
  String? _offSearchError, _researchSearchError;
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
        _researchItems.clear();
        _page = null;
        _researchPage = null;
        _reports.clear();
        _resultsQuery = '';
      }
    });
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 280), () => _search());
    }
  }

  Future<(T?, AppFailure?)> _readSource<T>(Future<T> Function() read) async {
    try {
      return (await read(), null);
    } on AppFailure catch (error) {
      return (null, error);
    } catch (_) {
      return (
        null,
        const AppFailure(
          'invalid_response',
          'Some product information could not be read. Please retry search.',
        ),
      );
    }
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    if (_query.length < 2 || !widget.active) return;
    final query = _query;
    // Pagination belongs to the query that produced these cursors.
    more = more && query == _resultsQuery;
    final request = ++_request;
    var replaced = more;
    setState(() {
      _busy = true;
      _error = null;
    });

    void accept(VoidCallback update) {
      if (!mounted || request != _request) return;
      setState(() {
        if (!replaced) {
          _discardThumbnails();
          _reports.clear();
          _items.clear();
          _researchItems.clear();
          _page = null;
          _researchPage = null;
          _offRetryPending = false;
          _researchRetryPending = false;
          _offSearchError = null;
          _researchSearchError = null;
          _resultsQuery = query;
          replaced = true;
        }
        update();
        final messages = [
          _offSearchError,
          _researchSearchError,
        ].whereType<String>().toSet().toList();
        _error = messages.isEmpty ? null : messages.join(' ');
      });
    }

    final skipOff =
        more &&
        (_items.length >= 100 ||
            (!_offRetryPending && _page?.nextCursor == null));
    final skipResearch =
        more &&
        (_researchItems.length >= 100 ||
            (!_researchRetryPending && _researchPage?.nextCursor == null));
    final offFuture = skipOff
        ? Future<(SearchPage?, AppFailure?)>.value((_page, null))
        : _readSource(
            () => widget.repository.search(
              query,
              cursor: more ? _page?.nextCursor : null,
            ),
          );
    final researchFuture = skipResearch
        ? Future<(ResearchSearchPage?, AppFailure?)>.value((
            _researchPage,
            null,
          ))
        : _readSource(
            () => widget.repository.searchResearch(
              query,
              cursor: more ? _researchPage?.nextCursor : null,
            ),
          );

    try {
      // Each source becomes readable as soon as it finishes. A slow or failed
      // source does not discard the other source's results or pagination.
      await Future.wait([
        offFuture.then<void>((result) {
          final (page, error) = result;
          accept(() {
            _offSearchError = error?.userMessage;
            _offRetryPending = error != null;
            if (page == null) return;
            if (more && page.status == 'unavailable') {
              _offSearchError = 'Catalogue labels are temporarily unavailable.';
              _offRetryPending = true;
              return;
            }
            _page = page;
            final codes = _items.map((item) => item.barcode).toSet();
            for (final item in page.candidates) {
              if (codes.add(item.barcode) && _items.length < 100) {
                _items.add(item);
              }
            }
          });
        }),
        researchFuture.then<void>((result) {
          final (page, error) = result;
          accept(() {
            _researchSearchError = error?.userMessage;
            _researchRetryPending = error != null;
            if (page == null) return;
            if (more && page.status == 'unavailable') {
              _researchSearchError =
                  'Sourced product information is temporarily unavailable.';
              _researchRetryPending = true;
              return;
            }
            _researchPage = page;
            final ids = _researchItems.map((item) => item.entryId).toSet();
            for (final item in page.candidates) {
              if (ids.add(item.entryId) && _researchItems.length < 100) {
                _researchItems.add(item);
              }
            }
          });
        }),
      ]);
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

  Future<void> _openResearch(ResearchedCandidate item) async {
    if (_opening != null) return;
    final request = _request;
    _focus.unfocus();
    setState(() {
      _opening = item.entryId;
      _error = null;
    });
    try {
      final product = await widget.repository.loadResearchProduct(item.entryId);
      if (!mounted || request != _request) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResearchedProductPage(product: product),
        ),
      );
    } on AppFailure catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.userMessage);
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  String get _emptyStatus {
    final statuses = [_page?.status, _researchPage?.status];
    if (statuses.contains('ready') || statuses.contains('not_found')) {
      return 'not_found';
    }
    if (statuses.contains('refine_query')) return 'refine_query';
    return 'unavailable';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _page?.status == 'ready' || _researchPage?.status == 'ready';
    final showItems =
        _query.length >= 2 && (_items.isNotEmpty || _researchItems.isNotEmpty);
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
                        if (_busy && _items.isEmpty && _researchItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SearchSkeleton(),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          StatusNotice(
                            title: showItems
                                ? 'Some sources could not be loaded'
                                : 'Search could not be completed',
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
                            (_page != null || _researchPage != null) &&
                            (!ready || !showItems))
                          StatusNotice(
                            title: switch (_emptyStatus) {
                              'refine_query' =>
                                'Add a more specific name or brand',
                              'unavailable' =>
                                'Catalogue search is unavailable',
                              _ => 'No matches for “$_query”',
                            },
                            message: _emptyStatus == 'unavailable'
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
                                  : '${_items.length + _researchItems.length} product records shown',
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
                if (showItems && _researchItems.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _researchItems.length,
                      itemBuilder: (context, index) {
                        final item = _researchItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              key: ValueKey('research-${item.entryId}'),
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(item.name),
                              subtitle: Text(
                                [
                                  if (item.brand != null) item.brand!,
                                  if (item.variant != null &&
                                      !item.name.toLowerCase().contains(
                                        item.variant!.toLowerCase(),
                                      ))
                                    item.variant!,
                                  item.quantity ?? 'Pack size unknown',
                                  researchProviderLabel(item.provider),
                                  'Collected ${item.source.retrievedAt.substring(0, 10)}',
                                  if (item.eligibility == 'conflicting')
                                    'Conflicting source information',
                                ].join(' · '),
                              ),
                              trailing: _opening == item.entryId
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _opening != null || _query != _resultsQuery
                                  ? null
                                  : () => _openResearch(item),
                            ),
                          ),
                        );
                      },
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
                            onTap: _opening != null || _query != _resultsQuery
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
                        (((_page?.nextCursor != null || _offRetryPending) &&
                                    _items.length < 100) ||
                                ((_researchPage?.nextCursor != null ||
                                        _researchRetryPending) &&
                                    _researchItems.length < 100)) &&
                            showItems &&
                            (_items.length < 100 || _researchItems.length < 100)
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
