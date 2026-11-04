import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared frosted surface. Blur is opt-in for small navigation chrome, never
/// repeated over scrolling cards or placed above the camera preview.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.radius = 24,
    this.blur = false,
    this.border = true,
    super.key,
  });

  final Widget child;
  final double radius;
  final bool blur, border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final colors = theme.colorScheme;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highContrast
              ? [colors.surfaceContainerLow, colors.surfaceContainerLow]
              : [
                  (dark ? const Color(0xff24383b) : Colors.white).withValues(
                    alpha: .96,
                  ),
                  (dark ? const Color(0xff142528) : const Color(0xffeef8f3))
                      .withValues(alpha: .9),
                ],
        ),
        border: border
            ? Border.all(
                color: highContrast
                    ? colors.onSurface
                    : colors.outlineVariant.withValues(alpha: .8),
              )
            : null,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur && !highContrast
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: surface,
            )
          : surface,
    );
  }
}
