import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui_components.dart';

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Our Sources')),
    body: const PageBody(
      maxWidth: 760,
      children: [
        _SourcesIntro(),
        SizedBox(height: 28),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text('Read source details'),
            tilePadding: EdgeInsets.all(20),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _Source(
                title: 'Your current package',
                body: 'Facts you check and confirm from your own label describe that package. Unlabel shows them separately from older catalogue records.',
                icon: Icons.document_scanner_outlined,
              ),
              SizedBox(height: 16),
              _Source(
                title: 'Open Food Facts',
                body: 'An open catalogue of packaged foods. Product records can be incomplete or older than the package in your hand. Their source and date stay attached to the facts.',
                icon: Icons.public_outlined,
                url: 'https://world.openfoodfacts.org/',
              ),
              SizedBox(height: 16),
              _Source(
                title: 'FSSAI guidance',
                body: 'The Food Safety and Standards Authority of India publishes food rules. Unlabel uses reviewed evidence for the specific claims it supports; this is not official product approval.',
                icon: Icons.verified_user_outlined,
                url: 'https://www.fssai.gov.in/',
              ),
              SizedBox(height: 16),
              _Source(
                title: 'Codex ingredient functions',
                body: 'A small reviewed glossary explains the technological role of supported additives. It does not give a health or allergy verdict.',
                icon: Icons.menu_book_outlined,
                url: 'https://www.fao.org/fao-who-codexalimentarius/en/',
              ),
              SizedBox(height: 16),
              StatusNotice(
                title: 'A clear boundary for every fact',
                message: 'Generic food values do not fill gaps in a branded product’s label. These explanations do not replace professional advice.',
                icon: Icons.info_outline,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SourcesIntro extends StatelessWidget {
  const _SourcesIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.hardEdge,
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
                FeatureIcon('shield', size: compact ? 24 : 32),
                const SizedBox(height: 12),
                Text(
                  'Facts with a source',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: compact ? 20 : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your confirmed package, dated product records and reviewed food guidance. Missing information stays unknown; disagreements stay visible.',
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
            asset: 'assets/artwork/botanical-corner.png',
            height: stacked
                ? 120
                : compact
                ? 160
                : 180,
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

class _Source extends StatelessWidget {
  const _Source({
    required this.title,
    required this.body,
    required this.icon,
    this.url,
  });
  final String title;
  final String body;
  final IconData icon;
  final String? url;

  Future<void> _copyLink(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: url!));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Source link copied')));
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy the link. Select the address to copy it.',
            ),
          ),
        );
      }
    }
  }

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
          if (url != null) ...[
            const SizedBox(height: 16),
            SelectableText(url!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copyLink(context),
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy website link'),
            ),
          ],
        ],
      ),
    );
  }
}
