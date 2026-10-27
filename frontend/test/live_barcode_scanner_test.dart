import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unlabel/core/capture/live_barcode_scanner.dart';
import 'package:unlabel/core/capture/live_barcode_photo.dart';

void main() {
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
