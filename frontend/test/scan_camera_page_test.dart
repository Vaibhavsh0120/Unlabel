import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/capture/local_label_parser.dart';
import 'package:unlabel/core/capture/live_camera.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';
import 'package:unlabel/features/scanner/presentation/scan_processing_overlay.dart';
import 'package:unlabel/features/scanner/presentation/mobile_navigation.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
);

class _Camera extends LiveCamera {
  int starts = 0, captures = 0;
  bool active = false, available = true;
  bool torchSupported = false;
  String? controlError;
  @override
  bool get ready => active;
  @override
  bool get busy => false;
  @override
  String? get error =>
      controlError ?? (available ? null : 'Camera permission is needed.');
  @override
  bool get canToggleTorch => torchSupported && controlError == null;
  @override
  Future<void> toggleTorch() async {
    controlError =
        'Flash is unavailable on this camera. Use brighter lighting.';
    notifyListeners();
  }

  @override
  Future<void> start() async {
    starts++;
    active = available;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    active = false;
    notifyListeners();
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    return _photo;
  }

  @override
  Future<Uint8List> captureFramed(Size viewport) => capture();

  @override
  Widget buildPreview() =>
      const ColoredBox(key: Key('test-live-feed'), color: Colors.green);
}

class _Reader extends AutomaticLabelReader {
  _Reader() : super(UnlabelRepository(baseUrl: 'https://example.test'));
  final reads = <Map<int, Uint8List>>[];
  Future<AutomaticScanResult> Function()? operation;
  int cancellations = 0;
  @override
  Future<AutomaticScanResult> read(
    Map<int, Uint8List> photos, {
    required Future<bool> Function() allowCloud,
  }) async {
    reads.add(photos);
    return operation != null
        ? operation!()
        : AutomaticScanResult(
            label: readLocalLabel('Synthetic oats', 'Ingredients: Oats'),
          );
  }

  @override
  void cancel() {
    cancellations++;
    super.cancel();
  }

  @override
  void dispose() {
    repository.close();
    super.dispose();
  }
}

