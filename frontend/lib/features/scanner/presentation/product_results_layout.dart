import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'ui_components.dart';
import 'label_studio_layout.dart';
import 'app_shell.dart';

/// One responsive composition for confirmed, researched and machine-read facts.
/// The views supply their own evidence status; this layout invents no scores.
class ProductResultsLayout extends StatelessWidget {
  const ProductResultsLayout({
    required this.main,
    required this.aside,
    this.mobile,
    this.asideSection = StudioSection.sources,
    super.key,
  });
  final List<Widget> main, aside;
  final List<Widget>? mobile;
  final StudioSection asideSection;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = Theme.of(context);
      final body = base.textTheme.apply(fontFamily: 'Inter');
      final compact = constraints.maxWidth < 600;
      final typography = body.copyWith(
        headlineLarge: body.headlineLarge?.copyWith(fontFamily: 'Manrope'),
        headlineMedium: body.headlineMedium?.copyWith(fontFamily: 'Manrope'),
        headlineSmall: body.headlineSmall?.copyWith(fontFamily: 'Manrope'),
        titleLarge: body.titleLarge?.copyWith(
          fontFamily: 'Manrope',
          fontSize: compact ? 18 : 22,
        ),
        titleMedium: body.titleMedium?.copyWith(
          fontFamily: 'Manrope',
          fontSize: compact ? 14 : 16,
        ),
        titleSmall: body.titleSmall?.copyWith(
          fontFamily: 'Manrope',
          fontSize: compact ? 14 : 14,
        ),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: compact ? 14 : 16),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: compact ? 14 : 14),
        bodySmall: body.bodySmall?.copyWith(fontSize: compact ? 12 : 12),
      );
      return Theme(
        data: base.copyWith(textTheme: typography),
        child: Material(color: base.colorScheme.surface, child: _studio()),
      );
    },
  );

  Widget _studio() {
    final blocks = <StudioBlock>[];
    Widget? header;
    void collect(
      List<Widget> widgets,
      StudioSection initial,
      String initialTitle,
    ) {
      var section = initial;
      var title = initialTitle;
      var children = <Widget>[];
      void flush() {
        if (children.any((w) => w is! SizedBox)) {
          blocks.add(StudioBlock(section, title, children));
        }
        children = <Widget>[];
      }

      for (final widget in widgets) {
        if (widget is ResultsIdentityCard && header == null) {
          header = widget;
          continue;
        }
        if (widget is StudioSectionTitle) {
          flush();
          section = widget.section;
          title = widget.title;
        } else {
          children.add(widget);
        }
      }
      flush();
    }

    collect(main, StudioSection.overview, 'Evidence summary');
    collect(
      aside,
      asideSection,
      asideSection == StudioSection.ingredients
          ? 'Ingredients'
          : 'More product context',
    );
    return LabelStudioLayout(
      header: header ?? const SizedBox.shrink(),
      blocks: blocks,
    );
  }
}

/// A single table only: original units, qualifiers and basis remain attached.
class ResultsNutrientGrid extends StatelessWidget {
  const ResultsNutrientGrid({
    required this.rows,
    required this.basis,
    super.key,
  });
  final List<Map<String, dynamic>> rows;
  final String basis;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      padding: 12,
      child: LayoutBuilder(
        builder: (context, area) {
          final count = MediaQuery.textScalerOf(context).scale(16) >= 25
              ? 1
              : 2;
          final width = (area.maxWidth - 10 * (count - 1)) / count;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (key, title, icon) in const [
                    ('energy', 'Energy', Icons.local_fire_department_outlined),
                    ('protein', 'Protein', Icons.fitness_center_outlined),
                    ('sugars', 'Total sugars', Icons.view_in_ar_outlined),
                    ('fat', 'Fat', Icons.water_drop_outlined),
                  ])
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: .45,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              icon,
                              size: 21,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _value(key),
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(title),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(basis, style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }

  String _value(String key) {
    final matching = rows.where((row) => row['nutrient'] == key).toList();
    if (matching.length != 1 ||
        matching.single['value'] == null ||
        matching.single['qualifier'] == 'unknown') {
      return 'Unknown';
    }
    final row = matching.single;
    final prefix = switch (row['qualifier']) {
      'less_than' => '< ',
      'less_than_or_equal' => '≤ ',
      'greater_than' => '> ',
      'greater_than_or_equal' => '≥ ',
      'approximate' => '≈ ',
      _ => '',
    };
    return '$prefix${row['value']} ${row['unit'] ?? ''}'.trim();
  }
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
    final base = Theme.of(context);
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xffd8f4e8),
        primary: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
    final compact = MediaQuery.sizeOf(context).width < 600;
    final navigation = AppShellScope.maybeOf(context);
    final controls = <Widget>[
      ?actions,
      if (navigation != null)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xff155b4b),
          ),
          onPressed: () => navigation.onSelect(2),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare'),
        ),
    ];
    final combinedActions = controls.isEmpty
        ? null
        : compact && MediaQuery.textScalerOf(context).scale(16) < 25
        ? Row(
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: controls[i]),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                controls[i],
              ],
            ],
          );
    final fallback = Semantics(
      label: 'Product photo unavailable',
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 36,
          color: Color(0xff155b4b),
        ),
      ),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: compact ? 80 : 176,
        child: ColoredBox(
          color: const Color(0xfff4f8f6),
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
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
        if (variant != null && variant != name)
          Text(variant!, style: theme.textTheme.bodyMedium),
        Text(
          quantity ?? 'Pack size unknown',
          style: theme.textTheme.bodyMedium,
        ),
        if (!compact && barcodeLine != null) barcodeLine,
      ],
    );
    return Theme(
      data: theme,
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
          color: const Color(0xff155b4b),
          borderRadius: BorderRadius.circular(22),
        ),
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
                if (combinedActions == null) {
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
                          Expanded(flex: 5, child: combinedActions),
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
                            child: combinedActions,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          if (compact && barcodeLine != null) barcodeLine,
                          const SizedBox(height: 12),
                          combinedActions,
                        ],
                      );
              },
            ),
          ],
        ),
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
    return ResultsSurface(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(heading, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 8),
          Text('$count recorded facts', style: theme.textTheme.labelMedium),
          const Divider(height: 24),
          Text(qualification, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

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
