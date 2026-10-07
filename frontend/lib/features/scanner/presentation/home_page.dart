import 'package:flutter/material.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import 'ui_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.store,
    required this.onLookup,
    required this.onEnterLabel,
    required this.onOpenReport,
    required this.onLibrary,
    required this.refreshKey,
    super.key,
  });

  final LocalStore store;
  final ValueChanged<bool> onLookup;
  final VoidCallback onEnterLabel;
  final ValueChanged<ProductReport> onOpenReport;
  final ValueChanged<int> onLibrary;
  final int refreshKey;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<LocalReport> _recent = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final history = await widget.store.history();
      if (!mounted) return;
      setState(() {
        _recent = history.take(3).toList();
        _error = null;
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageBody(
      maxWidth: 1120,
      children: [
        _Hero(onLookup: () => widget.onLookup(true)),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final columns = constraints.maxWidth >= 560 && !largeText ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ActionCard(
                  width: width,
                  icon: 'barcode',
                  title: 'Barcode lookup',
                  description: 'Use the code on your package',
                  onTap: () => widget.onLookup(true),
                ),
                _ActionCard(
                  width: width,
                  icon: 'leaf',
                  title: 'Search products',
                  description: 'Find by name or brand',
                  onTap: () => widget.onLookup(false),
                ),
                _ActionCard(
                  width: width,
                  icon: 'document-text',
                  title: 'Enter a label',
                  description: 'Use your current package',
                  onTap: widget.onEnterLabel,
                ),
                _ActionCard(
                  width: width,
                  icon: 'bookmark',
                  title: 'Saved products',
                  description: 'Keep reports on this device',
                  onTap: () => widget.onLibrary(1),
                ),
              ],
            );
          },
        ),
        SectionTitle(
          'Recently viewed',
          trailing: TextButton.icon(
            onPressed: () => widget.onLibrary(2),
            label: const Text('View history'),
            icon: const Icon(Icons.arrow_forward, size: 18),
          ),
        ),
        if (_error != null)
          StatusNotice(
            title: 'History could not be loaded',
            message: _error!,
            action: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          )
        else if (_recent.isEmpty)
          StatusNotice(
            title: 'Your first label starts here',
            message: 'Reports you view will appear here.',
            icon: Icons.history_outlined,
          )
        else
          for (final item in _recent) ...[
            _RecentRow(
              item: item,
              onTap: () => widget.onOpenReport(item.report),
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 28),
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Know where facts come from',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dated catalogue facts may differ from your package. Missing facts stay unknown.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onLookup});

  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.primaryContainer,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _LeavesPainter(
                  theme.colorScheme.primary.withValues(alpha: .09),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 400 ? 24 : 36,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Label Padhega India',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Understand your\nfood label',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 36
                          : 48,
                      height: 1.1,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Read nutrition, ingredients and package claims with clear, sourced explanations.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const Key('start-lookup'),
                    onPressed: onLookup,
                    icon: FeatureIcon(
                      'barcode',
                      color: theme.colorScheme.onPrimary,
                    ),
                    label: const Text('Look up a product'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeavesPainter extends CustomPainter {
  const _LeavesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var index = 0; index < 5; index++) {
      canvas.save();
      canvas.translate(size.width - 30 + index * 7, 35 + index * 75);
      canvas.rotate(-.7 + index * .2);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-150, -100, -170, 0)
        ..quadraticBezierTo(-70, 75, 0, 0);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter oldDelegate) => oldDelegate.color != color;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FeatureIcon(icon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item, required this.onTap});

  final LocalReport item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: const FeatureIcon('history'),
      title: Text(item.report.name),
      subtitle: Text(
        [
          if (item.report.brand?.isNotEmpty ?? false) item.report.brand!,
          item.report.basisLabel,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
