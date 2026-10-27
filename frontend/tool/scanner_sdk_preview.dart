// Developer-only deterministic camera-SDK verification. No Firebase/backend.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/capture/automatic_label_reader.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/features/scanner/presentation/scan_landing_page.dart';

class _Reader extends AutomaticLabelReader {
  _Reader() : super(UnlabelRepository(baseUrl: 'https://unused.invalid'));
  @override
  Future<AutomaticScanResult> lookupBarcode(String code) async =>
      AutomaticScanResult(barcode: code);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      theme: UnlabelTheme.forBrightness(Brightness.dark),
      home: const _Preview(),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final _reader = _Reader();
  int count = 0;
  String? code;
  bool show = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('SDK detections: $count; barcode: ${code ?? "none"}'),
      actions: [
        TextButton(
          onPressed: () => setState(() => show = false),
          child: const Text('Close scanner'),
        ),
      ],
    ),
    body: show
        ? ScanLandingPage(
            reader: _reader,
            onResult: (result, _) async {
              setState(() {
                count++;
                code = result.barcode;
              });
            },
          )
        : const Center(child: Text('Scanner closed')),
  );
}
