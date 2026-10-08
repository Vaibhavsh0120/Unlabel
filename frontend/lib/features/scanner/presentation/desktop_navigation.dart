import 'package:flutter/material.dart';

import '../../../core/widgets/brand_mark.dart';
import 'ui_components.dart';

/// Expanded navigation keeps the mobile destination order and real callbacks.
class DesktopNavigation extends StatelessWidget {
  const DesktopNavigation({
    required this.selectedIndex,
    required this.onSelect,
    required this.onHistory,
    required this.onInsights,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onHistory, onInsights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final destinations = [
      ('Home', 'home', () => onSelect(0)),
      ('Scan', 'barcode', () => onSelect(1)),
      ('Compare', 'scales', () => onSelect(2)),
      ('Saved', 'bookmark', () => onSelect(3)),
      ('History', 'history', onHistory),
      ('Insights', 'lightbulb', onInsights),
    ];
    return SizedBox(
      key: const Key('desktop-sidebar'),
      width: 240,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Unlabel',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontSize: 36,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const BrandLeaf(size: 30),
                      ],
                    ),
                    Text(
                      'Know Beyond the Label',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Semantics(
                            selected: i == selectedIndex && i < 4,
                            child: Material(
                              color: i == selectedIndex && i < 4
                                  ? colors.primaryContainer.withValues(
                                      alpha: .65,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                key: Key('desktop-nav-$i'),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minTileHeight: 56,
                                horizontalTitleGap: 24,
                                leading: i == 2
                                    ? Icon(
                                        Icons.balance_outlined,
                                        size: 28,
                                        color: colors.onSurfaceVariant,
                                      )
                                    : FeatureIcon(
                                        destinations[i].$2,
                                        size: 28,
                                        color: i == selectedIndex
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                title: Text(
                                  destinations[i].$1,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: i == selectedIndex
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                onTap: destinations[i].$3,
                              ),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 18,
                        ),
                        child: Divider(),
                      ),
                    ],
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).height >= 650)
                SizedBox(
                  height: 340,
                  child: Stack(
                    children: [
                      Positioned(
                        left: -55,
                        top: 0,
                        width: 210,
                        height: 260,
                        child: Image.asset(
                          'assets/artwork/sidebar-mint-leaves.png',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Positioned(
                        left: 44,
                        right: 24,
                        bottom: 32,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make\nhealthier choices\nfor a brighter\ntomorrow.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 44,
                              height: 2,
                              color: const Color(0xff70c9ac),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        right: 32,
                        bottom: 38,
                        child: FeatureIcon(
                          'leaf',
                          color: Color(0xff70c9ac),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopTopBar({
    required this.onSearch,
    required this.onProfile,
    required this.onNotifications,
    super.key,
  });
  final VoidCallback onSearch, onProfile, onNotifications;
  @override
  Size get preferredSize => const Size.fromHeight(80);
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: Material(
                  color: colors.surfaceContainerLow,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: onSearch,
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const FeatureIcon('magnifer', size: 22),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Search for a product, brand or ingredient...',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onNotifications,
              tooltip: 'Notifications',
              icon: const FeatureIcon('bell', size: 28),
            ),
            const SizedBox(width: 24),
            TextButton(
              onPressed: onProfile,
              child: Semantics(
                label: 'Profile',
                button: true,
                child: Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/artwork/profile-avatar.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.expand_more, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
