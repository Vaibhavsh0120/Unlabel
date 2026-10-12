import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/build_info.dart';

void main() {
  test('Flutter embeds canonical pubspec metadata without custom defines', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+([1-9][0-9]*)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(appBuildName, match.group(1));
    expect(appBuildNumber, match.group(2));
    expect(BuildInfo.version, match.group(1));
    expect(BuildInfo.buildNumber, match.group(2));
  });
}
