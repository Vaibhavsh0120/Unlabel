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
      if (widget.welcome) 'assets/artwork/welcome-scan-package.webp',
      if (!widget.welcome) ...[
        desktop
            ? 'assets/artwork/desktop-scan-hero.webp'
            : dark
            ? 'assets/artwork/scan-hero-dark.webp'
            : 'assets/artwork/scan-hero-light.webp',
        if (desktop) 'assets/artwork/recent-scans-empty.webp',
        ...InsightCatalogue.daily(DateTime.now())
            .map((article) => article.asset),
        if (desktop) 'assets/artwork/sidebar-mint-leaves.webp',
        'assets/artwork/profile-avatar.webp',
      ],
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
