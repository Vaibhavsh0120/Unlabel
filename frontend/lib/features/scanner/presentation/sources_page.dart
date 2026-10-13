import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'ui_components.dart';

const _sources = [
  _SourceInfo(
    id: 'facts',
    summary: 'Every fact keeps its source. Unknowns stay visible.',
    title: 'Facts with a source',
    icon: 'shield',
    artwork: 'assets/artwork/sources-facts.webp',
    body: 'Your confirmed package, dated product records and reviewed food guidance. Missing information stays unknown; disagreements stay visible.',
    detail: 'A report keeps the origin of a fact visible. Confirmed package facts and dated catalogue observations remain separate when they disagree.',
  ),
  _SourceInfo(
    id: 'package',
    summary: 'Facts confirmed from the label in your hand.',
    title: 'Your current package',
    icon: 'scanner',
    artwork: 'assets/artwork/sources-package.webp',
    body: 'Facts you check and confirm from your own label describe that package. Unlabel shows them separately from older catalogue records.',
    detail: 'Check the product identity, package size and nutrition basis before confirming a fact. An older record does not establish what is on your current package.',
  ),
  _SourceInfo(
    id: 'off',
    summary: 'Open catalogue records with their source and date.',
    title: 'Open Food Facts',
    icon: Icons.public_outlined,
    artwork: 'assets/artwork/sources-globe.webp',
    body: 'An open catalogue of packaged foods. Product records can be incomplete or older than the package in your hand. Their source and date stay attached to the facts.',
    url: 'https://world.openfoodfacts.org/',
    detail: 'Use the package in your hand to check the record. Missing values remain unknown, and a catalogue record is not proof of the current label.',
  ),
  _SourceInfo(
    id: 'fssai',
    summary: 'Reviewed guidance, not official product approval.',
    title: 'FSSAI guidance',
    icon: 'shield',
    artwork: 'assets/artwork/sources-guidance.webp',
    body: 'The Food Safety and Standards Authority of India publishes food rules.',
    url: 'https://www.fssai.gov.in/',
    detail: 'Unlabel explains reviewed claims, without representing FSSAI or certifying product approval or compliance.',
  ),
  _SourceInfo(
    id: 'codex',
    summary: 'What supported additives do, without a health verdict.',
    title: 'Codex ingredient functions',
    icon: Icons.menu_book_outlined,
    artwork: 'assets/artwork/sources-books.webp',
    body: 'A small reviewed glossary explains the technological role of supported additives. It does not give a health or allergy verdict.',
    url: 'https://www.fao.org/fao-who-codexalimentarius/en/',
    detail: 'An ingredient function explains its technological role. It does not establish permission for every food category or whether a product suits your allergies.',
  ),
  _SourceInfo(
    id: 'boundary',
    summary: 'Missing facts stay unknown. Labels stay product-specific.',
    title: 'A clear boundary for every fact',
    icon: Icons.info_outline,
    artwork: 'assets/artwork/sources-boundary.webp',
    body: 'Generic food values do not fill gaps in a branded product’s label. These explanations do not replace professional advice.',
    detail: 'Missing information is unknown, not zero. Unlabel does not turn incomplete evidence into a health, allergy-safety or compliance verdict.',
  ),
];

class _SourceInfo {
  const _SourceInfo({
    required this.id,
    required this.summary,
    required this.title,
    required this.body,
    required this.icon,
    required this.artwork,
    required this.detail,
    this.url,
  });
  final String id, title, body, artwork, detail;
  final String summary;
  final Object icon;
  final String? url;
}

class SourcesPage extends StatelessWidget {
  const SourcesPage({this.embedded = false, this.onBack, super.key});
  final bool embedded;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >= 1200 &&
        MediaQuery.textScalerOf(context).scale(14) <= 21;
    final body = PageBody(
      maxWidth: 1440,
      children: [
        _SourcesIntro(showHeading: embedded && desktop),
        const SizedBox(height: 24),
        for (final source in _sources) ...[
          _SourceCard(source),
          if (source != _sources.last) const SizedBox(height: 12),
        ],
      ],
    );
    return embedded ? body : ShellPage(title: 'Our Sources', body: body);
  }
}

