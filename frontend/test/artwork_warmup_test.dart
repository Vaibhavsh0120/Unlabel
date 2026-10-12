import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/artwork_warmup.dart';

class _HeldArtworkBundle extends CachingAssetBundle {
  _HeldArtworkBundle(
    this.image,
    this.manifest, {
    this.allowFirst = false,
    this.allowAll = false,
  });
  final ByteData image, manifest;
  final bool allowFirst;
  final bool allowAll;
  final requested = <String>[];
  final held = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') return Future.value(manifest);
    if (!key.startsWith('assets/artwork/')) return rootBundle.load(key);
    requested.add(key);
    if (allowAll || (allowFirst && requested.length == 1)) {
      return Future.value(image);
    }
    return held.future;
  }

  void release() {
    if (!held.isCompleted) held.complete(image);
  }
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Artwork warmup must use bundled illustrations');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData imageBytes, manifest;
  setUpAll(() async {
    final image = await createTestImage(cache: false);
    imageBytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    manifest = await rootBundle.load('AssetManifest.bin');
  });
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('a pending artwork load does not block the page or its action', (
    tester,
  ) async {
    final bundle = _HeldArtworkBundle(imageBytes, manifest);
    final previousOverrides = HttpOverrides.current;
    final network = _NoNetwork();
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = previousOverrides);
    var taps = 0;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          home: ArtworkWarmup(
            welcome: true,
            child: Scaffold(
              body: FilledButton(
                onPressed: () => taps++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(bundle.requested, isNotEmpty);
    expect(bundle.held.isCompleted, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
    expect(taps, 1);
    expect(network.attempts, 0);
    expect(
      bundle.requested.every(
        (asset) =>
            asset.startsWith('assets/artwork/') &&
            Uri.parse(asset).scheme.isEmpty,
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    bundle.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a warmed illustration appears through a normal Image.asset without reloading',
    (tester) async {
      const asset = 'assets/artwork/welcome-scan-package.webp';
      final bundle = _HeldArtworkBundle(imageBytes, manifest, allowFirst: true);
      var showImage = false;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => ArtworkWarmup(
                welcome: true,
                child: Scaffold(
                  body: Column(
                    children: [
                      FilledButton(
                        onPressed: () => setState(() => showImage = true),
                        child: const Text('Show artwork'),
                      ),
                      if (showImage) Image.asset(asset),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final imageContext = tester.element(find.byType(ArtworkWarmup));
      final key = await const AssetImage(asset)
          .obtainKey(createLocalImageConfiguration(imageContext));
      for (
        var frame = 0;
        frame < 30 &&
            !PaintingBinding.instance.imageCache.statusForKey(key).keepAlive;
        frame++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(
        PaintingBinding.instance.imageCache.statusForKey(key).keepAlive,
        isTrue,
      );
      expect(bundle.requested.where((path) => path == asset), hasLength(1));
      await tester.tap(find.widgetWithText(FilledButton, 'Show artwork'));
      await tester.pump();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(bundle.requested.where((path) => path == asset), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      bundle.release();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completed desktop warmup loads bundled illustrations without remote requests',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousOverrides = HttpOverrides.current;
      final network = _NoNetwork();
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      final bundle = _HeldArtworkBundle(imageBytes, manifest, allowAll: true);
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: const MaterialApp(
            home: ArtworkWarmup(
              welcome: false,
              child: Scaffold(body: Text('Ready')),
            ),
          ),
        ),
      );
      var settledFrames = 0;
      for (var frame = 0; frame < 100 && settledFrames < 3; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump();
        if (bundle.requested.isNotEmpty &&
            PaintingBinding.instance.imageCache.pendingImageCount == 0) {
          settledFrames++;
        } else {
          settledFrames = 0;
        }
      }
      expect(settledFrames, 3);
      expect(find.text('Ready'), findsOneWidget);
      expect(bundle.requested.length, greaterThan(2));
      expect(
        bundle.requested.every(
          (asset) =>
              asset.startsWith('assets/artwork/') &&
              Uri.parse(asset).scheme.isEmpty,
        ),
        isTrue,
      );
      expect(network.attempts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
