import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Keeps each visible wordmark a keyboard-accessible route back to Home.
class BrandHomeButton extends StatefulWidget {
  const BrandHomeButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<BrandHomeButton> createState() => _BrandHomeButtonState();
}

class _BrandHomeButtonState extends State<BrandHomeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Unlabel Home',
    button: true,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovered) => setState(() => _hovered = hovered),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: AnimatedScale(
            scale: _hovered ? 1.025 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            alignment: Alignment.centerLeft,
            child: ExcludeSemantics(child: widget.child),
          ),
        ),
      ),
    ),
  );
}

/// The authored filled leaf, independent of the outline feature-icon library.
class BrandLeaf extends StatelessWidget {
  const BrandLeaf({this.size = 30, this.color, super.key});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? '#70EBBA' : '#20966F';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="270 195 485 480">'
      '<defs><mask id="cut"><path fill="white" d="M0 0H1024V1024H0Z"/>'
      '<path d="M338 662 C397 543 496 426 645 320" fill="none" stroke="black" stroke-width="17" stroke-linecap="round"/></mask></defs>'
      '<path d="M348 612 C265 392 419 226 728 218 C736 474 602 640 394 630 Z" fill="$fill" mask="url(#cut)"/></svg>',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

class AppSymbol extends StatelessWidget {
  const AppSymbol({this.size = 80, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .23),
    child: Image.asset(
      'assets/brand/app-icon-${Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light'}.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}
