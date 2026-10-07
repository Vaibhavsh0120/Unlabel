import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/interaction/ui_feedback.dart';

import 'ui_components.dart';

class MobileNavigation extends StatefulWidget {
  const MobileNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  }) : assert(selectedIndex >= 0 && selectedIndex < 4);
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<MobileNavigation> createState() => _MobileNavigationState();
}

class _MobileNavigationState extends State<MobileNavigation>
    with WidgetsBindingObserver {
  double? _dragCenter;
  int? _dragCandidate;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(MobileNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _holding = false;
      _dragCenter = null;
      _dragCandidate = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  void _cancel() {
    if (!_holding) return;
    setState(() {
      _holding = false;
      _dragCenter = null;
      _dragCandidate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: theme.brightness == Brightness.dark ? .12 : .06,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                key: const Key('floating-navigation'),
                color: colors.surfaceContainerLow.withValues(alpha: .96),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(34),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final slot = constraints.maxWidth / 4;
                      final rtl =
                          Directionality.of(context) == TextDirection.rtl;
                      int logicalSlot(double x) {
                        final physical = (x / slot).floor().clamp(0, 3);
                        return rtl ? 3 - physical : physical;
                      }

                      void move(double x) {
                        if (!_holding) return;
                        final candidate = logicalSlot(x);
                        if (_dragCandidate != candidate) {
                          unawaited(UiFeedback.selection());
                        }
                        setState(() {
                          _dragCenter = x.clamp(
                            slot / 2,
                            constraints.maxWidth - slot / 2,
                          );
                          _dragCandidate = candidate;
                        });
                      }

                      final physicalSelected = rtl
                          ? 3 - widget.selectedIndex
                          : widget.selectedIndex;
                      final left = _dragCenter == null
                          ? physicalSelected * slot
                          : _dragCenter! - slot / 2;
                      return GestureDetector(
                        key: const Key('navigation-slide-gesture'),
                        behavior: HitTestBehavior.translucent,
                        excludeFromSemantics: true,
                        onLongPressStart: (details) {
                          if (logicalSlot(details.localPosition.dx) !=
                              widget.selectedIndex) {
                            return;
                          }
                          _holding = true;
                          move(details.localPosition.dx);
                        },
                        onLongPressMoveUpdate: (details) =>
                            move(details.localPosition.dx),
                        onLongPressCancel: _cancel,
                        onLongPressEnd: (_) {
                          final target = _dragCandidate;
                          _cancel();
                          if (target != null &&
                              target != widget.selectedIndex) {
                            widget.onDestinationSelected(target);
                          }
                        },
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration:
                                  _holding ||
                                      MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              left: left,
                              top: 0,
                              bottom: 0,
                              width: slot,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  key: const Key('navigation-active-indicator'),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: .22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var index = 0; index < 4; index++)
                                  Expanded(
                                    child: _Destination(
                                      index: index,
                                      selected: widget.selectedIndex == index,
                                      highlighted:
                                          (_dragCandidate ??
                                              widget.selectedIndex) ==
                                          index,
                                      dragging:
                                          _holding &&
                                          widget.selectedIndex == index,
                                      onTap: () =>
                                          widget.onDestinationSelected(index),
                                    ),
                                  ),
                              ],
                            ),
                            if (_holding)
                              Positioned(
                                key: const Key('navigation-dragged-icon'),
                                left: left + (slot - 24) / 2,
                                top: 8,
                                child: IgnorePointer(
                                  child: _destinationIcon(
                                    widget.selectedIndex,
                                    colors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
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

class _Destination extends StatelessWidget {
  const _Destination({
    required this.index,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    this.dragging = false,
  });
  final int index;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final bool dragging;
  static const _labels = ['Home', 'Scan', 'Compare', 'Saved'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlighted
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: _labels[index],
      hint: selected ? 'Hold and slide to choose a screen' : null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('mobile-nav-$index'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: dragging ? 0 : 1,
                      child: _destinationIcon(index, color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[index],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
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

Widget _destinationIcon(int index, Color color) => switch (index) {
  0 => FeatureIcon('home', size: 24, color: color),
  1 => FeatureIcon('scanner', size: 24, color: color),
  2 => Icon(Icons.balance_outlined, size: 24, color: color),
  _ => FeatureIcon('bookmark', size: 24, color: color),
};
