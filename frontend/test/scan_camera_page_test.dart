import 'dart:async';
import 'dart:convert';

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

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=',
);

class _Camera extends LiveCamera {
  int starts = 0, captures = 0;
  bool active = false, available = true;
  @override
  bool get ready => active;
  @override
  bool get busy => false;
  @override
  String? get error => available ? null : 'Camera permission is needed.';
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
    await tester.tap(find.text('Use Gallery'));
    await tester.pumpAndSettle();
    expect(camera.ready, isTrue);
    await tester.tap(find.text('Use Gallery'));
    await _finishRead(tester);
    expect(reader.reads, hasLength(1));
    expect(find.text('View results'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets('unknown barcode requests front/back photos without typing', (
    tester,
  ) async {
    final camera = _Camera(),
        reader = _Reader()
          ..operation = () async =>
              const AutomaticScanResult(barcode: '8901764051258');
    await _show(tester, camera, reader);
    await tester.tap(find.text('Barcode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-primary')));
    await _finishRead(tester);
    expect(reader.reads.single.keys, [2]);
    expect(
      find.textContaining('Photograph the front and back'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
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
      expect(find.byType(Scrollable), findsNothing);
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
  });
}
