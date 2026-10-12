import 'package:flutter/material.dart';

import 'desktop_navigation.dart';

/// Shared destinations for content that opens above the main client page.
class ShellNavigation {
  const ShellNavigation({
    required this.selectedIndex,
    required this.onSelect,
    required this.onHistory,
    required this.onInsights,
    required this.onSearch,
    required this.onProfile,
    required this.onNotifications,
    this.onSources,
  });
  final int selectedIndex;
  final VoidCallback? onSources;
  final ValueChanged<int> onSelect;
  final VoidCallback onHistory,
      onInsights,
      onSearch,
      onProfile,
      onNotifications;
}

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.navigation,
    required super.child,
    super.key,
  });
  final ShellNavigation navigation;

  static ShellNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>()?.navigation;

  /// A Navigator route has its own ancestry; carry the initiating shell with it.
  static Widget wrap(BuildContext context, Widget page) {
    final navigation = maybeOf(context);
    return navigation == null
        ? page
        : AppShellScope(navigation: navigation, child: page);
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      navigation != oldWidget.navigation;
}

/// Desktop content changes instantly while phone readers retain normal Back motion.
class ShellContentRoute<T> extends MaterialPageRoute<T> {
  ShellContentRoute({
    required BuildContext context,
    required super.builder,
    super.settings,
  }) : _steady =
           MediaQuery.sizeOf(context).width >= 1200 &&
           MediaQuery.textScalerOf(context).scale(14) <= 21;

  final bool _steady;
  @override
  Duration get transitionDuration =>
      _steady ? Duration.zero : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      _steady ? Duration.zero : super.reverseTransitionDuration;
}

/// Reuses the real desktop shell while compact layouts keep their Back bar.
class ShellPage extends StatelessWidget {
  const ShellPage({
    required this.title,
    required this.body,
    this.actions,
    this.selectedIndex,
    this.navigation,
    super.key,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final int? selectedIndex;
  final ShellNavigation? navigation;

  @override
  Widget build(BuildContext context) {
    final nav = navigation ?? AppShellScope.maybeOf(context);
    final desktop =
        MediaQuery.sizeOf(context).width >= 1200 &&
        MediaQuery.textScalerOf(context).scale(14) <= 21;
    if (!desktop || nav == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
      );
    }
    return Row(
      children: [
        DesktopNavigation(
          selectedIndex: selectedIndex ?? nav.selectedIndex,
          onSelect: nav.onSelect,
          onHistory: nav.onHistory,
          onInsights: nav.onInsights,
        ),
        Expanded(
          child: Scaffold(
            appBar: DesktopTopBar(
              onSearch: nav.onSearch,
              onProfile: nav.onProfile,
              onNotifications: nav.onNotifications,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                  child: Row(
                    children: [
                      const BackButton(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
