import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/models/app_failure.dart';
import '../../../core/models/product_report.dart';
import '../../../core/storage/local_store.dart';
import '../domain/insight_catalogue.dart';
import '../domain/insight_controller.dart';
import 'insights_page.dart';
import 'app_shell.dart';
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
    this.onInsights,
    this.onSources,
    this.insightController,
    this.desktop = false,
    super.key,
  });

  final LocalStore store;
  final ValueChanged<bool> onLookup;
  final VoidCallback onEnterLabel;
  final ValueChanged<ProductReport> onOpenReport;
  final ValueChanged<int> onLibrary;
  final int refreshKey;
  final VoidCallback? onCompare;
  final VoidCallback? onInsights;
  final VoidCallback? onSources;
  final InsightController? insightController;
  final bool desktop;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<LocalReport> _recent = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;
  late InsightController _insights;
  late bool _ownsInsights;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachInsights();
    _refresh();
  }

  void _attachInsights() {
    _ownsInsights = widget.insightController == null;
    _insights =
        widget.insightController ??
        InsightController(preferences: widget.store.preferences);
    unawaited(_insights.start());
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insightController != widget.insightController ||
        (_ownsInsights && oldWidget.store != widget.store)) {
      if (_ownsInsights) _insights.dispose();
      _attachInsights();
    }
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.store != widget.store) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _insights.refreshDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsInsights) _insights.dispose();
    super.dispose();
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

  void _showInsights() {
    if (widget.onInsights != null) {
      widget.onInsights!();
      return;
    }
    Navigator.of(context).push<void>(
      ShellContentRoute<void>(
        context: context,
        builder: (_) => InsightsPage(controller: _insights),
      ),
    );
  }

  void _showSources() {
    if (widget.onSources != null) {
      widget.onSources!();
      return;
    }
    Navigator.of(context).push<void>(
      ShellContentRoute<void>(
        context: context,
        builder: (_) => AppShellScope.wrap(context, const SourcesPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageBody(
    maxWidth: widget.desktop ? 1800 : 1120,
    padding: widget.desktop ? const EdgeInsets.fromLTRB(24, 0, 24, 16) : null,
    children: [
      _ScanHero(onScan: widget.onEnterLabel, desktop: widget.desktop),
      SizedBox(height: widget.desktop ? 16 : 24),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final columns =
              widget.desktop && constraints.maxWidth >= 850 && !largeText
              ? 4
              : constraints.maxWidth >= 340 && !largeText
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          final cards = [
            _ActionCard(
              desktop: widget.desktop,
              width: width,
              icon: const FeatureIcon('barcode'),
              title: 'Barcode Scan',
              description: 'Find a food label',
              onTap: () => widget.onLookup(true),
            ),
            _ActionCard(
              desktop: widget.desktop,
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
              desktop: widget.desktop,
              width: width,
              icon: const FeatureIcon('bookmark'),
              title: 'Saved Products',
              description: 'Your food finds',
              onTap: () => widget.onLibrary(1),
            ),
            _ActionCard(
              desktop: widget.desktop,
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
                        for (
                          var offset = 0;
                          offset < columns && index + offset < cards.length;
                          offset++
                        ) ...[
                          if (offset > 0) const SizedBox(width: 16),
                          cards[index + offset],
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      Padding(
        padding: EdgeInsets.only(top: 12, bottom: widget.desktop ? 0 : 12),
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
      _InsightCarousel(controller: _insights, desktop: widget.desktop),
      SectionTitle(
        'Recent scans',
        compact: widget.desktop,
        topSpacing: 0,
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
        widget.desktop
            ? _DesktopEmptyScans(
                onScan: widget.onEnterLabel,
                onSaved: () => widget.onLibrary(1),
              )
            : _MobileEmptyScans(onScan: widget.onEnterLabel)
      else if (widget.desktop)
        Row(
          key: const Key('desktop-recent-scans'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _recent.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _RecentRow(
                  item: _recent[i],
                  desktop: true,
                  onTap: () => widget.onOpenReport(_recent[i].report),
                ),
              ),
            ],
            for (var i = _recent.length; i < 3; i++) ...[
              const SizedBox(width: 12),
              const Spacer(),
            ],
          ],
        )
      else
        for (final item in _recent) ...[
          _RecentRow(item: item, onTap: () => widget.onOpenReport(item.report)),
          const SizedBox(height: 12),
        ],
      SizedBox(height: widget.desktop ? 12 : 32),
      _SourcesCard(onTap: _showSources, desktop: widget.desktop),
    ],
  );
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onScan, this.desktop = false});
  final VoidCallback onScan;
  final bool desktop;

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
              desktop ? 'Scan your food label' : 'Scan your\nfood label',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: desktop
                    ? (constraints.maxWidth >= 1200 ? 54 : 46)
                    : roomy
                    ? 42
                    : 24,
                height: 1.12,
                color: dark
                    ? theme.colorScheme.onSurface
                    : const Color(0xff073f34),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              desktop
                  ? 'Understand what’s really in your food\nwith clear, sourced label insights.'
                  : 'Read nutrition, ingredients and claims.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: desktop
                    ? 20
                    : compact
                    ? 13
                    : 16,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
            FilledButton.icon(
              key: const Key('start-lookup'),
              onPressed: onScan,
              style: FilledButton.styleFrom(
                minimumSize: Size(desktop ? 360 : 0, desktop ? 64 : 48),
                backgroundColor: dark ? theme.colorScheme.surface : null,
                foregroundColor: dark ? theme.colorScheme.onSurface : null,
                textStyle: TextStyle(
                  fontSize: desktop
                      ? 22
                      : compact
                      ? 14
                      : 16,
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
              label: desktop
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Start Scan'),
                        SizedBox(width: 48),
                        Icon(Icons.arrow_forward, size: 24),
                      ],
                    )
                  : const Text('Start Scan'),
            ),
          ],
        );
        final background = Image.asset(
          desktop
              ? 'assets/artwork/desktop-scan-hero.webp'
              : dark
              ? 'assets/artwork/scan-hero-dark.webp'
              : 'assets/artwork/scan-hero-light.webp',
          key: const Key('home-hero-background'),
          fit: desktop ? BoxFit.cover : BoxFit.contain,
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
                    minHeight: desktop
                        ? (constraints.maxWidth / 4.8).clamp(260, 310)
                        : (constraints.maxWidth / (compact ? 1.85 : 2.8)).clamp(
                            180,
                            360,
                          ),
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
                                stops: desktop
                                    ? const [0, .35, .58]
                                    : const [0, .48, .68],
                              ),
                            ),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: desktop ? .65 : .62,
                        child: Padding(
                          padding: desktop
                              ? const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 20,
                                )
                              : roomy
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
    this.desktop = false,
  });
  final double width;
  final Widget icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = width < 340 && !desktop;
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: desktop
                ? 15
                : compact
                ? 13
                : null,
            height: compact ? 1.2 : 1.3,
          ),
        ),
        SizedBox(height: compact ? 3 : 4),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: desktop
                ? 13
                : compact
                ? 12
                : null,
            height: compact ? 1.3 : 1.4,
          ),
        ),
      ],
    );
    final iconTile = Container(
      padding: EdgeInsets.all(
        desktop
            ? 12
            : compact
            ? 6
            : 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
      ),
      child: IconTheme(
        data: IconThemeData(color: theme.colorScheme.primary),
        child: SizedBox.square(
          dimension: desktop
              ? 28
              : compact
              ? 20
              : 28,
          child: FittedBox(child: icon),
        ),
      ),
    );
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: desktop
              ? 88
              : (width / (width >= 240 && compact ? 4.5 : 2.6)).clamp(64, 88),
        ),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: desktop
                    ? 12
                    : compact
                    ? 12
                    : 18,
                vertical: compact ? 8 : 14,
              ),
              child: Row(
                children: [
                  iconTile,
                  SizedBox(
                    width: desktop
                        ? 12
                        : compact
                        ? 8
                        : 16,
                  ),
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

class _InsightCarousel extends StatefulWidget {
  const _InsightCarousel({required this.controller, this.desktop = false});
  final InsightController controller;
  final bool desktop;

  @override
  State<_InsightCarousel> createState() => _InsightCarouselState();
}

class _InsightCarouselState extends State<_InsightCarousel> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Label tips');
  int _selected = 0;
  double _dragDistance = 0;
  int _slideDirection = 1;
  late String _dailyIdentity;

  @override
  void initState() {
    super.initState();
    _dailyIdentity = _identity;
    widget.controller.addListener(_dailyChanged);
  }

  String get _identity =>
      widget.controller.daily.map((article) => article.id).join('|');

  void _dailyChanged() {
    if (_dailyIdentity == _identity) return;
    setState(() {
      _dailyIdentity = _identity;
      _selected = 0;
    });
  }

  @override
  void didUpdateWidget(_InsightCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_dailyChanged);
      widget.controller.addListener(_dailyChanged);
      _dailyIdentity = _identity;
      _selected = 0;
    }
  }

  void _select(int index) {
    final tips = widget.controller.daily;
    final selected = (index + tips.length) % tips.length;
    if (selected == _selected) return;
    setState(() {
      _slideDirection = index > _selected ? 1 : -1;
      _selected = selected;
    });
  }

  void _openTip(InsightArticle tip) => Navigator.of(context).push<void>(
    ShellContentRoute<void>(
      context: context,
      builder: (_) => AppShellScope.wrap(
        context,
        InsightArticlePage(article: tip, controller: widget.controller),
      ),
    ),
  );

  @override
  void dispose() {
    widget.controller.removeListener(_dailyChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const duration = Duration(milliseconds: 180);
    final tips = widget.controller.daily;
    final tip = tips[_selected];
    final card = _InsightCard(
      key: ValueKey(_selected),
      tip: tip,
      onTap: () => _openTip(tip),
      desktop: widget.desktop,
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
        value: 'Tip ${_selected + 1} of ${tips.length}',
        increasedValue:
            'Tip ${(_selected + 1) % tips.length + 1} of ${tips.length}',
        decreasedValue:
            'Tip ${(_selected - 1 + tips.length) % tips.length + 1} of ${tips.length}',
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < tips.length; index++)
                  Semantics(
                    key: Key('insight-page-$index'),
                    selected: index == _selected,
                    button: true,
                    label: 'Show insight ${index + 1}: ${tips[index].title}',
                    onTap: () => _select(index),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 48,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 28,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _select(index),
                          tooltip: 'Show insight ${index + 1}',
                          icon: Icon(
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
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.tip,
    required this.onTap,
    this.desktop = false,
    super.key,
  });
  final InsightArticle tip;
  final VoidCallback onTap;
  final bool desktop;

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
            final art = desktop
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
                    child: Image.asset(
                      tip.asset,
                      key: const Key('home-insight-art'),
                      height: stacked ? 96 : 164,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      excludeFromSemantics: true,
                    ),
                  )
                : CornerArtwork(
                    key: const Key('home-insight-art'),
                    asset: tip.asset,
                    height: stacked ? 88 : 96,
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
                          widthFactor: .3,
                          child: art,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 7, child: text),
                      Expanded(flex: 3, child: art),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.item,
    required this.onTap,
    this.desktop = false,
  });
  final LocalReport item;
  final VoidCallback onTap;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(desktop ? 12 : 16),
          child: Row(
            children: [
              StoredProductPhoto(report: item.report, size: desktop ? 64 : 76),
              SizedBox(width: desktop ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.report.name,
                      maxLines: desktop ? 2 : null,
                      overflow: desktop ? TextOverflow.ellipsis : null,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: desktop ? 14 : null,
                      ),
                    ),
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
  const _SourcesCard({required this.onTap, this.desktop = false});
  final VoidCallback onTap;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.all(desktop ? 12 : 20),
          child: Row(
            children: [
              const FeatureIcon('shield', size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desktop
                          ? 'Data from package labels, manufacturer websites and Open Food Facts'
                          : 'Know where facts come from',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desktop
                          ? 'Source references stay attached. FSSAI guidance informs our label explanations.'
                          : 'Open Food Facts, your confirmed label and reviewed FSSAI guidance.',
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

class _MobileEmptyScans extends StatelessWidget {
  const _MobileEmptyScans({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const Key('mobile-empty-scans'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const FeatureIcon('barcode', size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No recent scans yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scans appear here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('mobile-empty-start-scan'),
              onPressed: onScan,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: FeatureIcon('scanner', size: 22, color: scheme.onPrimary),
              label: const Text('Start Scan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopEmptyScans extends StatelessWidget {
  const _DesktopEmptyScans({required this.onScan, required this.onSaved});
  final VoidCallback onScan, onSaved;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 760 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final artwork = SizedBox(
          key: const Key('desktop-empty-scans-art'),
          width: stacked ? 200 : 220,
          height: stacked ? 140 : 176,
          child: Image.asset(
            'assets/artwork/recent-scans-empty.webp',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        );
        final copy = Column(
          key: const Key('desktop-empty-scans-content'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No recent scans yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start scanning products to see them here.',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('desktop-empty-start-scan'),
                  onPressed: onScan,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(176, 56),
                  ),
                  icon: FeatureIcon(
                    'scanner',
                    size: 24,
                    color: colors.onPrimary,
                  ),
                  label: const Text('Start Scan'),
                ),
                TextButton.icon(
                  onPressed: onSaved,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
                  label: const Text('Browse saved products'),
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
          ],
        );
        return Card(
          key: const Key('desktop-empty-scans'),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primaryContainer.withValues(alpha: .32),
                  colors.surface,
                  colors.surface,
                  colors.primaryContainer.withValues(alpha: .28),
                ],
                stops: const [0, .3, .72, 1],
              ),
            ),
            child: Stack(
              children: [
                if (!stacked) ...[
                  Positioned(
                    right: -64,
                    bottom: -176,
                    width: 450,
                    height: 300,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(240),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -28,
                    bottom: -60,
                    width: 220,
                    height: 330,
                    child: IgnorePointer(
                      child: Transform.flip(
                        flipX: true,
                        child: SvgPicture.asset(
                          'assets/artwork/recent-scans-botanical.svg',
                          key: const Key('desktop-empty-scans-botanical'),
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            colors.primary.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? .18
                                  : .12,
                            ),
                            BlendMode.srcIn,
                          ),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 208),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(child: artwork),
                              const SizedBox(height: 20),
                              copy,
                            ],
                          )
                        : Row(
                            children: [
                              artwork,
                              const SizedBox(width: 32),
                              Expanded(child: copy),
                              SizedBox(
                                width: constraints.maxWidth >= 1100 ? 120 : 72,
                              ),
                            ],
                          ),
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
