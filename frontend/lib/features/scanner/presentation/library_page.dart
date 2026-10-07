import 'package:flutter/material.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import 'ui_components.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    required this.saved,
    required this.store,
    required this.onOpenReport,
    required this.onLookup,
    required this.onChanged,
    required this.refreshKey,
    super.key,
  });

  final bool saved;
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.saved != widget.saved) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorKind = null;
    });
    try {
      final items = widget.saved
          ? await widget.store.saved()
          : await widget.store.history();
      if (mounted) {
        setState(() {
          _items = items;
          _warning = widget.store.recoveryWarning;
        });
      }
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.userMessage;
          _errorKind = error.kind;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
      Text(
        widget.saved ? 'Saved products' : 'Your history',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
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
        StatusNotice(
          title: widget.saved
              ? 'Keep a useful label close'
              : 'No labels viewed yet',
          message: widget.saved
              ? 'Open a report and choose Save to find it here later.'
              : 'Look up a product or enter a label to start your history.',
          icon: widget.saved ? Icons.bookmark_outline : Icons.history_outlined,
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FeatureIcon(widget.saved ? 'bookmark' : 'history'),
                    title: Text(item.report.name),
                    subtitle: Text(
                      [
                        if (item.report.brand?.isNotEmpty ?? false)
                          item.report.brand!,
                        item.report.basisLabel,
                        'Viewed ${_date(item.storedAt)}',
                      ].join('\n'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenReport(item.report),
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
