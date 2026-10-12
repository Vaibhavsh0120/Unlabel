import 'package:flutter/material.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import 'report_presentation.dart';
import 'ui_components.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    required this.saved,
    required this.store,
    required this.onOpenReport,
    required this.onLookup,
    required this.onChanged,
    required this.refreshKey,
    this.showTitle = true,
    super.key,
  });

  final bool saved;
  final bool showTitle;
  final LocalStore store;
  final ValueChanged<ProductReport> onOpenReport;
  final VoidCallback onLookup;
  final VoidCallback onChanged;
  final int refreshKey;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<LocalReport> _items = [];
  bool _loading = true;
  String? _error;
  String? _errorKind;
  String? _warning;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.saved != widget.saved ||
        oldWidget.store != widget.store) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _errorKind = null;
      _items = [];
      _warning = null;
    });
    try {
      final items = widget.saved
          ? await widget.store.saved()
          : await widget.store.history();
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _items = items;
          _warning = widget.store.recoveryWarning;
        });
      }
    } on AppFailure catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = error.userMessage;
          _errorKind = error.kind;
        });
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _remove(LocalReport item) async {
    try {
      await widget.store.removeSaved(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved products')),
      );
      widget.onChanged();
      await _refresh();
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  Future<void> _clearList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.saved ? 'Clear saved products?' : 'Clear history?'),
        content: Text(
          widget.saved
              ? 'Remove saved reports from this device. Your history will remain.'
              : 'Remove viewed reports from this device. Saved products will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.saved ? 'Clear saved products' : 'Clear history',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (widget.saved) {
        await widget.store.clearSaved();
      } else {
        await widget.store.clearHistory();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.saved ? 'Saved products cleared' : 'History cleared',
          ),
        ),
      );
      widget.onChanged();
      await _refresh();
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      if (widget.showTitle) ...[
        Text(
          widget.saved ? 'Saved products' : 'Your history',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
      ],
      const Text(
        'Stored on this device. These reports are snapshots of what you viewed.',
      ),
      const SizedBox(height: 24),
      if (!_loading && _error == null && _warning != null) ...[
        StatusNotice(
          title: 'Some local reports could not be opened',
          message: _warning!,
        ),
        const SizedBox(height: 16),
      ],
      if (_loading)
        const BusyNotice('Loading your reports…')
      else if (_error != null)
        StatusNotice(
          title: 'Reports could not be loaded',
          message: _error!,
          action: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
              if (_errorKind == 'local_data_corrupt')
                OutlinedButton(
                  onPressed: _clearList,
                  child: Text(
                    widget.saved ? 'Clear saved products' : 'Clear history',
                  ),
                ),
            ],
          ),
        )
      else if (_items.isEmpty)
        LibraryEmptyState(
          asset: widget.saved
              ? 'assets/artwork/saved-empty.webp'
              : 'assets/artwork/history-empty.webp',
          title: widget.saved
              ? 'Keep a useful label close'
              : 'No labels viewed yet',
          message: widget.saved
              ? 'Open a report and choose Save to find it here later.'
              : 'Scan a barcode or photograph a label to start your history.',
          action: FilledButton(
            onPressed: widget.onLookup,
            child: const Text('Look up a product'),
          ),
        )
      else ...[
        if (!widget.saved)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clearList,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear history'),
            ),
          ),
        for (final item in _items) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onOpenReport(item.report),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          StoredProductPhoto(report: item.report, size: 76),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.report.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (item.report.brand?.isNotEmpty ?? false)
                                      item.report.brand!,
                                    item.report.basisLabel,
                                    'Viewed ${_date(item.storedAt)}',
                                  ].join('\n'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 22),
                        ],
                      ),
                    ),
                  ),
                  if (widget.saved)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _remove(item),
                        icon: const Icon(Icons.bookmark_remove_outlined),
                        label: const Text('Remove'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ],
  );

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

/// Provider photos are distinct from decorative app artwork. Invalid or absent
/// descriptors use a neutral package icon, never a made-up product picture.
class StoredProductPhoto extends StatelessWidget {
  const StoredProductPhoto({required this.report, this.size = 76, super.key});

  final ProductReport report;
  final double size;

  @override
  Widget build(BuildContext context) {
    final descriptor = ReportImageDescriptor.fromReport(report);
    final fallback = Center(
      child: FeatureIcon('document-text', size: size * .4),
    );
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: descriptor == null
              ? fallback
              : Tooltip(
                  message:
                      '${descriptor.attribution} · ${descriptor.license}\n${descriptor.licenseUrl}',
                  child: Image.network(
                    descriptor.url,
                    fit: BoxFit.contain,
                    semanticLabel:
                        'Product photo of ${report.name}. ${descriptor.attribution}. ${descriptor.license}.',
                    loadingBuilder: (context, image, progress) =>
                        progress == null ? image : fallback,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    required this.asset,
    required this.title,
    required this.message,
    required this.action,
    super.key,
  });

  final String title;
  final String asset;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final mobile = constraints.maxWidth < 560;
          final guidance = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          if (mobile) {
            final stacked = constraints.maxWidth < 320 || largeText;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stacked) ...[
                    guidance,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 208,
                        child: CornerArtwork(
                          asset: asset,
                          height: 180,
                          animate: false,
                        ),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(child: guidance),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 144,
                          child: CornerArtwork(
                            asset: asset,
                            height: 180,
                            animate: false,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (stacked)
                    SizedBox(width: double.infinity, child: action)
                  else
                    action,
                ],
              ),
            );
          }
          final copy = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [guidance, const SizedBox(height: 20), action],
            ),
          );
          final art = CornerArtwork(asset: asset, height: 180);
          return largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    Align(
                      alignment: Alignment.bottomRight,
                      child: FractionallySizedBox(widthFactor: .65, child: art),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 6, child: copy),
                    Expanded(flex: 4, child: art),
                  ],
                );
        },
      ),
    );
  }
}
