import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'ui_components.dart';
import '../../../core/widgets/brand_mark.dart';

class ResultsNavigation {
  const ResultsNavigation({
    required this.home,
    required this.scan,
    required this.history,
    required this.learn,
    required this.products,
    required this.profile,
    required this.notifications,
  });
  final VoidCallback home,
      scan,
      history,
      learn,
      products,
      profile,
      notifications;
}

/// Desktop results keep the supplied horizontal navigation; mobile keeps its
/// compact back/title bar. Every visible destination has a real app callback.
class ResultsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ResultsAppBar({required this.title, this.navigation, super.key});
  final String title;
  final ResultsNavigation? navigation;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) {
    final nav = navigation;
    if (nav == null ||
        MediaQuery.sizeOf(context).width < 1080 ||
        MediaQuery.textScalerOf(context).scale(16) >= 24) {
      return AppBar(title: Text(title));
    }
    final theme = Theme.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 32,
      title: Row(
        children: [
          TextButton(
            onPressed: nav.home,
            child: Row(
              children: [
                const BrandLeaf(size: 32),
                const SizedBox(width: 8),
                Text(
                  'Unlabel',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          TextButton(onPressed: nav.scan, child: const Text('Scan')),
          TextButton(onPressed: nav.history, child: const Text('History')),
          TextButton(onPressed: nav.learn, child: const Text('Learn')),
          TextButton(onPressed: nav.products, child: const Text('Products')),
          const Spacer(),
          SizedBox(
            width: MediaQuery.sizeOf(context).width > 1400 ? 360 : 270,
            child: TextButton.icon(
              onPressed: nav.products,
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: const FeatureIcon('magnifer', size: 20),
              label: const Text(
                'Search product, ingredient or claim…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            tooltip: 'Notifications',
            onPressed: nav.notifications,
            icon: const FeatureIcon('bell', size: 24),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Profile',
            onPressed: nav.profile,
            icon: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One responsive composition for confirmed, researched and machine-read facts.
/// The views supply their own evidence status; this layout invents no scores.
class ProductResultsLayout extends StatelessWidget {
  const ProductResultsLayout({
    required this.main,
    required this.aside,
    super.key,
  });
  final List<Widget> main, aside;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1080 &&
          MediaQuery.textScalerOf(context).scale(16) < 26;
      return Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : const Color(0xfff3fbf8),
        child: PageBody(
          maxWidth: 1480,
          children: [
            if (wide)
              Row(
                key: const Key('results-desktop-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _column(main)),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: _column(aside)),
                ],
              )
            else
              _column([...main, ...aside]),
          ],
        ),
      );
    },
  );

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

class ResultsIdentityCard extends StatelessWidget {
  const ResultsIdentityCard({
    required this.name,
    this.brand,
    this.variant,
    this.quantity,
    this.photo,
    this.imageUrl,
    this.imageDescription,
    this.actions,
    super.key,
  });
  final String name;
  final String? brand, variant, quantity, imageUrl, imageDescription;
  final Uint8List? photo;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Semantics(
      label: 'Product photo unavailable',
      child: const Center(child: FeatureIcon('document-text', size: 36)),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: MediaQuery.sizeOf(context).width < 500 ? 80 : 112,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerLow,
          child: photo != null
              ? Image.memory(
                  photo!,
                  fit: BoxFit.contain,
                  semanticLabel: 'Your session photo of $name',
                  errorBuilder: (_, _, _) => fallback,
                )
              : imageUrl != null
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  semanticLabel: imageDescription ?? 'Product photo of $name',
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleLarge),
        if (brand != null) ...[
          const SizedBox(height: 4),
          Text(brand!, style: theme.textTheme.bodyLarge),
        ],
        if (variant != null && variant != name) Text(variant!),
        Text(
          quantity ?? 'Pack size unknown',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
    return SectionCard(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 270 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 28;
              return stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [image, const SizedBox(height: 12), copy],
                    )
                  : Row(
                      children: [
                        image,
                        const SizedBox(width: 16),
                        Expanded(child: copy),
                      ],
                    );
            },
          ),
          if (actions != null) ...[const SizedBox(height: 12), actions!],
        ],
      ),
    );
  }
}

class ResultsSummaryCard extends StatelessWidget {
  const ResultsSummaryCard({
    required this.count,
    required this.heading,
    required this.message,
    required this.qualification,
    super.key,
  });
  final int count;
  final String heading, message, qualification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? const Color(0xffd3f5e5) : const Color(0xff10483b);
    final ring = Semantics(
      label: '$count recorded nutrition values. This is a fact count.',
      child: ExcludeSemantics(
        child: Container(
          width: MediaQuery.sizeOf(context).width < 500 ? 76 : 120,
          height: MediaQuery.sizeOf(context).width < 500 ? 76 : 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: dark ? const Color(0xff70cfa3) : const Color(0xff42bf85),
              width: 9,
            ),
          ),
          child: const Center(child: FeatureIcon('leaf', size: 44)),
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count ${count == 1 ? 'value' : 'values'}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: ink,
            fontSize: MediaQuery.sizeOf(context).width < 500 ? 34 : 44,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: dark ? const Color(0xff244b3b) : const Color(0xffd7f5e3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            heading,
            style: theme.textTheme.titleMedium?.copyWith(color: ink),
          ),
        ),
        const SizedBox(height: 10),
        Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: ink)),
        const SizedBox(height: 8),
        Text(
          qualification,
          style: theme.textTheme.bodySmall?.copyWith(color: ink),
        ),
      ],
    );
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= 275 &&
                MediaQuery.textScalerOf(context).scale(16) < 24
            ? Row(
                children: [
                  ring,
                  const SizedBox(width: 16),
                  Expanded(child: copy),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [ring, const SizedBox(height: 16), copy],
              ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: dark ? const Color(0xff182d24) : const Color(0xffeaf9ef),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: dark ? .12 : .20,
                child: Image.asset(
                  'assets/artwork/results-botanical.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class ResultsFact extends StatelessWidget {
  const ResultsFact({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    this.uncertain = false,
    this.grouped = false,
    super.key,
  });
  final String icon, title, detail, status;
  final bool uncertain, grouped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(child: FeatureIcon(icon, size: 26)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(detail),
              const SizedBox(height: 4),
              Text(
                status,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: uncertain
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return grouped
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: body,
          )
        : SectionCard(padding: 16, child: body);
  }
}

class ResultsFactsGrid extends StatelessWidget {
  const ResultsFactsGrid({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final two =
          constraints.maxWidth >= 600 &&
          MediaQuery.textScalerOf(context).scale(16) < 24;
      final width = two
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      if (!two && children.every((child) => child is ResultsFact)) {
        return SectionCard(
          padding: 12,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ResultsFact(
                  icon: (children[i] as ResultsFact).icon,
                  title: (children[i] as ResultsFact).title,
                  detail: (children[i] as ResultsFact).detail,
                  status: (children[i] as ResultsFact).status,
                  uncertain: (children[i] as ResultsFact).uncertain,
                  grouped: true,
                ),
              ],
            ],
          ),
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// A readable label on Flutter web as well as pointer-selectable package text.
class ResultsSelectableText extends StatelessWidget {
  const ResultsSelectableText(this.text, {this.style, super.key});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: text,
    excludeSemantics: true,
    child: SelectableText(text, style: style),
  );
}

class ResultsAllergenNotice extends StatelessWidget {
  const ResultsAllergenNotice({
    required this.contains,
    required this.mayContain,
    super.key,
  });
  final String? contains, mayContain;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declared = contains != null || mayContain != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: declared
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: declared
              ? theme.colorScheme.error.withValues(alpha: .3)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            declared ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 32,
            color: declared
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  declared
                      ? 'Allergen declarations'
                      : 'Allergen information unknown',
                  style: theme.textTheme.titleMedium,
                ),
                if (contains != null) Text('Contains: $contains'),
                if (mayContain != null) Text('May contain: $mayContain'),
                const Text(
                  'Check your current package. Missing information does not mean allergy-safe.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
