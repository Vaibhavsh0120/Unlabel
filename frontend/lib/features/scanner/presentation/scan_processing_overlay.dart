import 'package:flutter/material.dart';

/// Leaves the captured label visible while its information is being read.
class ScanProcessingOverlay extends StatefulWidget {
  const ScanProcessingOverlay({
    required this.barcode,
    required this.active,
    super.key,
  });

  final bool barcode;
  final bool active;

  @override
  State<ScanProcessingOverlay> createState() => _ScanProcessingOverlayState();
}

class _ScanProcessingOverlayState extends State<ScanProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(ScanProcessingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final animate =
        widget.active &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    } else if (!animate) {
      _sweep.stop();
      _sweep.value = .5;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      key: const Key('scan-processing'),
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) =>
              CustomPaint(painter: _ScanSweepPainter(_sweep.value)),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xeb073f31),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.barcode ? 'Reading barcode…' : 'Reading label…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScanSweepPainter extends CustomPainter {
  const _ScanSweepPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height * (.18 + .64 * progress);
    final line = Rect.fromLTWH(18, top, size.width - 36, 2);
    final trail = Rect.fromLTWH(18, top - 48, size.width - 36, 48);
    canvas.drawRect(
      trail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0070efba), Color(0x4070efba)],
        ).createShader(trail),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(line, const Radius.circular(2)),
      Paint()..color = const Color(0xffa3ffda),
    );
  }

  @override
  bool shouldRepaint(_ScanSweepPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
