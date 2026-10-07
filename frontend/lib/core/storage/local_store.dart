import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_failure.dart';
import '../models/product_report.dart';

abstract interface class PreferencesAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class AsyncPreferencesAdapter implements PreferencesAdapter {
  AsyncPreferencesAdapter({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

class LocalReport {
  const LocalReport({
    required this.id,
    required this.report,
    required this.storedAt,
  });
  final String id;
  final ProductReport report;
  final DateTime storedAt;
  JsonMap toJson() => {
    'id': id,
    'stored_at': storedAt.toUtc().toIso8601String(),
    'report': report.raw,
  };

  factory LocalReport.fromJson(JsonMap value) {
    final id = value['id'];
    final at = value['stored_at'];
    final report = value['report'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 512 ||
        at is! String ||
        DateTime.tryParse(at) == null ||
        report is! JsonMap) {
      throw const FormatException('Invalid local entry');
    }
    return LocalReport(
      id: id,
      report: ProductReport.fromJson(report),
      storedAt: DateTime.parse(at),
    );
  }
}

/// Device/browser convenience storage, not a cloud backup. No tokens, photos,
/// raw OCR or scanner identities are written here. Clear touches only our keys.
class LocalStore {
  LocalStore({PreferencesAdapter? preferences, DateTime Function()? clock})
    : _preferences = preferences ?? AsyncPreferencesAdapter(),
      _clock = clock ?? DateTime.now;
  static const historyKey = 'unlabel.client.v1.history';
  static const savedKey = 'unlabel.client.v1.saved';
  static const appearanceKey = 'unlabel.client.v1.appearance';
  static const welcomeKey = 'unlabel.client.v1.welcomeDone';
  static const maxReportBytes = 256 * 1024;
  static const maxNamespaceBytes = 2 * 1024 * 1024;
  static const maxHistory = 100;
  static const maxSaved = 50;
  final PreferencesAdapter _preferences;
  PreferencesAdapter get preferences => _preferences;
  final DateTime Function() _clock;
  Future<void> _tail = Future.value();
  String? recoveryWarning;

  Future<bool> welcomeCompleted() => _serial(() async {
    try {
      return await _preferences.read(welcomeKey) == '1';
    } catch (_) {
      return false;
    }
  });

  Future<void> completeWelcome() => _serial(() async {
    try {
      await _preferences.write(welcomeKey, '1');
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Welcome could not be remembered on this device. You can still use the app.',
      );
    }
  });

  Future<String> appearance() => _serial(() async {
    try {
      final value = await _preferences.read(appearanceKey);
      if (value == null) return 'light';
      if (!const ['system', 'light', 'dark'].contains(value)) {
        throw const AppFailure(
          'local_data_corrupt',
          'The stored appearance setting could not be read. Choose an appearance to replace it.',
        );
      }
      return value;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'The appearance setting could not be read on this device.',
      );
    }
  });

  Future<void> setAppearance(String value) => _serial(() async {
    if (!const ['system', 'light', 'dark'].contains(value)) {
      throw const AppFailure(
        'invalid_input',
        'Choose System, Light or Dark appearance.',
      );
    }
    try {
      await _preferences.write(appearanceKey, value);
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'The appearance could not be saved. Please try again.',
      );
    }
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<LocalReport>> history() =>
      _serial(() => _read(historyKey, maxHistory));
  Future<List<LocalReport>> saved() => _serial(() => _read(savedKey, maxSaved));
  Future<void> record(ProductReport report) =>
      _serial(() => _add(historyKey, maxHistory, report, evict: true));
  Future<void> save(ProductReport report) =>
      _serial(() => _add(savedKey, maxSaved, report, evict: false));
  Future<void> removeSaved(String id) => _serial(() async {
    final entries = await _read(savedKey, maxSaved);
    await _write(savedKey, entries.where((entry) => entry.id != id).toList());
  });
  Future<void> clearHistory() => _serial(() async {
    try {
      await _preferences.remove(historyKey);
      recoveryWarning = null;
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'History could not be cleared on this device. Please try again.',
      );
    }
  });
  Future<void> clearSaved() => _serial(() async {
    try {
      await _preferences.remove(savedKey);
      recoveryWarning = null;
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Saved products could not be cleared on this device. Please try again.',
      );
    }
  });

  Future<List<LocalReport>> _read(String key, int cap) async {
    String? text;
    try {
      text = await _preferences.read(key);
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'Local reports could not be read on this device.',
      );
    }
    if (text == null) return [];
    if (text.length > maxNamespaceBytes ||
        utf8.encode(text).length > maxNamespaceBytes) {
      throw const AppFailure(
        'local_data_corrupt',
        'Local report data is larger than the app allows. Clear this list to recover.',
      );
    }
    try {
      final data = jsonDecode(text);
      if (data is! JsonMap ||
          data['schema_version'] != '1' ||
          data['entries'] is! List) {
        throw const FormatException();
      }
      final values = data['entries'] as List;
      final recovered = <LocalReport>[];
      final identifiers = <String>{};
      var skipped = values.length > cap;
      for (final item in values.take(cap)) {
        try {
          if (item is! JsonMap ||
              utf8.encode(jsonEncode(item)).length > maxReportBytes) {
            throw const FormatException();
          }
          final entry = LocalReport.fromJson(item);
          if (!identifiers.add(entry.id)) {
            skipped = true;
            continue;
          }
          recovered.add(entry);
        } catch (_) {
          skipped = true;
        }
      }
      if (skipped) recoveryWarning = 'Some unreadable local reports were skipped. Valid reports are still available.';
      return recovered;
    } catch (_) {
      throw const AppFailure(
        'local_data_corrupt',
        'This local report list could not be read. Clear this list to recover; other app data is kept.',
      );
    }
  }

  Future<void> _add(
    String key,
    int cap,
    ProductReport report, {
    required bool evict,
  }) async {
    final entry = LocalReport(
      id: report.id,
      report: report,
      storedAt: _clock(),
    );
    if (utf8.encode(jsonEncode(entry.toJson())).length > maxReportBytes) {
      throw const AppFailure(
        'local_capacity',
        'The report is open, but it is too large to keep on this device.',
      );
    }
    final entries = await _read(key, cap);
    entries.removeWhere((item) => item.id == entry.id);
    if (!evict && entries.length >= cap) {
      throw const AppFailure(
        'local_capacity',
        'Saved products are full (50). Remove a saved product before adding another.',
      );
    }
    entries.insert(0, entry);
    if (entries.length > cap) entries.removeRange(cap, entries.length);
    if (evict) {
      while (_encodedSize(entries) > maxNamespaceBytes && entries.length > 1) {
        entries.removeLast();
      }
    }
    await _write(key, entries);
  }

  int _encodedSize(List<LocalReport> entries) =>
      utf8.encode(_encode(entries)).length;
  String _encode(List<LocalReport> entries) => jsonEncode({
    'schema_version': '1',
    'entries': entries.map((entry) => entry.toJson()).toList(),
  });
  Future<void> _write(String key, List<LocalReport> entries) async {
    final text = _encode(entries);
    if (utf8.encode(text).length > maxNamespaceBytes) {
      throw const AppFailure(
        'local_capacity',
        'This local list is full. Remove a saved product to make room.',
      );
    }
    try {
      await _preferences.write(key, text);
    } catch (_) {
      throw const AppFailure(
        'local_storage',
        'The report is open, but local saving failed on this device. Please try again.',
      );
    }
  }
}
