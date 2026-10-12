import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/interaction/ui_feedback.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/widgets/brand_mark.dart';
import '../domain/insight_catalogue.dart';
import '../domain/insight_controller.dart';
import 'sources_page.dart';
import 'app_shell.dart';
import 'ui_components.dart';

/// Daily reading feed. The app shell shares its controller with Home.
class InsightsPage extends StatefulWidget {
  const InsightsPage({
    this.controller,
    this.preferences,
    this.embedded = false,
    this.onSearch,
    this.onProfile,
    super.key,
  });
  final InsightController? controller;
  final PreferencesAdapter? preferences;
  final bool embedded;
  final VoidCallback? onSearch, onProfile;
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage>
    with WidgetsBindingObserver {
  late final InsightController _controller =
      widget.controller ?? InsightController(preferences: widget.preferences);
  bool _browseAll = false;
  @override
  void initState() {
    super.initState();
    // Resolve platform storage before registering a lifecycle observer.
    final controller = _controller;
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refreshDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _topic(InsightTopic topic) {
    setState(() => _browseAll = false);
    _controller.setTopic(topic);
  }

  void _open(InsightArticle article) => Navigator.of(context).push<void>(
    ShellContentRoute<void>(
      context: context,
      builder: (_) => AppShellScope.wrap(
        context,
        InsightArticlePage(article: article, controller: _controller),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 1000 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21;
          final articles = _browseAll ? _controller.all : _controller.visible;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InsightsHeading(
                wide: wide,
                showTitle:
                    !widget.embedded ||
                    (MediaQuery.sizeOf(context).width >= 1200 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 21),
              ),
              const SizedBox(height: 16),
              _TopicFilters(
                selected: _controller.selectedTopic,
                onSelect: _topic,
              ),
              const SizedBox(height: 20),
              if (_controller.error != null) ...[
                _StorageNotice(controller: _controller),
                const SizedBox(height: 16),
              ],
              if (articles.isNotEmpty) ...[
                _FeaturedInsight(
                  article: articles.first,
                  controller: _controller,
                  onOpen: () => _open(articles.first),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _browseAll
                            ? 'All insights'
                            : _controller.selectedTopic == InsightTopic.all
                            ? 'Today’s insights'
                            : '${_controller.selectedTopic.label} insights',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (!_browseAll &&
                        _controller.selectedTopic == InsightTopic.all)
                      Text(
                        '4 for today',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _InsightGrid(
                  articles: articles.skip(1).toList(),
                  controller: _controller,
                  onOpen: _open,
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('insights-browse-all'),
                  onPressed: () {
                    _controller.setTopic(InsightTopic.all);
                    setState(() => _browseAll = !_browseAll);
                  },
                  icon: Icon(
                    _browseAll
                        ? Icons.today_outlined
                        : Icons.library_books_outlined,
                  ),
                  label: Text(
                    _browseAll
                        ? 'Back to today’s four'
                        : 'Browse all 20 insights',
                  ),
                ),
              ),
              if (!wide) ...[
                const SizedBox(height: 20),
                _SavedInsights(
                  controller: _controller,
                  onOpen: _open,
                  inRail: false,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final open = AppShellScope.maybeOf(context)?.onSources;
                    if (open != null) {
                      open();
                    } else {
                      Navigator.of(context).push<void>(
                        ShellContentRoute<void>(
                          context: context,
                          builder: (_) =>
                              AppShellScope.wrap(context, const SourcesPage()),
                        ),
                      );
                    }
                  },
                  icon: const FeatureIcon('shield', size: 20),
                  label: const Text('Where the facts come from'),
                ),
              ),
            ],
          );
          return SingleChildScrollView(
            key: const Key('insights-scroll'),
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 16,
              20,
              wide ? 28 : 16,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 300,
                            child: Column(
                              children: [
                                _SavedInsights(
                                  controller: _controller,
                                  onOpen: _open,
                                  inRail: true,
                                ),
                                const SizedBox(height: 20),
                                _QuickTopics(onSelect: _topic),
                                const SizedBox(height: 20),
                                const _ReadingNote(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : main,
              ),
            ),
          );
        },
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Unlabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(width: 4),
            if (MediaQuery.textScalerOf(context).scale(14) <= 21)
              const BrandLeaf(),
          ],
        ),
        actions: [
          if (widget.onSearch != null)
            IconButton(
              onPressed: widget.onSearch,
              tooltip: 'Search products',
              icon: const FeatureIcon('magnifer'),
            ),
          if (widget.onProfile != null)
            IconButton(
              onPressed: widget.onProfile,
              tooltip: 'Profile',
              icon: const FeatureIcon('user'),
            ),
        ],
      ),
      body: content,
    );
  }
}

