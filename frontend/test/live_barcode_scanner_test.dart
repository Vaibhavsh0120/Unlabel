import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unlabel/core/capture/live_barcode_scanner.dart';
import 'package:unlabel/core/capture/live_barcode_photo.dart';

import 'automatic_label_reader_test.dart' show barcodePhoto;

class _Controller extends MobileScannerController {
  _Controller() : super(autoStart: false);
  final zooms = <double>[];
  final focusPoints = <Offset>[];
  Future<BarcodeCapture?>? photoOperation;
  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    value = value.copyWith(
      isInitialized: true,
      isRunning: true,
      zoomScale: 0,
      size: const Size(1920, 1080),
      cameraDirection: CameraFacing.back,
    );
  }

  @override
  Future<void> stop() async {
    value = value.copyWith(isRunning: false);
  }

  @override
  Future<void> setZoomScale(double scale) async {
    zooms.add(scale);
    value = value.copyWith(zoomScale: scale);
  }

  @override
  Future<void> setFocusPoint(Offset point) async {
    focusPoints.add(point);
  }

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    if (photoOperation != null) return photoOperation!;
    throw UnsupportedError('SDK still decoder unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'focus uses the visible preview crop instead of whole-screen coordinates',
    () async {
      final controller = _Controller();
      final scanner = LiveBarcodeScanner(controller: controller);
      addTearDown(scanner.dispose);
      await scanner.start();
      await scanner.focusAt(const Offset(150, 150), const Size(300, 300));
      expect(controller.focusPoints.last, const Offset(.5, .5));
      await scanner.focusAt(Offset.zero, const Size(300, 300));
      expect(controller.focusPoints.last, const Offset(.21875, 0));
      controller.value = controller.value.copyWith(
        deviceOrientation: DeviceOrientation.landscapeLeft,
      );
      await scanner.focusAt(Offset.zero, const Size(600, 300));
      expect(controller.focusPoints.last, const Offset(0, .359375));
    },
  );
  test('cancel rejects an SDK still result before accepting or starting a fallback', () async {
    final controller = _Controller();
    final pending = Completer<BarcodeCapture?>();
    controller.photoOperation = pending.future;
    final scanner = LiveBarcodeScanner(controller: controller);
    addTearDown(scanner.dispose);
    final reading = scanner.analyzeBytes(await barcodePhoto());
    scanner.cancelPhotoRead();
    pending.complete(
      const BarcodeCapture(
        barcodes: [
          Barcode(format: BarcodeFormat.ean13, rawValue: '8901764051258'),
        ],
      ),
    );
    expect(await reading, isNull);
  });
  test(
    'SDK still failure falls back to independent local EAN decoding',
    () async {
      final scanner = LiveBarcodeScanner(controller: _Controller());
      addTearDown(scanner.dispose);
      expect(
        (await scanner.analyzeBytes(await barcodePhoto()))?.code,
        '8901764051258',
      );
    },
  );
  test(
    'pinch zoom changes camera scale, clamps and ignores stopped camera',
    () async {
      final controller = _Controller();
      final scanner = LiveBarcodeScanner(controller: controller);
      addTearDown(scanner.dispose);
      scanner.beginZoom();
      await scanner.updateZoom(2);
      expect(controller.zooms, isEmpty);
      await scanner.start();
      scanner.beginZoom();
      await scanner.updateZoom(2);
      expect(controller.zooms.last, inExclusiveRange(0, 1));
      await scanner.updateZoom(100);
      expect(controller.zooms.last, 1);
      await scanner.updateZoom(.1);
      expect(controller.zooms.last, 0);
      final count = controller.zooms.length;
      await scanner.stop();
      await scanner.updateZoom(2);
      expect(controller.zooms.length, count);
    },
  );
  test('SDK product adapter rejects QR values and failed checksum', () {
    expect(
      productBarcodeDetection(
        const BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.qrCode, rawValue: '8901764051258'),
            Barcode(format: BarcodeFormat.ean13, rawValue: '8901764051259'),
          ],
        ),
      ),
      isNull,
    );
    final detection = productBarcodeDetection(
      const BarcodeCapture(
        size: Size(100, 50),
        barcodes: [
          Barcode(
            format: BarcodeFormat.ean13,
            rawValue: '8901764051258',
            corners: [
              Offset(10, 10),
              Offset(90, 10),
              Offset(90, 40),
              Offset(10, 40),
            ],
          ),
        ],
      ),
    );
    expect(detection!.code, '8901764051258');
    expect(detection.points.first, const Offset(.1, .2));
  });

  test('UPC-E SDK output expands to canonical checksum-valid UPC-A', () {
    final detection = productBarcodeDetection(
      const BarcodeCapture(
        barcodes: [Barcode(format: BarcodeFormat.upcE, rawValue: '04252614')],
      ),
    );
    expect(detection!.code, '042100005264');
  });

  test(
    'native SDK photo file is removed after successful and failed analysis',
    () async {
      for (final fail in [false, true]) {
        String? temporaryPath;
        Future<String> analyze() =>
            withBarcodePhoto(Uint8List.fromList([1, 2, 3]), (path) async {
              temporaryPath = path;
              expect(await File(path).readAsBytes(), [1, 2, 3]);
              if (fail) throw StateError('synthetic failure');
              return 'decoded';
            });
        if (fail) {
          await expectLater(analyze(), throwsStateError);
        } else {
          expect(await analyze(), 'decoded');
        }
        expect(await File(temporaryPath!).exists(), isFalse);
        expect(await File(temporaryPath!).parent.exists(), isFalse);
      }
    },
  );
}