Future<void> _show(
  WidgetTester tester,
  _Camera camera,
  _Reader reader, {
  Future<Uint8List?> Function()? pickPhoto,
  Future<void> Function(AutomaticScanResult, Uint8List?)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(Brightness.light),
      home: ScanLandingPage(
        camera: camera,
        reader: reader,
        pickPhoto: pickPhoto ?? () async => null,
        onResult: onResult ?? (_, _) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _finishRead(WidgetTester tester) async {
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'scanner task header keeps only its title and frees preview space',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final camera = _Camera();
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: Scaffold(
            extendBody: true,
            appBar: AppBar(toolbarHeight: 64, title: const Text('Unlabel')),
            body: ScanLandingPage(
              camera: camera,
              reader: _Reader(),
              pickPhoto: () async => null,
              onResult: (_, _) async {},
            ),
            bottomNavigationBar: MobileNavigation(
              selectedIndex: 1,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scan Label'), findsOneWidget);
      expect(find.byTooltip('Back to Home'), findsNothing);
      expect(find.byTooltip('Photo reading settings'), findsNothing);
      expect(
        find.text('Point your camera at a product barcode.'),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const Key('scan-preview'))).height,
      greaterThan(844 / 2),
      );
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );

  testWidgets('mobile shutter exposes one named accessible capture action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final camera = _Camera();
    await _show(tester, camera, _Reader());
    final data = tester
        .getSemantics(find.byKey(const Key('scan-primary')))
        .getSemanticsData();
    expect(data.label, 'Click Photo');
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    final garden = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/artwork/scanner-garden-v1.png',
    );
    expect(garden, findsOneWidget);
    expect(
      tester.getRect(garden).bottom,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const Key('scan-gallery'))).bottom,
      ),
    );
    await tester.tap(find.byKey(const Key('scan-primary')));
    await _finishRead(tester);
    expect(camera.captures, 1);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
    semantics.dispose();
  });

  testWidgets('unavailable camera has one working gallery action', (
    tester,
  ) async {
    final camera = _Camera()..available = false;
    var selections = 0;
    await _show(
      tester,
      camera,
      _Reader(),
      pickPhoto: () async {
        selections++;
        return null;
      },
    );
    expect(find.text('Choose Photo'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('scan-primary')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('scan-gallery')));
    await tester.pumpAndSettle();
    expect(selections, 1);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets(
    'failed flash shows a persistent error while capture stays usable',
    (tester) async {
      final camera = _Camera()..torchSupported = true;
      await _show(tester, camera, _Reader());
      await tester.tap(find.byTooltip('Turn flash on'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Flash is unavailable'), findsOneWidget);
      expect(camera.ready, isTrue);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.flash_off_rounded),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets(
    'processing retains status without motion when reduced motion is enabled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const SizedBox(
              width: 320,
              height: 480,
              child: ScanProcessingOverlay(barcode: true, active: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reading barcode…'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('camera starts immediately; background and disposal stop it', (
    tester,
  ) async {
    final camera = _Camera();
    await _show(tester, camera, _Reader());
    expect(camera.starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.ready, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, 2);
    await tester.pumpWidget(const SizedBox());
    expect(camera.ready, isFalse);
    camera.dispose();
  });
  testWidgets('capture reads automatically and opens results without a form', (
    tester,
  ) async {
    final camera = _Camera(), reader = _Reader();
    AutomaticScanResult? opened;
    Uint8List? front;
    await _show(
      tester,
      camera,
      reader,
      onResult: (value, photo) async {
        opened = value;
        front = photo;
      },
    );
    await tester.tap(find.byKey(const Key('scan-mode-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-primary')));
    await _finishRead(tester);
    expect(camera.captures, 1);
    expect(camera.ready, isFalse);
    expect(reader.reads.single.keys, [0]);
    expect(find.text('View results'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('scan-primary')));
    await tester.pumpAndSettle();
    expect(opened?.label?.ingredients, 'Oats');
    expect(front, _photo);
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(camera.ready, isTrue);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets('gallery cancellation resumes camera; a chosen photo is read', (
    tester,
  ) async {
    final camera = _Camera(), reader = _Reader();
    var photos = 0;
    await _show(
      tester,
      camera,
      reader,
      pickPhoto: () async => photos++ == 0 ? null : _photo,
    );
    await tester.tap(find.byKey(const Key('scan-gallery')));
    await tester.pumpAndSettle();
    expect(camera.ready, isTrue);
    await tester.tap(find.byKey(const Key('scan-gallery')));
    await _finishRead(tester);
    expect(reader.reads, hasLength(1));
    expect(find.text('View results'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets(
    'default barcode opens one product page even when catalogue misses',
    (tester) async {
      final camera = _Camera(),
          reader = _Reader()
            ..operation = () async =>
                const AutomaticScanResult(barcode: '8901764051258');
      AutomaticScanResult? opened;
      await _show(
        tester,
        camera,
        reader,
        onResult: (result, _) async => opened = result,
      );
      await tester.tap(find.byKey(const Key('scan-primary')));
      await _finishRead(tester);
      expect(reader.reads.single.keys, [2]);
      expect(opened?.barcode, '8901764051258');
      expect(opened?.report, isNull);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets('stop discards a late extraction and permits a new photo', (
    tester,
  ) async {
    final camera = _Camera(), reader = _Reader();
    final pending = Completer<AutomaticScanResult>();
    reader.operation = () => pending.future;
    await _show(tester, camera, reader);
    await tester.tap(find.byKey(const Key('scan-primary')));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.tap(find.text('Stop reading'));
    await tester.pumpAndSettle();
    pending.complete(
      AutomaticScanResult(label: readLocalLabel('Late oats', '')),
    );
    await tester.pumpAndSettle();
    expect(find.text('View results'), findsNothing);
    expect(reader.cancellations, greaterThan(0));
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(camera.ready, isTrue);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets(
    'Android lost-picker recovery cannot delay camera or replace a new capture',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      final pending = Completer<Object?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        picker,
        (call) async => call.method == 'retrieve' ? pending.future : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          picker,
          null,
        ),
      );
      final camera = _Camera();
      await tester.pumpWidget(
        MaterialApp(
          home: ScanLandingPage(
            camera: camera,
            reader: _Reader(),
            onResult: (_, _) async {},
          ),
        ),
      );
      await tester.pump();
      expect(camera.ready, isTrue);
      await tester.tap(find.byKey(const Key('scan-primary')));
      await _finishRead(tester);
      pending.complete({
        'pathList': ['/late/photo.png'],
        'type': 'image',
      });
      await tester.pumpAndSettle();
      expect(find.text('View results'), findsOneWidget);
      expect(find.textContaining('could not be restored'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('Scan fits narrow, short, landscape and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final sample in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(844, 390), 1.0),
      (const Size(320, 844), 2.0),
    ]) {
      tester.view.physicalSize = sample.$1;
      tester.platformDispatcher.textScaleFactorTestValue = sample.$2;
      final camera = _Camera()..available = false;
      await _show(tester, camera, _Reader());
      if (sample.$2 == 1 && sample.$1.width < 650) {
        expect(find.byType(Scrollable), findsNothing);
      }
      expect(
        tester.getSize(find.byKey(const Key('scan-preview'))).height,
        greaterThan(120),
      );
      await tester.ensureVisible(find.byKey(const Key('scan-gallery')));
      expect(
        tester.getRect(find.byKey(const Key('scan-gallery'))).bottom,
        lessThan(sample.$1.height),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    }
  });
}