class _InsightsHeading extends StatelessWidget {
  const _InsightsHeading({required this.wide, required this.showTitle});
  final bool wide;
  final bool showTitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Semantics(
            header: true,
            child: Text(
              'Insights',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: wide ? 48 : 34,
                color: theme.colorScheme.brightness == Brightness.light
                    ? const Color(0xff072c25)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        if (showTitle) const SizedBox(height: 4),
        Text(
          'Simple guidance for healthier choices.',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: wide ? 20 : 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class InsightTopicIcon extends StatelessWidget {
  const InsightTopicIcon(this.topic, {this.size = 22, this.color, super.key});
  final InsightTopic topic;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.primary;
    return switch (topic) {
      InsightTopic.all => Icon(Icons.grid_view_rounded, size: size, color: ink),
      InsightTopic.sugar => Icon(
        Icons.view_in_ar_outlined,
        size: size,
        color: ink,
      ),
      InsightTopic.fibre => FeatureIcon('food-fibre', size: size, color: ink),
      InsightTopic.protein => FeatureIcon('dumbbell', size: size, color: ink),
      InsightTopic.claims => FeatureIcon('shield', size: size, color: ink),
      InsightTopic.ingredients => Icon(
        Icons.science_outlined,
        size: size,
        color: ink,
      ),
      InsightTopic.tips => Icon(Icons.bolt_outlined, size: size, color: ink),
      InsightTopic.swaps => Icon(
        Icons.swap_horiz_rounded,
        size: size,
        color: ink,
      ),
    };
  }
}

class _TopicFilters extends StatelessWidget {
  const _TopicFilters({required this.selected, required this.onSelect});
  final InsightTopic selected;
  final ValueChanged<InsightTopic> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final topic in InsightTopic.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('insight-topic-${topic.name}'),
              showCheckmark: false,
              avatar: InsightTopicIcon(
                topic,
                color: selected == topic
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
              label: Text(topic.label),
              selected: selected == topic,
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .22),
              labelStyle: TextStyle(
                color: selected == topic
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              onSelected: (_) => onSelect(topic),
            ),
          ),
      ],
    ),
  );
}

class _FeaturedInsight extends StatelessWidget {
  const _FeaturedInsight({
    required this.article,
    required this.controller,
    required this.onOpen,
  });
  final InsightArticle article;
  final InsightController controller;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('insight-featured'),
      color: theme.colorScheme.brightness == Brightness.dark
          ? theme.colorScheme.primaryContainer
          : const Color(0xffe4f8ef),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onOpen,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final stacked =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                final copy = Padding(
                  padding: EdgeInsets.fromLTRB(narrow ? 20 : 28, 28, 8, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FEATURED INSIGHT',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 1.8,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        article.title,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontSize: narrow ? 24 : 36,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        article.summary,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: narrow ? 14 : 18,
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ReadBadge(article: article),
                    ],
                  ),
                );
                final art = Padding(
                  padding: const EdgeInsets.fromLTRB(4, 28, 12, 12),
                  child: _ArticleArt(
                    article: article,
                    height: narrow ? 180 : 300,
                  ),
                );
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: copy,
                          ),
                          art,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 6, child: copy),
                          Expanded(flex: 5, child: art),
                        ],
                      );
              },
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: _Bookmark(article: article, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _ArticleArt extends StatelessWidget {
  const _ArticleArt({required this.article, required this.height});
  final InsightArticle article;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(article.asset, height: height, fit: BoxFit.contain),
  );
}

class _ReadBadge extends StatelessWidget {
  const _ReadBadge({required this.article});
  final InsightArticle article;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          article.quickTip ? Icons.bolt_rounded : Icons.menu_book_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            article.quickTip ? 'Quick tip' : '${article.readMinutes} min read',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}

