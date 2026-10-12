import 'dart:async';

import 'package:flutter/material.dart';

import '../features/scanner/domain/insight_catalogue.dart';

/// Warm public illustrations without delaying the page or fetching product photos.
/// Use the same AssetImage keys as Image.asset so its first frame can use the cache.
class ArtworkWarmup extends StatefulWidget {
  const ArtworkWarmup({required this.child, required this.welcome, super.key});
  final Widget child;
  final bool welcome;

  @override
  State<ArtworkWarmup> createState() => _ArtworkWarmupState();
}

class _ArtworkWarmupState extends State<ArtworkWarmup> {
  final _attempted = <String>{};
  final _queue = <String>[];
  bool _warming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(ArtworkWarmup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    final desktop = MediaQuery.sizeOf(context).width >= 1200;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final assets = [
      if (widget.welcome) ...[
        'assets/artwork/welcome-scan-package.webp',
      ],
      desktop
          ? 'assets/artwork/desktop-scan-hero.webp'
          : dark
          ? 'assets/artwork/scan-hero-dark.webp'
          : 'assets/artwork/scan-hero-light.webp',
      if (desktop) 'assets/artwork/recent-scans-empty.webp',
      ...InsightCatalogue.daily(DateTime.now()).map((article) => article.asset),
      if (desktop) 'assets/artwork/sidebar-mint-leaves.webp',
      'assets/artwork/profile-avatar.webp',
      'assets/artwork/history-empty.webp',
      'assets/artwork/saved-empty.webp',
      'assets/artwork/not-found-art.webp',
      'assets/artwork/sources-intro.webp',
      'assets/artwork/sources-facts.webp',
      'assets/artwork/sources-package.webp',
      'assets/artwork/sources-globe.webp',
      'assets/artwork/sources-guidance.webp',
      'assets/artwork/sources-books.webp',
      'assets/artwork/sources-boundary.webp',
    ];
    for (final asset in assets) {
      if (_attempted.add(asset)) _queue.add(asset);
    }
    if (!_warming) unawaited(_warm());
  }

  Future<void> _warm() async {
    _warming = true;
    while (mounted && _queue.isNotEmpty) {
      final asset = _queue.removeAt(0);
      // Sequential decoding bounds memory/work on phones. Failure is decorative;
      // the screen remains usable and normal Image.asset loading can retry.
      await precacheImage(
        AssetImage(asset),
        context,
        onError: (error, stack) {},
      );
    }
    _warming = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
