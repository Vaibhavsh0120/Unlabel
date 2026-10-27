import 'package:flutter/material.dart';

/// One inexpensive pulse for the first page; motion stops offscreen or when
/// reduced motion is requested. No placeholder pretends to be a product.
class SearchSkeleton extends StatefulWidget {
  const SearchSkeleton({super.key});
  @override
  State<SearchSkeleton> createState() => _SearchSkeletonState();
}

class _SearchSkeletonState extends State<SearchSkeleton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!_foreground ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Searching products',
      liveRegion: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: 300,
          width: double.infinity,
          child: CustomPaint(painter: _SearchPlaceholderPainter(color, _pulse)),
        ),
      ),
    );
  }
}

/// Repaints only the placeholder shapes. No per-frame widget rebuild or group
/// opacity layer is needed while a product search is outstanding.
class _SearchPlaceholderPainter extends CustomPainter {
  _SearchPlaceholderPainter(this.color, this.pulse) : super(repaint: pulse);
  final Color color;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .45 + pulse.value * .35);
    final textWidth = (size.width - 88).clamp(0.0, size.width);
    void bar(double x, double y, double width, double height) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, height),
          const Radius.circular(10),
        ),
        paint,
      );
    }

    for (var row = 0; row < 3; row++) {
      final y = row * 100.0;
      bar(0, y, size.width.clamp(0, 72), 88);
      bar(88, y + 13, textWidth * .8, 16);
      bar(88, y + 41, textWidth * .5, 12);
      bar(88, y + 63, textWidth * .6, 12);
    }
  }

  @override
  bool shouldRepaint(_SearchPlaceholderPainter oldDelegate) =>
      color != oldDelegate.color || pulse != oldDelegate.pulse;
}
