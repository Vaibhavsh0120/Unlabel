import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/brand_mark.dart';
import 'ui_components.dart';

/// Guests can begin immediately; account sign-in is a separate optional action.
class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.onContinue, this.onSignIn, super.key});

  final VoidCallback onContinue;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xff101b17) : const Color(0xfffbfefd),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 900;
                final side = desktop ? 56.0 : 24.0;
                return SingleChildScrollView(
                  key: const Key('welcome-scroll'),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1288,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: side,
                          vertical: desktop ? 64 : 28,
                        ),
                        child: desktop
                            ? _desktop(
                                context,
                                math.min(1288, constraints.maxWidth) - side * 2,
                              )
                            : _mobile(context, constraints.maxWidth - side * 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context, double width) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const _WelcomeWordmark(),
      const SizedBox(height: 24),
      _WelcomeHero(size: math.min(380, width * .96)),
      const SizedBox(height: 12),
      _headline(context, desktop: false),
      const SizedBox(height: 8),
      _subtitle(context, desktop: false),
      const SizedBox(height: 24),
      const _WelcomeFeatures(),
      const SizedBox(height: 24),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _WelcomeActions(onContinue: onContinue, onSignIn: onSignIn),
      ),
    ],
  );

  Widget _desktop(BuildContext context, double width) => Row(
    key: const Key('welcome-desktop-layout'),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _WelcomeWordmark(centered: false, desktop: true),
            const SizedBox(height: 48),
            _headline(context, desktop: true, wide: width >= 1120),
            const SizedBox(height: 12),
            _subtitle(context, desktop: true),
            const SizedBox(height: 36),
            const _WelcomeFeatures(desktop: true),
            const SizedBox(height: 32),
            _WelcomeActions(onContinue: onContinue, onSignIn: onSignIn),
          ],
        ),
      ),
      const SizedBox(width: 30),
      Expanded(child: _WelcomeHero(size: math.min(660, width * .44))),
    ],
  );

  Widget _headline(
    BuildContext context, {
    required bool desktop,
    bool wide = false,
  }) => Text(
    'Scan food smarter',
    key: const Key('welcome-headline'),
    textAlign: desktop ? TextAlign.start : TextAlign.center,
    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
      color: _ink(context),
      fontSize: desktop ? (wide ? 68 : 56) : 34,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: desktop ? -1.8 : -1.1,
    ),
  );

  Widget _subtitle(BuildContext context, {required bool desktop}) => Text(
    'Simple insights from every label.',
    textAlign: desktop ? TextAlign.start : TextAlign.center,
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: _muted(context),
      fontSize: desktop ? 27 : 18,
      height: 1.35,
      letterSpacing: -.25,
    ),
  );
}

Color _ink(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xffeefbf4)
    : const Color(0xff042c29);

Color _muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xffbec8d0)
    : const Color(0xff77819c);

class _WelcomeWordmark extends StatelessWidget {
  const _WelcomeWordmark({this.centered = true, this.desktop = false});
  final bool centered;
  final bool desktop;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Unlabel',
              style: TextStyle(
                fontSize: desktop ? 50 : 40,
                fontWeight: FontWeight.w800,
                color: _ink(context),
                height: 1,
                letterSpacing: -1.9,
              ),
            ),
            const SizedBox(width: 3),
            BrandLeaf(size: desktop ? 46 : 38),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Know Beyond the Label',
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: desktop ? 20 : 16,
          color: _muted(context),
          height: 1.2,
        ),
      ),
    ],
  );
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/artwork/welcome-scan-package.webp',
    key: const Key('welcome-package-artwork'),
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class _WelcomeFeatures extends StatelessWidget {
  const _WelcomeFeatures({this.desktop = false});
  final bool desktop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      const chips = [
        _WelcomeFeature(label: 'Scan labels', featureIcon: 'barcode'),
        _WelcomeFeature(label: 'Compare products', icon: Icons.balance),
        _WelcomeFeature(label: 'Easy insights', leaf: true),
      ];
      if (constraints.maxWidth < 280 || scale > 1.45) {
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: chips,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: desktop ? 14 : 8),
            Expanded(child: chips[i]),
          ],
        ],
      );
    },
  );
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.label,
    this.icon,
    this.featureIcon,
    this.leaf = false,
  });
  final String label;
  final IconData? icon;
  final String? featureIcon;
  final bool leaf;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 900 ? 7 : 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff1b342a) : const Color(0xffeffaf5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 125;
          final symbol = Container(
            width: tight ? 28 : 44,
            height: tight ? 28 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? const Color(0xff284c3c) : const Color(0xffddf8ed),
            ),
            child: Center(
              child: leaf
                  ? BrandLeaf(size: tight ? 23 : 29)
                  : featureIcon != null
                  ? FeatureIcon(
                      featureIcon!,
                      size: tight ? 23 : 30,
                      color: dark
                          ? const Color(0xff70ebba)
                          : const Color(0xff075e49),
                    )
                  : Icon(
                      icon,
                      size: tight ? 24 : 30,
                      color: dark
                          ? const Color(0xff70ebba)
                          : const Color(0xff075e49),
                    ),
            ),
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              symbol,
              SizedBox(width: tight ? 5 : 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _ink(context),
                    fontSize: tight ? 12 : 16,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({required this.onContinue, this.onSignIn});
  final VoidCallback onContinue;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff38a77f).withValues(alpha: .16),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton(
          key: const Key('welcome-continue'),
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff09614f),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            minimumSize: const Size(0, 60),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FeatureIcon('scanner', size: 25, color: Colors.white),
              const SizedBox(width: 16),
              const Flexible(
                child: Text(
                  'Get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.arrow_forward, size: 26),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        key: const Key('welcome-sign-in'),
        onPressed: onSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(0, 48),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff325944)
                : const Color(0xffcdece1),
            width: 1.4,
          ),
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'I already have an account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
