import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth_widgets.dart';

/// Only illustration layers animate. This widget never owns credentials or
/// interprets a tap as authentication success.
class AuthScene extends StatefulWidget {
  const AuthScene({
    required this.desktop,
    required this.create,
    required this.entrance,
    required this.reaction,
    required this.celebrating,
    this.showCopy = true,
    super.key,
  });
  final bool desktop, create, celebrating;
  final bool showCopy;
  final int reaction;
  final Animation<double> entrance;
  @override
  State<AuthScene> createState() => _AuthSceneState();
}

class _AuthSceneState extends State<AuthScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _foreground = true;
  bool get _motion =>
      _foreground &&
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

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

  void _syncMotion() {
    if (_motion) {
      if (!_idle.isAnimating) _idle.repeat();
    } else {
      _idle.stop();
      _reaction.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void didUpdateWidget(AuthScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.reaction != widget.reaction ||
            oldWidget.celebrating != widget.celebrating) &&
        _motion) {
      _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle.dispose();
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette(context);
    return LayoutBuilder(
      builder: (context, bounds) {
        final w = bounds.maxWidth, h = bounds.maxHeight;
        final desktop = widget.desktop;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final s = desktop
            ? math.min(w / 830, h / 1024).clamp(.5, 1.15)
            : (w / 426).clamp(.75, 1.3);
        final tablet = !desktop && w >= 600;
        final mascotSize = desktop
            ? math.min(w * .55, h * .47)
            : w * (tablet ? .43 : .55);
        final body = Image.asset(
          'assets/artwork/auth/mascot.png',
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
        final sprout = Image.asset(
          'assets/artwork/auth/sprout.png',
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
        final garden = Image.asset(
          'assets/artwork/auth/garden${p.dark ? '-dark' : ''}.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _Clouds(p.mint)),
              ),
            ),
            Positioned(
              left: -w * .025,
              right: -w * .025,
              bottom: 0,
              height: desktop ? w * .69 : w * (tablet ? .25 : .36),
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _idle,
                    child: garden,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(
                        math.sin(_idle.value * math.pi * 2) * 1.5,
                        0,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: desktop ? w * .245 : w * (tablet ? .52 : .385),
              bottom: desktop
                  ? h * .035
                  : -mascotSize * (widget.create ? .30 : .21),
              width: mascotSize,
              height: mascotSize * 1.1,
              child: ExcludeSemantics(
                child: AuthEntrance(
                  animation: widget.entrance,
                  order: 3,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_idle, _reaction]),
                      builder: (context, child) {
                        final phase = _idle.value * math.pi * 2;
                        final bounce =
                            math.sin(_reaction.value * math.pi) *
                            (widget.celebrating ? 16 : 5);
                        final breath = math.sin(phase) * 3 * s;
                        return Transform.translate(
                          offset: Offset(0, breath - bounce),
                          child: Transform.rotate(
                            angle:
                                math.sin(phase) * .008 +
                                math.sin(_reaction.value * math.pi * 2) * .018,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: mascotSize * .36,
                                  top: 0,
                                  width: mascotSize * .35,
                                  height: mascotSize * .35,
                                  child: Transform.rotate(
                                    alignment: Alignment.bottomCenter,
                                    angle: math.sin(phase + .6) * .045,
                                    child: sprout,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: mascotSize * .12,
                                  width: mascotSize,
                                  height: mascotSize,
                                  child: child!,
                                ),
                                Positioned(
                                  left: 0,
                                  top: mascotSize * .12,
                                  width: mascotSize,
                                  height: mascotSize,
                                  child: CustomPaint(
                                    painter: _Eyes(
                                      phase: _idle.value,
                                      happy: widget.celebrating,
                                    ),
                                  ),
                                ),
                                if (widget.celebrating)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _Celebration(
                                        _reaction.value,
                                        p.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
            if (desktop) ...[
              Positioned(
                left: w * (widget.create ? .11 : .14),
                top: h * .51,
                width: w * (widget.create ? .245 : .2),
                height: w * (widget.create ? .12 : .19),
                child: _floating(
                  1.2,
                  -.22,
                  _SceneCard(create: widget.create, kind: 0, scale: s),
                ),
              ),
              Positioned(
                right: w * .045,
                top: h * (widget.create ? .51 : .55),
                width: w * (widget.create ? .245 : .2),
                height: w * (widget.create ? .12 : .19),
                child: _floating(
                  3,
                  .22,
                  _SceneCard(create: widget.create, kind: 1, scale: s),
                ),
              ),
              if (widget.create)
                Positioned(
                  left: w * .09,
                  top: h * .51 + w * .17 + 18 * s,
                  width: w * .24,
                  height: w * .11,
                  child: _floating(
                    4,
                    -.2,
                    _SceneCard(create: true, kind: 2, scale: s),
                  ),
                ),
              if (!widget.create)
                Positioned(
                  left: w * .4,
                  top: h * .48,
                  width: 44 * s,
                  height: 44 * s,
                  child: _floating(2.5, 0, const CustomPaint(painter: _Star())),
                ),
            ],
            Positioned(
              left: desktop ? w * .63 : w * .80,
              top: desktop ? h * .5 : h * .42,
              width: desktop ? w * .095 : w * .1,
              height: desktop ? w * .1 : w * .11,
              child: _floating(2, -.1, const _HeartBubble()),
            ),
            Positioned(
              left: desktop ? w * .73 : w * .85,
              top: desktop ? h * .63 : h * .68,
              child: _floating(
                1,
                .15,
                AuthAccent(size: (desktop ? 38 : 21) * s),
              ),
            ),
            if (widget.showCopy && desktop)
              Positioned(
                left: w * .17,
                top: h * .055,
                width: w * .82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthEntrance(
                      animation: widget.entrance,
                      child: AuthWordmark(size: 68 * s),
                    ),
                    SizedBox(height: 38 * s),
                    AuthEntrance(
                      animation: widget.entrance,
                      order: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            children: widget.create
                                ? [
                                    const TextSpan(
                                      text: 'A more mindful you,\n',
                                    ),
                                    TextSpan(
                                      text: 'starts here.',
                                      style: TextStyle(color: p.green),
                                    ),
                                  ]
                                : [
                                    const TextSpan(
                                      text: 'Know what\nyou consume.',
                                    ),
                                  ],
                          ),
                          style: p.heading(72 * s),
                        ),
                      ),
                    ),
                    SizedBox(height: 20 * s),
                    AuthEntrance(
                      animation: widget.entrance,
                      order: 2,
                      child: Text(
                        widget.create
                            ? 'Create your account to scan, understand,\nand make healthier choices — every day.'
                            : 'Scan. Understand. Make healthier choices everyday.',
                        style: p.body(27 * s).copyWith(height: 1.24),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.showCopy && !desktop) ...[
              Positioned(
                left: w * .081,
                top: 46 * s,
                child: AuthEntrance(
                  animation: widget.entrance,
                  child: AuthWordmark(size: 43 * s),
                ),
              ),
              Positioned(
                left: w * .081,
                top: (46 + 62 * textScale) * s,
                width: w * .86,
                child: AuthEntrance(
                  animation: widget.entrance,
                  order: 1,
                  child: Text.rich(
                    TextSpan(
                      children: widget.create
                          ? [
                              const TextSpan(text: 'Create\nyour '),
                              TextSpan(
                                text: 'account',
                                style: TextStyle(
                                  color: p.dark ? p.green : p.ink,
                                ),
                              ),
                            ]
                          : [
                              const TextSpan(text: 'Know what\nyou '),
                              TextSpan(
                                text: 'consume.',
                                style: TextStyle(color: p.green),
                              ),
                            ],
                    ),
                    style: p.heading(33 * s),
                  ),
                ),
              ),
              Positioned(
                left: w * .081,
                top: (46 + 134 * textScale) * s,
                width: w * .56,
                child: AuthEntrance(
                  animation: widget.entrance,
                  order: 2,
                  child: Text(
                    widget.create
                        ? 'Join unlabel and start\nmaking healthier choices\ntoday.'
                        : 'Scan. Understand. Make\nhealthier choices everyday.',
                    style: p.body(15.5 * s).copyWith(height: 1.24),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _floating(
    double phase,
    double angle,
    Widget child,
  ) => ExcludeSemantics(
    child: AuthEntrance(
      animation: widget.entrance,
      order: 4,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _idle,
          child: child,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, math.sin(_idle.value * math.pi * 2 + phase) * 3),
            child: Transform.rotate(
              angle: angle + math.sin(_idle.value * math.pi * 2 + phase) * .012,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Eyes extends CustomPainter {
  const _Eyes({required this.phase, required this.happy});
  final double phase;
  final bool happy;
  @override
  void paint(Canvas canvas, Size size) {
    final blinkDistance = math.min((phase - .65).abs(), (phase - .695).abs());
    final openness = (blinkDistance / .013).clamp(.08, 1.0);
    for (final x in [.395, .593]) {
      final center = Offset(size.width * x, size.height * .357);
      if (happy) {
        final r = size.width * .016;
        canvas.drawArc(
          Rect.fromCenter(
            center: center.translate(0, r / 2),
            width: r * 2,
            height: r * 1.4,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xff291d15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * .007
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final rect = Rect.fromCenter(
          center: center,
          width: size.width * .034,
          height: size.height * .052 * openness,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xff594736), Color(0xff1e160f)],
              center: Alignment.topLeft,
            ).createShader(rect),
        );
        if (openness > .4) {
          canvas.drawOval(
            Rect.fromCenter(
              center: center.translate(-size.width * .005, -size.height * .012),
              width: size.width * .008,
              height: size.height * .014 * openness,
            ),
            Paint()..color = const Color(0xfffff7e6).withValues(alpha: .75),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Eyes oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.happy != happy;
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.create,
    required this.kind,
    required this.scale,
  });
  final bool create;
  final int kind;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final p = AuthPalette(context);
    final label = kind == 0
        ? (create ? 'Scan\nfood labels' : 'Healthier\nchoices')
        : kind == 1
        ? (create ? 'Get simple\ninsights' : 'Simple\ninsights')
        : 'Make\nhealthier choices';
    final graphic = SizedBox.square(
      dimension: 43 * scale,
      child: kind == 0
          ? Image.asset('assets/artwork/auth/sprout.png')
          : CustomPaint(painter: kind == 1 ? const _Bars() : const _Heart()),
    );
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: p.paper.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(27 * scale),
        border: Border.all(color: p.dark ? p.border : Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffb4936c).withValues(alpha: .14),
            offset: const Offset(-3, 5),
            blurRadius: 9,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: create
            ? Row(
                children: [
                  graphic,
                  SizedBox(width: 12 * scale),
                  Text(label, style: p.body(19 * scale, bold: true)),
                ],
              )
            : Column(
                children: [
                  graphic,
                  SizedBox(height: 8 * scale),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: p.body(20 * scale, bold: true),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeartBubble extends StatelessWidget {
  const _HeartBubble();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AuthPalette(context).paper,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: const Color(0xffd2ac8f).withValues(alpha: .2),
          blurRadius: 8,
          offset: const Offset(-2, 3),
        ),
      ],
    ),
    child: const CustomPaint(painter: _Heart()),
  );
}

class _Heart extends CustomPainter {
  const _Heart();
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .5, s.height * .9)
      ..cubicTo(
        -s.width * .35,
        s.height * .35,
        s.width * .05,
        -s.height * .15,
        s.width * .5,
        s.height * .24,
      )
      ..cubicTo(
        s.width * .95,
        -s.height * .15,
        s.width * 1.35,
        s.height * .35,
        s.width * .5,
        s.height * .9,
      );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffb2a0), Color(0xffff776b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(_Heart oldDelegate) => false;
}

class _Bars extends CustomPainter {
  const _Bars();
  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < 3; i++) {
      final height = s.height * (.35 + i * .26);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            s.width * (.05 + i * .32),
            s.height - height,
            s.width * .23,
            height,
          ),
          Radius.circular(s.width * .09),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xff71b48a),
            const Color(0xff218b54),
            i / 2,
          )!,
      );
    }
  }

  @override
  bool shouldRepaint(_Bars oldDelegate) => false;
}

class _Star extends CustomPainter {
  const _Star();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..quadraticBezierTo(s.width * .55, s.height * .45, s.width, s.height / 2)
      ..quadraticBezierTo(s.width * .55, s.height * .55, s.width / 2, s.height)
      ..quadraticBezierTo(s.width * .45, s.height * .55, 0, s.height / 2)
      ..quadraticBezierTo(s.width * .45, s.height * .45, s.width / 2, 0);
    canvas.drawPath(
      p,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xffffefad), Color(0xffedc460)],
        ).createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(_Star oldDelegate) => false;
}

class _Celebration extends CustomPainter {
  const _Celebration(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < 7; i++) {
      final a = i * math.pi * 2 / 7;
      final radius = s.width * (.27 + progress * .2);
      canvas.save();
      canvas.translate(
        s.width / 2 + math.cos(a) * radius,
        s.height * .4 + math.sin(a) * radius,
      );
      canvas.scale(1 - progress * .6);
      const _Star().paint(canvas, Size.square(s.width * .035));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Celebration oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Clouds extends CustomPainter {
  const _Clouds(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .94, 0)
      ..cubicTo(
        s.width * .85,
        s.height * .11,
        s.width * .56,
        s.height * .15,
        s.width * .69,
        s.height * .26,
      )
      ..cubicTo(
        s.width * .77,
        s.height * .33,
        s.width,
        s.height * .3,
        s.width,
        s.height * .43,
      )
      ..lineTo(s.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .58));
    canvas.drawOval(
      Rect.fromLTWH(
        -s.width * .27,
        s.height * .38,
        s.width * .37,
        s.height * .21,
      ),
      Paint()..color = color.withValues(alpha: .48),
    );
  }

  @override
  bool shouldRepaint(_Clouds oldDelegate) => oldDelegate.color != color;
}
