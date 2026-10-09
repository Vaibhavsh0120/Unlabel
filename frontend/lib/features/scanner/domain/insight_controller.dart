import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/local_store.dart';
import 'insight_catalogue.dart';

/// Editorial bookmarks are device-wide convenience data. They never enter the
/// product library, a scanner identity namespace or private account sync.
class InsightController extends ChangeNotifier {
  InsightController({
    PreferencesAdapter? preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences ?? AsyncPreferencesAdapter(),
       _clock = clock ?? DateTime.now {
    _updateDay();
  }

  static const savedKey = 'unlabel.client.v1.insightBookmarks';
  static const _maxBytes = 8192;
  final PreferencesAdapter _preferences;
  final DateTime Function() _clock;
  List<String> _savedIds = [];
  List<InsightArticle> _daily = [];
  String _day = '';
  InsightTopic _selectedTopic = InsightTopic.all;
  Timer? _timer;
  Future<void>? _starting;
  Future<void>? _reading;
  bool _started = false;
  bool _disposed = false;
  bool _canWrite = false;
  bool loading = true;
  bool saving = false;
  String? error;

  List<InsightArticle> get all => InsightCatalogue.articles;
  List<InsightArticle> get daily => _daily;
  InsightTopic get selectedTopic => _selectedTopic;
  List<InsightArticle> get visible => _selectedTopic == InsightTopic.all
      ? _daily
      : List.unmodifiable(all.where((item) => item.topic == _selectedTopic));
  List<InsightArticle> get saved => List.unmodifiable(
    _savedIds.map(InsightCatalogue.byId).whereType<InsightArticle>(),
  );
  bool isSaved(String id) => _savedIds.contains(id);

  Future<void> start() {
    if (_disposed) return Future.value();
    if (_started) {
      refreshDay();
      return _reading ?? _starting ?? Future.value();
    }
    _started = true;
    _scheduleMidnight();
    return _starting = reloadSaved();
  }

  Future<void> reloadSaved() {
    if (_disposed || saving) return Future.value();
    final reading = _reading;
    if (reading != null) return reading;
    // Publish only after assigning the shared future. A listener may request a
    // retry synchronously from notifyListeners; it must join this same read.
    final completion = Completer<void>();
    _reading = completion.future;
    loading = true;
    _publish();
    unawaited(_loadSaved(completion));
    return completion.future;
  }

  Future<void> _loadSaved(Completer<void> completion) async {
    try {
      final ids = await _readSaved();
      if (_disposed) return;
      _savedIds = ids;
      _canWrite = true;
      error = null;
    } catch (_) {
      if (_disposed) return;
      _canWrite = false;
      error = 'Saved insights could not be read on this device. Retry, or clear saved insights to start again.';
    } finally {
      _reading = null;
      completion.complete();
      if (!_disposed) {
        loading = false;
        _publish();
      }
    }
  }

  Future<List<String>> _readSaved() async {
    final raw = await _preferences.read(savedKey);
    if (raw == null) return [];
    if (raw.length > _maxBytes || utf8.encode(raw).length > _maxBytes) {
      throw const FormatException('Insight bookmark size');
    }
    final document = jsonDecode(raw);
    if (document is! Map<String, dynamic> ||
        document['schema_version'] != 1 ||
        document['ids'] is! List) {
      throw const FormatException('Insight bookmark document');
    }
    final ids = document['ids'] as List;
    // Known IDs recover without treating deleted or duplicate articles as facts.
    return ids
        .whereType<String>()
        .where((id) => InsightCatalogue.byId(id) != null)
        .toSet()
        .take(InsightCatalogue.articles.length)
        .toList();
  }

  Future<bool> toggleSaved(String id) async {
    if (_disposed || saving || loading || InsightCatalogue.byId(id) == null) {
      return false;
    }
    if (!_canWrite) {
      error = 'Retry reading saved insights before saving, or clear that list to recover.';
      _publish();
      return false;
    }
    saving = true;
    error = null;
    _publish();
    try {
      // Re-read before writing so a separately opened view keeps existing saves.
      final ids = await _readSaved();
      if (!ids.remove(id)) ids.insert(0, id);
      await _preferences.write(
        savedKey,
        jsonEncode({'schema_version': 1, 'ids': ids}),
      );
      if (_disposed) return false;
      _savedIds = ids;
      return true;
    } catch (_) {
      if (!_disposed) {
        error =
            'This insight could not be saved on this device. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        _publish();
      }
    }
  }

  Future<bool> clearSaved() async {
    if (_disposed || saving || loading) return false;
    saving = true;
    _publish();
    try {
      await _preferences.remove(savedKey);
      if (_disposed) return false;
      _savedIds = [];
      _canWrite = true;
      error = null;
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'Saved insights could not be cleared. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        _publish();
      }
    }
  }

  void setTopic(InsightTopic topic) {
    if (_disposed || topic == _selectedTopic) return;
    _selectedTopic = topic;
    _publish();
  }

  /// Call when the app resumes as mobile/browser timers can be suspended.
  void refreshDay() {
    if (_disposed) return;
    final changed = _updateDay();
    if (_started) _scheduleMidnight();
    if (changed) _publish();
  }

  bool _updateDay() {
    final now = _clock().toLocal();
    final day = '${now.year}-${now.month}-${now.day}';
    if (_day == day) return false;
    _day = day;
    _daily = InsightCatalogue.daily(now);
    return true;
  }

  void _scheduleMidnight() {
    _timer?.cancel();
    final now = _clock().toLocal();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(
      midnight.difference(now) + const Duration(seconds: 1),
      refreshDay,
    );
  }

  void clearError() {
    if (_disposed || error == null) return;
    error = null;
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
