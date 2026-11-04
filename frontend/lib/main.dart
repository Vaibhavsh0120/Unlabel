import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;

import 'app/unlabel_app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope', 'Inter']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/brand/fonts/$family-OFL.txt'));
    }
  });
  runApp(const UnlabelApp());
}
