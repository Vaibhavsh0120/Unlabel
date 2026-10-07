import 'package:flutter/material.dart';

import 'sources_page.dart';
import 'ui_components.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Label Insights')),
    body: PageBody(
      maxWidth: 760,
      children: [
        const _InsightsIntro(),
        const SizedBox(height: 28),
        const _Tip(
          icon: Icons.straighten_outlined,
          title: 'Start with the serving size',
          body: 'The table may describe 100 g, 100 ml or one serving. Read its printed basis before using a number.',
        ),
        const SizedBox(height: 16),
        const Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text('More label reading tips'),
            tilePadding: EdgeInsets.all(20),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _Tip(
                icon: Icons.compare_arrows,
                title: 'Compare the same amount',
                body: 'Use the same basis for both products. A smaller serving can make a number look lower.',
              ),
              SizedBox(height: 16),
              _Tip(
                icon: Icons.help_outline,
                title: 'Missing does not mean zero',
                body: 'When a nutrient or ingredient is missing, Unlabel keeps it unknown. Check your package for the current details.',
              ),
              SizedBox(height: 16),
              _Tip(
                icon: Icons.grid_view_outlined,
                title: 'Total sugar and added sugar differ',
                body: 'Total sugar can include naturally occurring sugar and added sugar. Read each declared row separately.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const SourcesPage())),
          icon: const FeatureIcon('shield'),
          label: const Text('Where the facts come from'),
        ),
      ],
    ),
  );
}

class _InsightsIntro extends StatelessWidget {
  const _InsightsIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainer
          : theme.colorScheme.primaryContainer.withValues(alpha: .42),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final compact = constraints.maxWidth < 560;
          final copy = Padding(
            padding: compact && !stacked
                ? const EdgeInsets.fromLTRB(20, 20, 8, 20)
                : const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FeatureIcon('lightbulb', size: compact ? 24 : 30),
                const SizedBox(height: 12),
                Text(
                  'A little label clarity',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: compact ? 20 : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Small things to check before using a nutrition number.',
                  style:
                      (compact
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
          final art = CornerArtwork(
            asset: 'assets/artwork/breakfast-leaf.png',
            height: stacked
                ? 120
                : compact
                ? 160
                : 200,
            scale: 1,
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    Align(
                      alignment: Alignment.bottomRight,
                      child: FractionallySizedBox(widthFactor: .5, child: art),
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

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 30),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
