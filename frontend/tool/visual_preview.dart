// Developer-only entry point. Production main.dart never imports this file.
// Fixture JSON/PNG are copied into the separate preview output by the local
// review script. They are owned synthetic/public catalogue observations.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/capture/live_camera.dart';
import 'package:unlabel/core/capture/barcode_reader.dart';
import 'package:unlabel/core/capture/vision_photo.dart';
import 'package:unlabel/core/capture/local_ocr.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/presentation/extracted_product_page.dart';
import 'package:unlabel/features/scanner/presentation/report_page.dart';
import 'package:unlabel/features/scanner/presentation/researched_product_page.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';
import 'package:unlabel/features/scanner/presentation/product_results_layout.dart';
import 'package:zxing_lib/oned.dart';
import 'package:zxing_lib/zxing.dart';

import 'dart:ui' as ui;

Future<JsonMap> diagnostics(Uint8List photo) async {
  final bits = EAN13Writer().encode(
    '8901764051258',
    BarcodeFormat.ean13,
    600,
    180,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawPaint(ui.Paint()..color = const ui.Color(0xffffffff));
  for (var x = 0; x < 600; x++) {
    if (bits.get(x, 90)) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), 10, 1, 160),
        ui.Paint()..color = const ui.Color(0xff000000),
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 180);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final barcode = BarcodeReader();
  final ocr = LocalOcrReader();
  try {
    final read = await barcode.read(bytes!.buffer.asUint8List());
    final prepared = await VisionPhoto.prepare(photo);
    final text = await ocr.recognize(prepared.bytes);
    return {
      'barcode': read?.code,
      'barcode_anchors': read?.points.length,
      'prepared_bytes': prepared.bytes.length,
      'prepared_width': prepared.size.width,
      'prepared_height': prepared.size.height,
      'ocr_has_identity': text.contains('SYNTHETIC'),
      'ocr_has_ingredients': text.toLowerCase().contains('ingredients'),
      'ocr_has_nutrition': text.toLowerCase().contains('nutrition'),
      'source': 'Owned synthetic fixture; actual browser decoder, ZXing and Tesseract. No backend or physical camera.',
    };
  } finally {
    barcode.dispose();
    ocr.dispose();
  }
}

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Camera extends LiveCamera {
  _Camera(this.photo);
  final Uint8List photo;
  bool _active = false;
  @override
  bool get ready => _active;
  @override
  bool get busy => false;
  @override
  Future<void> start() async {
    _active = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _active = false;
    notifyListeners();
  }

  @override
  Future<Uint8List> capture() async => photo;
  @override
  Widget buildPreview() => Image.memory(photo, fit: BoxFit.contain);
}

class _Reader extends AutomaticLabelReader {
  _Reader(this.label)
    : super(UnlabelRepository(baseUrl: 'https://example.invalid'));
  final ExtractedLabel label;
  @override
  Future<AutomaticScanResult> read(
    Map<int, Uint8List> photos, {
    required Future<bool> Function() allowCloud,
  }) async =>
      AutomaticScanResult(label: label, capturedSlots: photos.keys.toList());
  @override
  void dispose() {
    repository.close();
    super.dispose();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final base = Uri.base.replace(query: '', fragment: '');
  Future<JsonMap> json(String name) async =>
      jsonDecode((await http.get(base.resolve('fixtures/$name.json'))).body)
          as JsonMap;
  final report = ProductReport.fromJson(await json('report'));
  final label = ExtractedLabel.fromJson(await json('label'));
  final product = ResearchedProduct.fromJson(await json('research'));
  final photo = (await http.get(base.resolve('fixtures/label.png'))).bodyBytes;
  final dark = Uri.base.queryParameters['theme'] == 'dark';
  final screen = Uri.base.queryParameters['screen'] ?? 'report';
  if (screen == 'diagnostics') {
    runApp(
      MaterialApp(home: Scaffold(body: FutureBuilder<JsonMap>(
        future: diagnostics(photo),
        builder: (_, snapshot) => SelectableText(jsonEncode(
          snapshot.hasError ? {'error_type': snapshot.error.runtimeType.toString()} :
          snapshot.data ?? {'status': 'Reading owned synthetic fixture'},
        )),
      ))),
    );
    return;
  }
  final navigation = ResultsNavigation(
    home: () {},
    scan: () {},
    history: () {},
    learn: () {},
    products: () {},
    profile: () {},
    notifications: () {},
  );
  final store = LocalStore(preferences: _Preferences());
  Widget extracted() =>
      ExtractedProductPage(label: label, photo: photo, navigation: navigation);
  runApp(
    MaterialApp(
      title: 'Unlabel local synthetic visual review',
      debugShowCheckedModeBanner: false,
      theme: UnlabelTheme.forBrightness(
        dark ? Brightness.dark : Brightness.light,
      ),
      home: switch (screen) {
        'extracted' => extracted(),
        'research' => ResearchedProductPage(
          product: product,
          navigation: navigation,
        ),
        'scan' => Builder(
          builder: (context) => ScanLandingPage(
            camera: _Camera(photo),
            reader: _Reader(label),
            pickPhoto: () async => photo,
            onResult: (_, _) async =>
                Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => extracted())),
          ),
        ),
        _ => ReportPage(
          report: report,
          store: store,
          onChanged: () {},
          sessionPhoto: photo,
          navigation: navigation,
        ),
      },
    ),
  );
}
