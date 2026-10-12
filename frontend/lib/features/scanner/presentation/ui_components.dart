import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Decorative artwork fits inside a reserved box, including its motion inset.
/// It never owns a gesture or accessibility node and pauses while scrolling or
/// outside the viewport.
class CornerArtwork extends StatefulWidget {
  const CornerArtwork({
    required this.asset,
    this.height = 220,
    this.scale = 1,
    this.alignment = Alignment.bottomRight,
    this.animate = true,
    super.key,
  });
  final String asset;
  final double height, scale;
  final Alignment alignment;
  final bool animate;
  @override
  State<CornerArtwork> createState() => _CornerArtworkState();
}

class _CornerArtworkState extends State<CornerArtwork>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  ScrollPosition? _position;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_updateMotion);
      _position?.isScrollingNotifier.removeListener(_updateMotion);
      _position = position;
      _position?.addListener(_updateMotion);
      _position?.isScrollingNotifier.addListener(_updateMotion);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMotion());
  }

  @override
  void didUpdateWidget(CornerArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMotion());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion() {
    if (!mounted) return;
    final enabled =
        widget.animate &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (!enabled) {
      _motion.stop();
      _motion.value = 0;
      return;
    }
    if (_position?.isScrollingNotifier.value ?? false) {
      // Keep the current pose while dragging or coasting. The notifier resumes
      // motion at idle; offset updates need no viewport work during scrolling.
      _motion.stop();
      return;
    }
    final box = context.findRenderObject();
    var visible = false;
    if (box is RenderBox && box.hasSize && box.attached) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      visible = rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
    }
    if (visible && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!visible) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_updateMotion);
    _position?.isScrollingNotifier.removeListener(_updateMotion);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedBuilder(
              animation: _motion,
              child: Image.asset(
                widget.asset,
                fit: BoxFit.contain,
                width: double.infinity,
                height: widget.height,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
              builder: (_, child) {
                final phase = math.sin(_motion.value * math.pi * 2);
                return Transform.translate(
                  offset: Offset(0, phase * 4),
                  child: Transform.rotate(
                    angle: phase * .018,
                    alignment: widget.alignment,
                    child: Transform.scale(
                      scale: widget.scale.clamp(0.1, 1.0),
                      alignment: widget.alignment,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class FeatureIcon extends StatelessWidget {
  const FeatureIcon(this.name, {this.size = 26, this.color, super.key});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name-linear.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? Theme.of(context).colorScheme.primary,
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    required this.children,
    this.maxWidth = 1000,
    this.padding,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
                  40 + MediaQuery.paddingOf(context).bottom,
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.padding = 24, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class StatusNotice extends StatelessWidget {
  const StatusNotice({
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodyLarge),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class BusyNotice extends StatelessWidget {
  const BusyNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    this.trailing,
    this.compact = false,
    this.topSpacing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool compact;
  final double? topSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: topSpacing ?? (compact ? 12 : 28),
      bottom: compact ? 8 : 16,
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}
