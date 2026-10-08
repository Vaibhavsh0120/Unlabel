import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/capture/live_camera.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB3sAAAAASUVORK5CYII=',
);

class _Camera extends LiveCamera {
  int starts = 0, stops = 0, captures = 0;
  bool active = false;
  bool available = true;
  @override
  bool get ready => active;
  @override
  bool get busy => false;
  @override
  String? get error => available
      ? null
      : 'Camera permission is needed. Allow it in browser settings, then retry, or choose a photo.';
  @override
  Future<void> start() async {
    starts++;
    active = available;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    active = false;
    notifyListeners();
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    return _photo;
  }

  @override
  Widget buildPreview() =>
      const ColoredBox(key: Key('test-live-feed'), color: Colors.green);
}

Future<void> _show(
  WidgetTester tester,
  _Camera camera, {
  Future<Uint8List?> Function()? pickPhoto,
  Future<void> Function(Map<int, Uint8List>)? review,
  Future<void> Function()? onBarcode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(Brightness.light),
      home: ScanLandingPage(
        camera: camera,
        pickPhoto: pickPhoto ?? () async => null,
        onBarcode: onBarcode ?? () async {},
        onEnterLabel: () async {},
        onReviewCapture: review,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pending Android gallery recovery cannot replace a new capture', (
    tester,
  ) async {
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
        theme: UnlabelTheme.forBrightness(Brightness.light),
        home: ScanLandingPage(
          camera: camera,
          onBarcode: () async {},
          onEnterLabel: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(camera.ready, isTrue);
    await tester.tap(find.byKey(const Key('scan-primary')));
    await tester.pumpAndSettle();
    expect(camera.captures, 1);
    pending.complete({
      'pathList': ['/stale/recovered-photo.png'],
      'type': 'image',
    });
    await tester.pumpAndSettle();
    expect(find.text('Review Label'), findsOneWidget);
    expect(find.textContaining('could not be restored'), findsNothing);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      _photo,
    );
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'camera starts immediately while lost-gallery recovery times out safely',
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
      var barcodes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: UnlabelTheme.forBrightness(Brightness.light),
          home: ScanLandingPage(
            camera: camera,
            onBarcode: () async => barcodes++,
            onEnterLabel: () async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Working…'), findsNothing);
      expect(camera.starts, 1);
      expect(camera.ready, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Working…'), findsNothing);
      expect(camera.ready, isTrue);
      await tester.tap(find.text('Barcode'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pumpAndSettle();
      expect(barcodes, 1);
      pending.complete({
        'pathList': ['/late/private-photo.png'],
        'type': 'image',
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(camera.ready, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'opening Scan starts live preview; background and disposal stop it',
    (tester) async {
      final camera = _Camera();
      await _show(tester, camera);
      expect(camera.starts, 1);
      expect(find.byKey(const Key('test-live-feed')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(camera.ready, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(const SizedBox());
      expect(camera.ready, isFalse);
      camera.dispose();
    },
  );
  testWidgets(
    'capture freezes local photo, stops preview, reviews and retakes',
    (tester) async {
      final camera = _Camera();
      Map<int, Uint8List>? reviewed;
      await _show(tester, camera, review: (photos) async => reviewed = photos);
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pumpAndSettle();
      expect(camera.captures, 1);
      expect(camera.ready, isFalse);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Review Label'), findsOneWidget);
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pumpAndSettle();
      expect(reviewed?.keys, [0]);
      expect(reviewed?[0], _photo);
      expect(camera.ready, isFalse);
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();
      expect(camera.ready, isTrue);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets(
    'gallery cancellation resumes preview; a picked photo remains local',
    (tester) async {
      final camera = _Camera();
      final result = Completer<Uint8List?>();
      await _show(tester, camera, pickPhoto: () => result.future);
      await tester.tap(find.text('Use Gallery'));
      await tester.pump();
      expect(camera.ready, isFalse);
      result.complete(null);
      await tester.pumpAndSettle();
      expect(camera.ready, isTrue);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
      final camera2 = _Camera();
      await _show(tester, camera2, pickPhoto: () async => _photo);
      await tester.tap(find.text('Use Gallery'));
      await tester.pumpAndSettle();
      expect(camera2.ready, isFalse);
      expect(find.text('Review Label'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      camera2.dispose();
    },
  );
  testWidgets(
    'manual barcode fallback pauses the camera until its sheet closes',
    (tester) async {
      final camera = _Camera();
      final closeSheet = Completer<void>();
      var opened = 0;
      await _show(
        tester,
        camera,
        onBarcode: () {
          opened++;
          return closeSheet.future;
        },
      );
      await tester.tap(find.text('Barcode'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan-primary')));
      await tester.pump();
      expect(opened, 1);
      expect(camera.ready, isFalse);
      expect(camera.captures, 0);
      closeSheet.complete();
      await tester.pumpAndSettle();
      expect(camera.ready, isTrue);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets(
    'Scan fits narrow, short, landscape and enlarged text without scrolling',
    (tester) async {
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
        await _show(tester, camera);
        expect(find.byType(Scrollable), findsNothing);
        expect(find.text('Barcode lookup'), findsNothing);
        expect(find.text('Find by name or brand'), findsNothing);
        expect(find.byKey(const Key('scan-preview')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('scan-preview'))).height,
          greaterThan(120),
        );
        expect(
          tester.getRect(find.text('Use Gallery')).bottom,
          lessThan(sample.$1.height),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        camera.dispose();
      }
    },
  );
}