class _Bookmark extends StatelessWidget {
  const _Bookmark({
    required this.article,
    required this.controller,
    this.compact = false,
  });
  final InsightArticle article;
  final InsightController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final saved = controller.isSaved(article.id);
    return IconButton(
      key: Key('insight-save-${article.id}'),
      tooltip: saved ? 'Unsave ${article.title}' : 'Save ${article.title}',
      isSelected: saved,
      alignment: compact ? Alignment.topCenter : Alignment.center,
      padding: compact ? const EdgeInsets.only(top: 6) : null,
      style: IconButton.styleFrom(
        backgroundColor: compact
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface.withValues(alpha: .82),
      ),
      onPressed: controller.loading || controller.saving
          ? null
          : () async {
              final success = await controller.toggleSaved(article.id);
              if (!context.mounted) return;
              if (success) unawaited(UiFeedback.confirmed());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? controller.isSaved(article.id)
                              ? 'Insight saved on this device'
                              : 'Insight removed from saved'
                        : controller.error ??
                              'Could not save. Please try again.',
                  ),
                ),
              );
            },
      color: saved
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 23,
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({
    required this.articles,
    required this.controller,
    required this.onOpen,
  });
  final List<InsightArticle> articles;
  final InsightController controller;
  final ValueChanged<InsightArticle> onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final large = MediaQuery.textScalerOf(context).scale(14) > 21;
      final columns = large || constraints.maxWidth < 340
          ? 1
          : constraints.maxWidth >= 760
          ? 3
          : 2;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      if (columns == 3) {
        return Column(
          children: [
            for (var start = 0; start < articles.length; start += columns) ...[
              if (start > 0) const SizedBox(height: gap),
              Table(
                // LayoutBuilder inside each tile needs real width constraints.
                // Measure natural heights first, then stretch this row to its
                // tallest card without an intrinsic-size probe or fixed height.
                defaultVerticalAlignment:
                    TableCellVerticalAlignment.intrinsicHeight,
                columnWidths: const {
                  1: FixedColumnWidth(gap),
                  3: FixedColumnWidth(gap),
                },
                children: [
                  TableRow(
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: gap),
                        if (start + column < articles.length)
                          _InsightTile(
                            article: articles[start + column],
                            controller: controller,
                            onOpen: () => onOpen(articles[start + column]),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ],
        );
      }
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < articles.length; i++)
            SizedBox(
              width:
                  columns == 2 &&
                      i == articles.length - 1 &&
                      articles.length.isOdd
                  ? constraints.maxWidth
                  : width,
              child: _InsightTile(
                article: articles[i],
                controller: controller,
                onOpen: () => onOpen(articles[i]),
              ),
            ),
        ],
      );
    },
  );
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.article,
    required this.controller,
    required this.onOpen,
    this.savedRow = false,
  });
  final InsightArticle article;
  final InsightController controller;
  final VoidCallback onOpen;
  final bool savedRow;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('insight-card-${article.id}'),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, tileConstraints) => Stack(
          fit: tileConstraints.hasBoundedHeight
              ? StackFit.expand
              : StackFit.loose,
          children: [
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 220 ||
                        MediaQuery.textScalerOf(context).scale(14) > 21;
                    final copy = Column(
                      key: Key('insight-copy-${article.id}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 32),
                          child: Text(
                            article.topic.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.1,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: savedRow ? 16 : 18,
                            height: 1.2,
                          ),
                        ),
                        if (!savedRow) ...[
                          const SizedBox(height: 8),
                          Text(
                            article.summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (savedRow) ...[
                          const SizedBox(height: 8),
                          _ReadBadge(article: article),
                        ],
                      ],
                    );
                    final art = Container(
                      key: Key('insight-art-${article.id}'),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: .24,
                        ),
                        borderRadius: BorderRadius.circular(savedRow ? 16 : 28),
                      ),
                      child: _ArticleArt(
                        article: article,
                        height: savedRow
                            ? 104
                            : stacked
                            ? 112
                            : 130,
                      ),
                    );
                    final content = stacked
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: art),
                              const SizedBox(height: 8),
                              copy,
                            ],
                          )
                        : Row(
                            key: Key('insight-content-${article.id}'),
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(width: savedRow ? 80 : 94, child: art),
                              const SizedBox(width: 8),
                              Expanded(child: copy),
                            ],
                          );
                    final badge = Align(
                      key: Key('insight-read-${article.id}'),
                      alignment: Alignment.centerLeft,
                      child: _ReadBadge(article: article),
                    );
                    // Table measures natural content once with unbounded
                    // height, then stretches each card to the tallest row.
                    // Flex only during that bounded pass so the picture and
                    // copy centre together above a badge pinned to the bottom.
                    if (constraints.hasBoundedHeight && !stacked && !savedRow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Center(child: content)),
                          const SizedBox(height: 12),
                          badge,
                        ],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        content,
                        if (!savedRow) ...[const SizedBox(height: 12), badge],
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: _Bookmark(
                article: article,
                controller: controller,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedInsights extends StatelessWidget {
  const _SavedInsights({
    required this.controller,
    required this.onOpen,
    required this.inRail,
  });
  final InsightController controller;
  final ValueChanged<InsightArticle> onOpen;
  final bool inRail;
  @override
  Widget build(BuildContext context) {
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Saved insights',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (controller.saved.isNotEmpty)
              TextButton(
                key: const Key('insights-see-saved'),
                onPressed: () => Navigator.of(context).push<void>(
                  ShellContentRoute<void>(
                    context: context,
                    builder: (_) => AppShellScope.wrap(
                      context,
                      _SavedInsightsPage(controller: controller),
                    ),
                  ),
                ),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Loading saved insights…'),
          )
        else if (controller.saved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Save an insight to read it again. Your collection stays on this device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final article in controller.saved.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InsightTile(
                article: article,
                controller: controller,
                savedRow: true,
                onOpen: () => onOpen(article),
              ),
            ),
      ],
    );
    return inRail
        ? Card(
            child: Padding(padding: const EdgeInsets.all(16), child: contents),
          )
        : contents;
  }
}

