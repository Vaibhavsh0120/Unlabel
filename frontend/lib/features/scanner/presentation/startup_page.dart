import 'package:flutter/material.dart';

import '../../../core/widgets/brand_mark.dart';

/// Shown during app startup state restoration, with no artificial delay.
class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff8faf4),
    body: Semantics(
      label: 'Loading Unlabel',
      liveRegion: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoSize = (constraints.maxWidth * .15).clamp(48.0, 88.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/artwork/splash-botanical.webp',
                fit: BoxFit.cover,
                cacheWidth: 900,
                excludeFromSemantics: true,
              ),
              Align(
                alignment: const Alignment(0, -.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Unlabel',
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                color: const Color(0xff193d2a),
                                fontSize: logoSize,
                                fontWeight: FontWeight.w400,
                                height: 1,
                                letterSpacing: -2.3,
                              ),
                            ),
                            const SizedBox(width: 2),
                            ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Color(0xff365940),
                                BlendMode.srcIn,
                              ),
                              child: BrandLeaf(size: logoSize * .75),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Know Beyond the Label',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xff3d604c),
                          fontSize: (logoSize * .22).clamp(12.0, 19.0),
                          letterSpacing: 2.4,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Align(
                alignment: Alignment(0, .68),
                child: ExcludeSemantics(child: _StartupDots()),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _StartupDots extends StatelessWidget {
  const _StartupDots();

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('startup-loading-dots'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final color in const [
        Color(0xffbed0bd),
        Color(0xff739580),
        Color(0xffaac5b1),
      ])
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
    ],
  );
}
