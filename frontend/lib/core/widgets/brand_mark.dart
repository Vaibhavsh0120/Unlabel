import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The authored filled leaf, independent of the outline feature-icon library.
class BrandLeaf extends StatelessWidget {
  const BrandLeaf({this.size = 30, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? '#70EBBA' : '#20966F';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="270 195 485 480">'
      '<defs><mask id="cut"><path fill="white" d="M0 0H1024V1024H0Z"/>'
      '<path d="M338 662 C397 543 496 426 645 320" fill="none" stroke="black" stroke-width="17" stroke-linecap="round"/></mask></defs>'
      '<path d="M348 612 C265 392 419 226 728 218 C736 474 602 640 394 630 Z" fill="$color" mask="url(#cut)"/></svg>',
      width: size,
      height: size,
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