class _QuickTopics extends StatelessWidget {
  const _QuickTopics({required this.onSelect});
  final ValueChanged<InsightTopic> onSelect;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final entry in const [
            (InsightTopic.sugar, 'Added sugar, natural sugar and labels.'),
            (InsightTopic.fibre, 'Where to find fibre and how to read it.'),
            (InsightTopic.protein, 'Understand protein amounts and portions.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: .5),
                    child: InsightTopicIcon(entry.$1),
                  ),
                  title: Text(entry.$1.label),
                  subtitle: Text(
                    entry.$2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(entry.$1),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReadingNote extends StatelessWidget {
  const _ReadingNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      'Small knowledge.\nBrighter tomorrows.',
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _StorageNotice extends StatelessWidget {
  const _StorageNotice({required this.controller});
  final InsightController controller;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.error!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: controller.loading || controller.saving
                    ? null
                    : () => unawaited(controller.reloadSaved()),
                child: const Text('Retry saved insights'),
              ),
              TextButton(
                onPressed: () async {
                  final clear = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear saved insights?'),
                      content: const Text(
                        'This removes insight bookmarks on this device. You can save the articles again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear saved insights'),
                        ),
                      ],
                    ),
                  );
                  if (clear == true) await controller.clearSaved();
                },
                child: const Text('Clear saved insights'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SavedInsightsPage extends StatelessWidget {
  const _SavedInsightsPage({required this.controller});
  final InsightController controller;
  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Saved insights',
    selectedIndex: 5,
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PageBody(
        maxWidth: 1000,
        children: [
          if (controller.error != null) _StorageNotice(controller: controller),
          if (controller.saved.isEmpty)
            const Text(
              'No saved insights yet. Use a bookmark on any insight to save it here.',
            ),
          _InsightGrid(
            articles: controller.saved,
            controller: controller,
            onOpen: (article) => Navigator.of(context).push<void>(
              ShellContentRoute<void>(
                context: context,
                builder: (_) => AppShellScope.wrap(
                  context,
                  InsightArticlePage(article: article, controller: controller),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class InsightArticlePage extends StatelessWidget {
  const InsightArticlePage({
    required this.article,
    required this.controller,
    super.key,
  });
  final InsightArticle article;
  final InsightController controller;
  Future<void> _source(BuildContext context, InsightSource source) async {
    try {
      if (await launchUrl(
        Uri.parse(source.url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Keep the source available through its copy action. */
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
  }

  @override
  Widget build(BuildContext context) => ShellPage(
    title: 'Insight',
    selectedIndex: 5,
    actions: [
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) =>
            _Bookmark(article: article, controller: controller),
      ),
      const SizedBox(width: 8),
    ],
    body: PageBody(
      maxWidth: 760,
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _StorageNotice(controller: controller),
                ),
        ),
        Semantics(
          header: true,
          child: Text(
            article.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        Text(article.summary, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              article.topic.label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            _ReadBadge(article: article),
          ],
        ),
        _ArticleArt(article: article, height: 220),
        for (final section in article.sections) ...[
          Semantics(
            header: true,
            child: Text(
              section.heading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
        ],
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'On your next label',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                article.takeaway,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Sources', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Reviewed ${article.reviewedOn} · Illustrations explain a topic; they do not describe a scanned product.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final source in article.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    source.url,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _source(context, source),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open source'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: source.url),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Source link copied'),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not copy. Select the link above.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: const Text('Copy link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
