import 'package:flutter/material.dart';

/// Missing-link content stays inside the working app header and navigation.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primaryContainer.withValues(alpha: .24),
            colors.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 136).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final wide =
                          contentConstraints.maxWidth >= 760 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 21;
                      final copy = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: wide
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '404',
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontSize: wide ? 132 : 88,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -6,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            header: true,
                            child: Text(
                              'Page not found',
                              textAlign: wide
                                  ? TextAlign.start
                                  : TextAlign.center,
                              style: theme.textTheme.headlineLarge,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "This link doesn't lead to an Unlabel page. Head Home to keep exploring.",
                            textAlign: wide
                                ? TextAlign.start
                                : TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(
                            onPressed: onHome,
                            child: const Text('Go to Home'),
                          ),
                        ],
                      );
                      final artwork = ExcludeSemantics(
                        child: Image.asset(
                          'assets/artwork/not-found-art.webp',
                          height: wide ? 400 : 180,
                          fit: BoxFit.contain,
                        ),
                      );
                      return wide
                          ? Row(
                              key: const Key('not-found-desktop-content'),
                              children: [
                                Expanded(child: copy),
                                const SizedBox(width: 48),
                                Expanded(child: artwork),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                artwork,
                                const SizedBox(height: 12),
                                copy,
                              ],
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
