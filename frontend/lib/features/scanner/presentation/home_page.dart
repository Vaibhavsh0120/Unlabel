import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import 'insights_page.dart';
import 'library_page.dart';
import 'sources_page.dart';
import 'ui_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.store,
    required this.onLookup,
    required this.onEnterLabel,
    required this.onOpenReport,
    required this.onLibrary,
    required this.refreshKey,
    this.onCompare,
    super.key,
  });

  final LocalStore store;
  final ValueChanged<bool> onLookup;
  final VoidCallback onEnterLabel;
  final ValueChanged<ProductReport> onOpenReport;
  final ValueChanged<int> onLibrary;
  final int refreshKey;
  final VoidCallback? onCompare;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<LocalReport> _recent = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.store != widget.store) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _recent = [];
      _error = null;
    });
    try {
      final history = await widget.store.history();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _recent = history.take(3).toList();
        _error = null;
      });
    } on AppFailure catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error.userMessage);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _showInsights() =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const InsightsPage()));

  void _showSources() =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const SourcesPage()));

  @override
  Widget build(BuildContext context) => PageBody(
    maxWidth: 1120,
    children: [
      _ScanHero(onScan: widget.onEnterLabel),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final columns = constraints.maxWidth >= 340 && !largeText ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          final cards = [
            _ActionCard(
              width: width,
              icon: const FeatureIcon('barcode'),
              title: 'Barcode Scan',
              description: 'Find a food label',
              onTap: () => widget.onLookup(true),
            ),
            _ActionCard(
              width: width,
              icon: widget.onCompare == null
                  ? const FeatureIcon('leaf')
                  : const Icon(Icons.balance_outlined, size: 28),
              title: widget.onCompare == null
                  ? 'Search Products'
                  : 'Compare Products',
              description: widget.onCompare == null
                  ? 'Find by name or brand'
                  : 'Compare the facts',
              onTap: widget.onCompare ?? () => widget.onLookup(false),
            ),
            _ActionCard(
              width: width,
              icon: const FeatureIcon('bookmark'),
              title: 'Saved Products',
              description: 'Your food finds',
              onTap: () => widget.onLibrary(1),
            ),
            _ActionCard(
              width: width,
              icon: const FeatureIcon('history'),
              title: 'History',
              description: 'Your past scans',
              onTap: () => widget.onLibrary(2),
            ),
          ];
          return Column(
            key: const Key('home-actions-grid'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index += columns) ...[
                if (index > 0) const SizedBox(height: 16),
                if (columns == 1)
                  cards[index]
                else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cards[index],
                        const SizedBox(width: 16),
                        cards[index + 1],
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Today’s Insight',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: _showInsights,
              label: const Text('See all'),
              icon: const Icon(Icons.chevron_right, size: 20),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
      const _InsightCarousel(),
      SectionTitle(
        'Recent scans',
        trailing: TextButton.icon(
          onPressed: () => widget.onLibrary(2),
          label: const Text('See all'),
          icon: const Icon(Icons.chevron_right, size: 20),
          iconAlignment: IconAlignment.end,
        ),
      ),
      if (_loading)
        const BusyNotice('Loading your recent labels…')
      else if (_error != null)
        StatusNotice(
          title: 'History could not be loaded',
          message: _error!,
          action: OutlinedButton(
            onPressed: _refresh,
            child: const Text('Retry'),
          ),
        )
      else if (_recent.isEmpty)
        LibraryEmptyState(
          title: 'Your first food find starts here',
          message: 'The labels you explore will appear here.',
          action: TextButton.icon(
            onPressed: widget.onEnterLabel,
            icon: const FeatureIcon('scanner', size: 22),
            label: const Text('Start Scan'),
          ),
        )
      else
        for (final item in _recent) ...[
          _RecentRow(item: item, onTap: () => widget.onOpenReport(item.report)),
          const SizedBox(height: 12),
        ],
      const SizedBox(height: 32),
      _SourcesCard(onTap: _showSources),
    ],
  );
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final compact = constraints.maxWidth < 560;
        final roomy = constraints.maxWidth >= 650;
        final copy = Column(
          key: const Key('home-scan-copy'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KNOW WHAT’S INSIDE',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: compact ? 9 : 12,
                letterSpacing: compact ? .7 : 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              'Scan your\nfood label',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: roomy ? 42 : 24,
                height: 1.12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              'Read nutrition, ingredients and claims.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: compact ? 13 : 16,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
            FilledButton.icon(
              key: const Key('start-lookup'),
              onPressed: onScan,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: dark ? theme.colorScheme.surface : null,
                foregroundColor: dark ? theme.colorScheme.onSurface : null,
                textStyle: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 20,
                  vertical: 12,
                ),
                side: dark
                    ? BorderSide(color: theme.colorScheme.primary, width: 1.4)
                    : BorderSide.none,
              ),
              icon: const FeatureIcon('scanner', size: 20, color: Colors.white),
              label: const Text('Start Scan'),
            ),
          ],
        );
        final background = Image.asset(
          dark
              ? 'assets/artwork/scan-hero-dark.png'
              : 'assets/artwork/scan-hero-light.png',
          key: const Key('home-hero-background'),
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        );
        return Container(
          key: const Key('home-scan-hero'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            color: dark ? const Color(0xff171b1e) : const Color(0xfff0faf5),
          ),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(padding: const EdgeInsets.all(20), child: copy),
                    SizedBox(height: 120, child: background),
                  ],
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxWidth / (compact ? 1.85 : 2.8))
                        .clamp(180, 360),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: IgnorePointer(child: background)),
                      // Keep live copy on a quiet, opaque surface at every ratio.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  dark
                                      ? const Color(0xff171b1e)
                                      : const Color(0xfff0faf5),
                                  dark
                                      ? const Color(0xff171b1e)
                                      : const Color(0xfff0faf5),
                                  (dark
                                          ? const Color(0xff171b1e)
                                          : const Color(0xfff0faf5))
                                      .withValues(alpha: 0),
                                ],
                                stops: const [0, .48, .68],
                              ),
                            ),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: .62,
                        child: Padding(
                          padding: roomy
                              ? const EdgeInsets.all(28)
                              : const EdgeInsets.fromLTRB(16, 16, 4, 16),
                          child: copy,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
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
  final Widget icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = width < 340;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: compact ? 13 : null,
            height: compact ? 1.2 : 1.3,
          ),
        ),
        SizedBox(height: compact ? 3 : 4),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: compact ? 12 : null,
            height: compact ? 1.3 : 1.4,
          ),
        ),
      ],
    );
    final iconTile = Container(
      padding: EdgeInsets.all(compact ? 6 : 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
      ),
      child: IconTheme(
        data: IconThemeData(color: theme.colorScheme.primary),
        child: SizedBox.square(
          dimension: compact ? 20 : 28,
          child: FittedBox(child: icon),
        ),
      ),
    );
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (width / (width >= 240 && compact ? 4.5 : 2.6)).clamp(
            64,
            88,
          ),
        ),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 18,
                vertical: compact ? 8 : 14,
              ),
              child: Row(
                children: [
                  iconTile,
                  SizedBox(width: compact ? 8 : 16),
                  Expanded(child: words),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelTip {
  const _LabelTip({
    required this.title,
    required this.summary,
    required this.detail,
    required this.asset,
  });

  final String title, summary, detail, asset;
}

// These explanations are the same reviewed label-reading tips in InsightsPage.
// Decorative pictures illustrate the app, never a reported product or score.
const _labelTips = [
  _LabelTip(
    title: 'Start with the serving size',
    summary: 'Check the printed amount before comparing nutrition numbers.',
    detail: 'The table may describe 100 g, 100 ml or one serving. Read its printed basis before using a number.',
    asset: 'assets/artwork/breakfast-leaf.png',
  ),
  _LabelTip(
    title: 'Compare the same amount',
    summary: 'Use the same amount when comparing two products.',
    detail: 'Use the same basis for both products. A smaller serving can make a number look lower.',
    asset: 'assets/artwork/label-leaf.png',
  ),
  _LabelTip(
    title: 'Missing does not mean zero',
    summary: 'Missing label information stays unknown.',
    detail: 'When a nutrient or ingredient is missing, Unlabel keeps it unknown. Check your package for the current details.',
    asset: 'assets/artwork/botanical-corner.png',
  ),
  _LabelTip(
    title: 'Total sugar and added sugar differ',
    summary: 'Read total sugar and added sugar as separate rows.',
    detail: 'Total sugar can include naturally occurring sugar and added sugar. Read each declared row separately.',
    asset: 'assets/artwork/sugar-cubes.png',
  ),
];

class _InsightCarousel extends StatefulWidget {
  const _InsightCarousel();

  @override
  State<_InsightCarousel> createState() => _InsightCarouselState();
}

class _InsightCarouselState extends State<_InsightCarousel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Label tips');
  int _selected = 0;
  double _dragDistance = 0;
  int _slideDirection = 1;

  void _select(int index) {
    final selected = (index + _labelTips.length) % _labelTips.length;
    if (selected == _selected) return;
    setState(() {
      _slideDirection = index > _selected ? 1 : -1;
      _selected = selected;
    });
  }

  void _openTip(_LabelTip tip) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => _InsightDetailPage(tip: tip)));

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const duration = Duration(milliseconds: 180);
    final tip = _labelTips[_selected];
    final card = _InsightCard(
      key: ValueKey(_selected),
      tip: tip,
      onTap: () => _openTip(tip),
    );
    return Focus(
      key: const Key('insight-keyboard-focus'),
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _select(_selected + (rtl ? -1 : 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _select(_selected + (rtl ? 1 : -1));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        key: const Key('insight-adjustable'),
        container: true,
        explicitChildNodes: true,
        label: 'Label tips',
        value: 'Tip ${_selected + 1} of ${_labelTips.length}',
        increasedValue:
            'Tip ${(_selected + 1) % _labelTips.length + 1} of ${_labelTips.length}',
        decreasedValue:
            'Tip ${(_selected - 1 + _labelTips.length) % _labelTips.length + 1} of ${_labelTips.length}',
        onIncrease: () => _select(_selected + 1),
        onDecrease: () => _select(_selected - 1),
        child: Column(
          key: const Key('home-insight-carousel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onHorizontalDragStart: (_) => _dragDistance = 0,
              onHorizontalDragUpdate: (event) =>
                  _dragDistance += event.delta.dx,
              onHorizontalDragEnd: (event) {
                final velocity = event.primaryVelocity ?? 0;
                if (_dragDistance.abs() < 32 && velocity.abs() < 250) return;
                final forward =
                    (_dragDistance == 0 ? velocity : _dragDistance) < 0;
                _select(_selected + (forward != rtl ? 1 : -1));
              },
              child: reduced
                  ? card
                  : AnimatedSize(
                      duration: duration,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: Offset(
                                    _slideDirection * (rtl ? -.08 : .08),
                                    0,
                                  ),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                            child: child,
                          ),
                        ),
                        child: card,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _labelTips.length; index++)
                    Semantics(
                      key: Key('insight-page-$index'),
                      selected: index == _selected,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          index == _selected
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: index == _selected ? 8 : 6,
                          color: index == _selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.tip, required this.onTap, super.key});
  final _LabelTip tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('home-insight-card'),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            final compact = constraints.maxWidth < 560;
            final text = Padding(
              key: const Key('home-insight-copy'),
              padding: compact && !stacked
                  ? const EdgeInsets.fromLTRB(20, 20, 8, 20)
                  : const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FeatureIcon('lightbulb', size: compact ? 22 : 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'LABEL TIP',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: compact ? 10 : null,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tip.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: compact ? 18 : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tip.summary,
                    style:
                        (compact
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.bodyLarge)
                            ?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                  ),
                ],
              ),
            );
            final art = CornerArtwork(
              key: const Key('home-insight-art'),
              asset: tip.asset,
              height: stacked
                  ? 120
                  : compact
                  ? 180
                  : 210,
              scale: 1,
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      text,
                      Align(
                        alignment: Alignment.bottomRight,
                        child: FractionallySizedBox(
                          widthFactor: .5,
                          child: art,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 6, child: text),
                      Expanded(flex: 4, child: art),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _InsightDetailPage extends StatelessWidget {
  const _InsightDetailPage({required this.tip});
  final _LabelTip tip;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Label tip')),
    body: PageBody(
      maxWidth: 760,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text(tip.detail, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              CornerArtwork(asset: tip.asset, height: 160),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const InsightsPage())),
          icon: const FeatureIcon('lightbulb'),
          label: const Text('All label tips'),
        ),
      ],
    ),
  );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item, required this.onTap});
  final LocalReport item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              StoredProductPhoto(report: item.report, size: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.report.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (item.report.brand?.isNotEmpty ?? false)
                          item.report.brand!,
                        item.report.basisLabel,
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const FeatureIcon('shield', size: 30),
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
                      'Open Food Facts, your confirmed label and reviewed FSSAI guidance.',
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
    );
  }
}
