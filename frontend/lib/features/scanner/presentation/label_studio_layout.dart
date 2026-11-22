import 'package:flutter/material.dart';

import 'ui_components.dart';

enum StudioSection { overview, nutrition, ingredients, claims, sources, sugar }

/// Typed section boundaries keep navigation independent of displayed wording.
class StudioSectionTitle extends SectionTitle {
  const StudioSectionTitle(
    this.section,
    super.title, {
    super.topSpacing,
    super.key,
  });
  final StudioSection section;
}

class StudioBlock {
  const StudioBlock(this.section, this.title, this.children);
  final StudioSection section;
  final String title;
  final List<Widget> children;
}

class LabelStudioLayout extends StatefulWidget {
  const LabelStudioLayout({
    required this.header,
    required this.blocks,
    super.key,
  });
  final Widget header;
  final List<StudioBlock> blocks;
  @override
  State<LabelStudioLayout> createState() => _LabelStudioLayoutState();
}

class _LabelStudioLayoutState extends State<LabelStudioLayout> {
  final _top = GlobalKey();
  final _anchors = <StudioSection, GlobalKey>{};
  StudioSection _selected = StudioSection.overview;

  void _go(StudioSection section) {
    final target = section == StudioSection.overview ? _top : _anchors[section];
    final context = target?.currentContext;
    if (context == null) return;
    setState(() => _selected = section);
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      alignment: section == StudioSection.overview ? 0 : .15,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final compact = constraints.maxWidth < 600;
      final wide =
          constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(16) < 25;
      final inset = compact ? 16.0 : 24.0;
      final pageWidth = constraints.maxWidth.clamp(0.0, 1480.0);
      final margin = (constraints.maxWidth - pageWidth) / 2 + inset;
      final used = <StudioBlock>{};
      Widget block(StudioBlock item) {
        final first = identical(
          widget.blocks.firstWhere((b) => b.section == item.section),
          item,
        );
        return Padding(
          key: first ? (_anchors[item.section] ??= GlobalKey()) : null,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(item.title, style: theme.textTheme.titleMedium),
                ),
              ...item.children,
            ],
          ),
        );
      }

      List<StudioBlock> take(StudioSection section, {int? limit}) {
        final found = widget.blocks
            .where((b) => b.section == section)
            .take(limit ?? widget.blocks.length)
            .toList();
        used.addAll(found);
        return found;
      }

      final nutrition = take(StudioSection.nutrition, limit: 1);
      final ingredients = take(StudioSection.ingredients, limit: 1);
      final sugar = take(StudioSection.sugar);
      final evidence = take(StudioSection.overview);
      final columns = [
        nutrition,
        [...ingredients, ...sugar],
        evidence,
      ];
      final rest = widget.blocks.where((b) => !used.contains(b)).toList();
      final body = <Widget>[
        if (wide)
          Row(
            key: const Key('results-desktop-columns'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  flex: i == 2 ? 3 : 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: columns[i].map(block).toList(),
                  ),
                ),
              ],
            ],
          )
        else ...[
          ...nutrition.map(block),
          ...sugar.map(block),
          ...ingredients.map(block),
          ...evidence.map(block),
        ],
        LayoutBuilder(
          builder: (context, area) {
            final count = wide ? 2 : 1;
            final width = (area.maxWidth - 16 * (count - 1)) / count;
            return Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final item in rest)
                  SizedBox(width: width, child: block(item)),
              ],
            );
          },
        ),
      ];
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(margin, 20, margin, 16),
            sliver: SliverToBoxAdapter(
              child: KeyedSubtree(key: _top, child: widget.header),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StudioTabs(
              height: (MediaQuery.textScalerOf(context).scale(18) + 32).clamp(
                60.0,
                120.0,
              ),
              background: theme.colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (section, title) in const [
                        (StudioSection.overview, 'Overview'),
                        (StudioSection.nutrition, 'Nutrition'),
                        (StudioSection.ingredients, 'Ingredients'),
                        (StudioSection.claims, 'Claims'),
                        (StudioSection.sources, 'Sources'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TextButton(
                            key: ValueKey('studio-tab-${section.name}'),
                            style: TextButton.styleFrom(
                              backgroundColor: _selected == section
                                  ? const Color(0xff155b4b)
                                  : Colors.transparent,
                              foregroundColor: _selected == section
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                section == StudioSection.overview ||
                                    widget.blocks.any(
                                      (b) => b.section == section,
                                    )
                                ? () => _go(section)
                                : null,
                            child: Text(title),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin,
              20,
              margin,
              40 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _StudioTabs extends SliverPersistentHeaderDelegate {
  _StudioTabs({
    required this.child,
    required this.background,
    this.height = 60,
  });
  final Widget child;
  final Color background;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: background,
    child: SizedBox.expand(
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
  @override
  bool shouldRebuild(covariant _StudioTabs oldDelegate) => true;
}