class _SourcesIntro extends StatelessWidget {
  const _SourcesIntro({this.showHeading = false});
  final bool showHeading;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final compact = constraints.maxWidth < 600;
      final stacked =
          constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text('Our Sources', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
          ],
          Text(
            'Trusted sources, clear information',
            style: compact
                ? theme.textTheme.titleLarge
                : theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'We combine data from reliable and well-known sources to bring you product facts and food guidance. Here’s where our information comes from.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: compact ? 12 : 14,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      final art = _SourceArtwork(
        asset: 'assets/artwork/sources-intro.webp',
        width: compact ? 112 : 280,
        height: compact ? 128 : 160,
      );
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: art),
              ],
            )
          : Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 16),
                art,
              ],
            );
    },
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard(this.source);
  final _SourceInfo source;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final compact = constraints.maxWidth < 600;
      final stacked =
          constraints.maxWidth < 330 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: compact ? 14 : 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            source.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: compact ? 12 : 14,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (source.url != null && !compact) ...[
            const SizedBox(height: 8),
            SelectableText(source.url!, style: theme.textTheme.bodySmall),
            _CopySourceLink(url: source.url!, id: source.id),
          ],
        ],
      );
      final details = IconButton(
        key: Key('source-details-${source.id}'),
        tooltip: 'Read ${source.title} details',
        onPressed: () => _showSourceDetails(context, source),
        icon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
      );
      final art = _SourceArtwork(
        asset: source.artwork,
        width: compact ? 112 : 172,
        height: compact ? 112 : 104,
      );
      return Card(
        key: Key('source-card-${source.id}'),
        color: source.id == 'facts'
            ? theme.colorScheme.primaryContainer.withValues(alpha: .24)
            : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: compact ? Key('source-details-${source.id}') : null,
          onTap: () => _showSourceDetails(context, source),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _SourceIcon(source.icon, compact: compact),
                          const Spacer(),
                          if (!compact) details,
                        ],
                      ),
                      const SizedBox(height: 12),
                      copy,
                      Align(alignment: Alignment.centerRight, child: art),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SourceIcon(source.icon, compact: compact),
                      SizedBox(width: compact ? 8 : 24),
                      Expanded(child: copy),
                      SizedBox(width: compact ? 4 : 16),
                      art,
                      if (!compact) details,
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon(this.icon, {required this.compact});
  final Object icon;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: compact ? 48 : 56,
      height: compact ? 48 : 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: icon is String
          ? FeatureIcon(icon as String, size: 28)
          : Icon(icon as IconData, size: 28, color: scheme.primary),
    );
  }
}

class _SourceArtwork extends StatelessWidget {
  const _SourceArtwork({
    required this.asset,
    required this.width,
    required this.height,
  });
  final String asset;
  final double width, height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}

Future<void> _showSourceDetails(BuildContext context, _SourceInfo source) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  if (MediaQuery.sizeOf(context).width >= 720) {
    return showDialog<void>(
      context: context,
      animationStyle: reduced ? AnimationStyle.noAnimation : null,
      builder: (context) => Dialog(
        key: const Key('source-detail-window'),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: SizedBox(width: 640, child: _SourceDetailsBody(source)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
    builder: (context) =>
        SafeArea(top: false, child: _SourceDetailsBody(source)),
  );
}

class _SourceDetailsBody extends StatelessWidget {
  const _SourceDetailsBody(this.source);
  final _SourceInfo source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.5);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.primaryContainer.withValues(alpha: .24),
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
            child: Row(
              children: [
                _SourceIcon(source.icon, compact: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(source.title, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close source details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const Key('source-detail-scroll'),
              primary: false,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.body, style: bodyStyle),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: .5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Limits',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          source.detail,
                          style: bodyStyle?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (source.url != null) ...[
                    const SizedBox(height: 24),
                    Text('Website', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SelectableText(
                      source.url!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _CopySourceLink(url: source.url!, id: '${source.id}-sheet'),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 132,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopySourceLink extends StatefulWidget {
  const _CopySourceLink({required this.url, required this.id});
  final String url, id;
  @override
  State<_CopySourceLink> createState() => _CopySourceLinkState();
}

class _CopySourceLinkState extends State<_CopySourceLink> {
  String? _feedback;
  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.url));
      if (!mounted) return;
      setState(() => _feedback = 'Source link copied');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Source link copied')));
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _feedback = 'Could not copy. Select the address to copy it.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        key: Key('source-copy-${widget.id}'),
        onPressed: _copy,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.copy_outlined, size: 16),
        label: const Text('Copy website link'),
      ),
      if (_feedback != null)
        Semantics(
          liveRegion: true,
          child: Text(_feedback!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}
