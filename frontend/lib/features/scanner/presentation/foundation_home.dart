import 'package:flutter/material.dart';

class FoundationHome extends StatelessWidget {
  const FoundationHome({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  static const _features = [
    (
      title: 'Check the claim',
      description: 'Compare package claims with the ingredients and nutrition.',
    ),
    (
      title: 'See ingredients clearly',
      description: 'Highlight useful label information as you scan.',
    ),
    (
      title: 'Find what suits you',
      description: 'Understand a food through your preferences and allergies.',
    ),
    (
      title: 'Understand every ingredient',
      description: 'Read simple explanations in English or Hindi.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlabel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              label: 'Appearance',
              child: DropdownButton<ThemeMode>(
                key: const Key('theme-selector'),
                value: themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) onThemeModeChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Label Padhega India',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Know what is inside your food.',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text('Scanning is coming soon.'),
                    const SizedBox(height: 32),
                    Text(
                      'Coming to Unlabel',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 720 ? 2 : 1;
                        final width =
                            (constraints.maxWidth - 16 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final feature in _features)
                              SizedBox(
                                width: width,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          feature.title,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(feature.description),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Preview only. No food analysis yet.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
