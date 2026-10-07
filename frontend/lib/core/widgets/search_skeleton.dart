import 'package:flutter/material.dart';

/// One inexpensive pulse for the first page; motion stops offscreen or when
/// reduced motion is requested. No placeholder pretends to be a product.
class SearchSkeleton extends StatefulWidget {
  const SearchSkeleton({super.key});
  @override
  State<SearchSkeleton> createState() => _SearchSkeletonState();
}

class _SearchSkeletonState extends State<SearchSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = .5;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Semantics(
      label: 'Searching products',
      liveRegion: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulse,
          child: Column(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    bar(72, 88),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: .8,
                            child: bar(double.infinity, 16),
                          ),
                          const SizedBox(height: 12),
                          FractionallySizedBox(
                            widthFactor: .5,
                            child: bar(double.infinity, 12),
                          ),
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: .6,
                            child: bar(double.infinity, 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          builder: (_, child) =>
              Opacity(opacity: .45 + _pulse.value * .35, child: child),
        ),
      ),
    );
  }
}
