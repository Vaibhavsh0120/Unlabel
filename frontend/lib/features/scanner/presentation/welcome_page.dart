import 'package:flutter/material.dart';

import '../../../core/widgets/brand_mark.dart';
import 'ui_components.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppSymbol(size: 72)),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to Unlabel',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Know beyond the label',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        clipBehavior: Clip.hardEdge,
                        height: constraints.maxWidth < 600 ? 180 : 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: .35,
                          ),
                        ),
                        child: CornerArtwork(
                          asset: 'assets/artwork/welcome-garden.png',
                          height: constraints.maxWidth < 600 ? 180 : 220,
                          scale: 1.05,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'A little clarity for\nevery food find.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Explore nutrition, ingredients and claims on your food package.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('welcome-continue'),
                        onPressed: onContinue,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        label: const Text('Explore Unlabel'),
                        icon: const Icon(Icons.arrow_forward),
                        iconAlignment: IconAlignment.end,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No account needed. Sign in for other devices.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
