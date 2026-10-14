import 'package:flutter/material.dart';

/// Auth-specific reference tokens; the rest of the application's theme is intact.
class AuthPalette {
  AuthPalette(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get background =>
      dark ? const Color(0xff101416) : const Color(0xfff8f6ef);
  Color get paper => dark ? const Color(0xff161b1e) : const Color(0xfffffefd);
  Color get ink => dark ? const Color(0xfff5f7f5) : const Color(0xff1b2732);
  Color get muted => dark ? const Color(0xffb4bdc4) : const Color(0xff777c80);
  Color get green => dark ? const Color(0xff4fe09a) : const Color(0xff21844f);
  Color get border => dark ? const Color(0xff363e43) : const Color(0xffdedfdd);
  Color get mint => dark ? const Color(0xff1c2a25) : const Color(0xffedf2eb);

  Color get button => dark ? const Color(0xff24965a) : const Color(0xff21844f);

  TextStyle heading(double size) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: ink,
    height: 1.08,
    letterSpacing: -.6,
  );
  TextStyle body(double size, {bool bold = false}) => TextStyle(
    fontFamily: 'Quicksand',
    fontSize: size,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    color: bold ? ink : muted,
    height: 1.3,
  );
}

/// Press feedback wraps a real keyboard/semantics-aware Flutter button.
class AuthPress extends StatefulWidget {
  const AuthPress({required this.child, super.key});
  final Widget child;
  @override
  State<AuthPress> createState() => _AuthPressState();
}

class _AuthPressState extends State<AuthPress> {
  bool _down = false, _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() {
      _hover = false;
      _down = false;
    }),
    child: Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? .975 : (_hover ? 1.008 : 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    ),
  );
}

/// A finite entrance: controls stay mounted and can be used immediately.
class AuthEntrance extends StatelessWidget {
  const AuthEntrance({
    required this.animation,
    required this.child,
    this.order = 0,
    super.key,
  });
  final Animation<double> animation;
  final Widget child;
  final int order;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final progress = animation.drive(
      CurveTween(
        curve: Interval(
          order * .06,
          .65 + order * .05,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween(begin: const Offset(0, .025), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.height, required this.fontSize, super.key});
  final double height, fontSize;
  @override
  Widget build(BuildContext context) {
    final p = AuthPalette(context);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: Divider(color: p.border, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('or', style: p.body(fontSize)),
          ),
          Expanded(child: Divider(color: p.border, thickness: 1)),
        ],
      ),
    );
  }
}

class AuthAccent extends StatelessWidget {
  const AuthAccent({this.size = 24, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _AccentPainter(AuthPalette(context).green),
    ),
  );
}

class _AccentPainter extends CustomPainter {
  const _AccentPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * .16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .21, size.height * .4),
      Offset(size.width * .41, size.height * .1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .53, size.height * .7),
      Offset(size.width * .9, size.height * .59),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AccentPainter oldDelegate) => oldDelegate.color != color;
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({required this.size, super.key});
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = AuthPalette(context);
    return Semantics(
      label: 'Unlabel',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              textScaler: TextScaler.noScaling,
              TextSpan(
                children: [
                  TextSpan(
                    text: 'un',
                    style: TextStyle(color: p.green),
                  ),
                  const TextSpan(text: 'label'),
                ],
              ),
              style: p
                  .heading(size)
                  .copyWith(letterSpacing: -size * .05, height: 1),
            ),
            Padding(
              padding: EdgeInsets.only(top: size * .02),
              child: AuthAccent(size: size * .38),
            ),
          ],
        ),
      ),
    );
  }
}
