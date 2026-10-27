import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (nav != null && MediaQuery.sizeOf(context).width < 1080) {
      return AppBar(
        titleSpacing: 16,
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: BrandHomeButton(
          onPressed: nav.home,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLeaf(size: 28),
              const SizedBox(width: 6),
              if (MediaQuery.textScalerOf(context).scale(16) < 24)
                Text(
                  'Unlabel',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontFamily: 'Nunito'),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search products',
            onPressed: nav.products,
            icon: const FeatureIcon('magnifer', size: 24),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: nav.profile,
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 8),
        ],
      );
    }
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
    this.mobile,
    super.key,
  });
  final List<Widget> main, aside;
  final List<Widget>? mobile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1080 &&
          MediaQuery.textScalerOf(context).scale(16) < 26;
      final base = Theme.of(context);
      final body = base.textTheme.apply(fontFamily: 'Quicksand');
      final compact = constraints.maxWidth < 600;
      final typography = body.copyWith(
        headlineLarge: body.headlineLarge?.copyWith(fontFamily: 'Nunito'),
        headlineMedium: body.headlineMedium?.copyWith(fontFamily: 'Nunito'),
        headlineSmall: body.headlineSmall?.copyWith(fontFamily: 'Nunito'),
        titleLarge: body.titleLarge?.copyWith(
          fontFamily: 'Nunito',
          fontSize: compact ? 18 : 22,
        ),
        titleMedium: body.titleMedium?.copyWith(
          fontFamily: 'Nunito',
          fontSize: compact ? 14 : 16,
        ),
        titleSmall: body.titleSmall?.copyWith(
          fontFamily: 'Nunito',
          fontSize: compact ? 12 : 14,
        ),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: compact ? 12 : 16),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: compact ? 12 : 14),
        bodySmall: body.bodySmall?.copyWith(fontSize: compact ? 11 : 12),
      );
      return Theme(
        data: base.copyWith(textTheme: typography),
        child: Material(
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
                _column(mobile ?? [...main, ...aside]),
            ],
          ),
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
    this.barcode,
    super.key,
  });
  final String name;
  final String? brand, variant, quantity, imageUrl, imageDescription, barcode;
  final Uint8List? photo;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final fallback = Semantics(
      label: 'Product photo unavailable',
      child: const Center(child: FeatureIcon('document-text', size: 36)),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: compact ? 80 : 176,
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
    final barcodeLine = barcode == null
        ? null
        : Row(
            children: [
              const FeatureIcon('barcode', size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: 'Barcode $barcode',
                  child: ExcludeSemantics(
                    child: Text(barcode!, style: theme.textTheme.bodySmall),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy barcode',
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: barcode!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Barcode copied')),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not copy barcode')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 17),
              ),
            ],
          );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: compact ? 21 : 28,
          ),
        ),
        if (brand != null) ...[
          const SizedBox(height: 4),
          Text(brand!, style: theme.textTheme.bodyLarge),
        ],
        if (variant != null && variant != name) Text(variant!),
        Text(
          quantity ?? 'Pack size unknown',
          style: theme.textTheme.bodyMedium,
        ),
        if (!compact && barcodeLine != null) barcodeLine,
      ],
    );
    return ResultsSurface(
      padding: compact ? 16 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 28;
              final identity = stack
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
              if (actions == null) {
                return compact && barcodeLine != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: 8),
                          barcodeLine,
                        ],
                      )
                    : identity;
              }
              if (compact &&
                  !stack &&
                  barcodeLine != null &&
                  MediaQuery.textScalerOf(context).scale(16) < 23) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 6, child: barcodeLine),
                        const SizedBox(width: 10),
                        Expanded(flex: 5, child: actions!),
                      ],
                    ),
                  ],
                );
              }
              return constraints.maxWidth >= 680 && !stack
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: actions!,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        if (compact && barcodeLine != null) barcodeLine,
                        const SizedBox(height: 12),
                        actions!,
                      ],
                    );
            },
          ),
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
    final accent = dark ? const Color(0xff20efc3) : theme.colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
        final ring = Semantics(
          label:
              '$count recorded nutrition ${count == 1 ? 'value' : 'values'}. This is a fact count.',
          child: ExcludeSemantics(
            child: Container(
              width: compact ? 56 : 100,
              height: compact ? 56 : 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: compact ? 6 : 8),
              ),
              child: Center(
                child: BrandLeaf(size: compact ? 30 : 46, color: accent),
              ),
            ),
          ),
        );
        final headingRow = Wrap(
          spacing: compact ? 8 : 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$count ${count == 1 ? 'value' : 'values'}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: ink,
                fontSize: compact ? 26 : 40,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dark ? const Color(0xff0e4a40) : const Color(0xffd7f5e3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: .25)),
              ),
              child: Text(
                heading,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ink,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ),
          ],
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ink,
                fontSize: compact ? 12 : 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              qualification,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ink,
                fontSize: compact ? 11 : 13,
              ),
            ),
          ],
        );
        final artwork = ExcludeSemantics(
          child: Image.asset(
            'assets/artwork/product-botanical-v2.webp',
            width: compact ? 44 : 116,
            height: compact ? 56 : 116,
            fit: BoxFit.contain,
          ),
        );
        return Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: dark
                  ? [const Color(0xff045949), const Color(0xff102620)]
                  : [const Color(0xffd6f5e9), const Color(0xffedf9f2)],
            ),
            border: Border.all(color: accent.withValues(alpha: .4)),
          ),
          child: compact || largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (largeText) ...[
                      ring,
                      const SizedBox(height: 12),
                      headingRow,
                    ] else
                      Row(
                        children: [
                          ring,
                          const SizedBox(width: 12),
                          Expanded(child: headingRow),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 8),
                        artwork,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    ring,
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headingRow,
                          const SizedBox(height: 10),
                          copy,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    artwork,
                  ],
                ),
        );
      },
    );
  }
}

/// Shared bordered surface; no blur or continuously animated decoration.
class ResultsSurface extends StatelessWidget {
  const ResultsSurface({required this.child, this.padding = 16, super.key});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xff1a252a), const Color(0xff121a1e)]
              : [Colors.white, const Color(0xfff3faf6)],
        ),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
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
    return ResultsSurface(
      padding: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 180;
          final symbol = Container(
            width: compact ? 34 : 46,
            height: compact ? 34 : 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(child: FeatureIcon(icon, size: compact ? 22 : 26)),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(detail, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                status,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: uncertain
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              symbol,
              const SizedBox(width: 8),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class ResultsFactsGrid extends StatelessWidget {
  const ResultsFactsGrid({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final regularText = MediaQuery.textScalerOf(context).scale(16) < 23;
      final columns = !regularText || constraints.maxWidth < 340
          ? 1
          : constraints.maxWidth >= 760
          ? 4
          : 2;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
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
            : (theme.brightness == Brightness.dark
                  ? const Color(0xff302717)
                  : const Color(0xfffff4dc)),
        border: Border.all(
          color: declared
              ? theme.colorScheme.error.withValues(alpha: .3)
              : const Color(0xffb88426),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            declared ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 32,
            color: declared
                ? theme.colorScheme.onErrorContainer
                : (theme.brightness == Brightness.dark
                      ? const Color(0xffffbf5a)
                      : const Color(0xff8b5900)),
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
