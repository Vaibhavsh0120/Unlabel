import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/scanner/domain/insight_catalogue.dart';
import 'package:unlabel/features/scanner/domain/insight_controller.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('Unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failWrite) throw StateError('Unavailable');
    values.remove(key);
  }
}

class _DelayedPreferences extends _Preferences {
  Completer<String?>? pendingRead;

  @override
  Future<String?> read(String key) {
    final pending = pendingRead;
    pendingRead = null;
    return pending?.future ?? super.read(key);
  }
}

class _TimerObservedController extends InsightController {
  _TimerObservedController({required super.preferences, required super.clock});

  int refreshCalls = 0;

  @override
  void refreshDay() {
    refreshCalls++;
    super.refreshDay();
  }
}

void main() {
  test(
    'overlapping read retries share completion before saving is enabled',
    () async {
      final preferences = _DelayedPreferences();
      final controller = InsightController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.start();
      final pending = Completer<String?>();
      preferences.pendingRead = pending;
      final firstRead = controller.reloadSaved();
      var retryFinished = false;
      final retry = controller.reloadSaved().then((_) => retryFinished = true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.loading, isTrue);
      expect(retryFinished, isFalse);
      expect(await controller.toggleSaved('claim-check'), isFalse);
      pending.complete(null);
      await Future.wait([firstRead, retry]);
      expect(controller.loading, isFalse);
      expect(await controller.toggleSaved('claim-check'), isTrue);
      expect(controller.saved.single.id, 'claim-check');
    },
  );

  test('daily selection is stable within a day and contains four topics', () {
    final morning = InsightCatalogue.daily(DateTime(2026, 10, 9, 1));
    final evening = InsightCatalogue.daily(DateTime(2026, 10, 9, 23, 59));
    expect(morning.map((item) => item.id), evening.map((item) => item.id));
    expect(morning, hasLength(4));
    expect(morning.map((item) => item.id).toSet(), hasLength(4));
    expect(morning.map((item) => item.topic).toSet(), hasLength(4));
    expect(
      InsightCatalogue.daily(DateTime(2026, 10, 10)).map((item) => item.id),
      isNot(morning.map((item) => item.id)),
    );
  });

  test('consumers cannot erase the shared daily selection', () {
    final controller = InsightController(preferences: _Preferences());
    addTearDown(controller.dispose);
    expect(() => controller.daily.clear(), throwsUnsupportedError);
    expect(controller.daily, hasLength(4));
  });

  test('synchronous reload listeners join the existing read', () async {
    final preferences = _DelayedPreferences();
    final controller = InsightController(preferences: preferences);
    addTearDown(controller.dispose);
    await controller.start();
    final pending = Completer<String?>();
    preferences.pendingRead = pending;
    Future<void>? joined;
    var requested = false;
    controller.addListener(() {
      if (controller.loading && !requested) {
        requested = true;
        joined = controller.reloadSaved();
      }
    });
    final read = controller.reloadSaved();
    expect(requested, isTrue);
    expect(controller.loading, isTrue);
    pending.complete(null);
    await Future.wait([read, joined!]);
    expect(controller.loading, isFalse);
    expect(await controller.toggleSaved('claim-check'), isTrue);
  });

  test('selection can reach the complete catalogue over successive days', () {
    final selected = <String>{};
    for (var day = 0; day < 365; day++) {
      selected.addAll(
        InsightCatalogue.daily(DateTime(2026, 1, 1 + day))
            .map((item) => item.id),
      );
    }
    expect(selected, hasLength(20));
    expect(
      InsightCatalogue.articles.map((item) => item.asset).toSet(),
      hasLength(20),
    );
    for (final article in InsightCatalogue.articles) {
      expect(article.sections.length, greaterThanOrEqualTo(2));
      expect(article.sources, isNotEmpty);
      expect(
        article.sources.every(
          (source) => Uri.parse(source.url).scheme == 'https',
        ),
        isTrue,
      );
    }
  });

  test(
    'topic browsing includes the full catalogue beyond daily picks',
    () async {
      final controller = InsightController(
        preferences: _Preferences(),
        clock: () => DateTime(2026, 10, 9),
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.visible, hasLength(4));
      controller.setTopic(InsightTopic.sugar);
      expect(controller.visible, hasLength(4));
      expect(
        controller.visible.every((item) => item.topic == InsightTopic.sugar),
        isTrue,
      );
      expect(
        controller.visible.map((item) => item.id),
        contains('added-sugar'),
      );
      controller.setTopic(InsightTopic.all);
      expect(
        controller.visible.map((item) => item.id),
        controller.daily.map((item) => item.id),
      );
    },
  );

  test(
    'date refresh replaces picks once while preserving saved articles',
    () async {
      var now = DateTime(2026, 10, 9, 23, 59);
      final controller = InsightController(
        preferences: _Preferences(),
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.start();
      final yesterday = controller.daily.map((item) => item.id).toList();
      await controller.toggleSaved('added-sugar');
      var notices = 0;
      controller.addListener(() => notices++);
      controller.refreshDay();
      expect(notices, 0);
      now = DateTime(2026, 10, 10, 0, 1);
      controller.refreshDay();
      expect(notices, 1);
      expect(controller.daily.map((item) => item.id), isNot(yesterday));
      expect(controller.saved.single.id, 'added-sugar');
    },
  );

  testWidgets(
    'midnight timer refreshes once, keeps saves and is cancelled on disposal',
    (tester) async {
      var now = DateTime(2026, 10, 9, 23, 59, 59);
      final controller = _TimerObservedController(
        preferences: _Preferences(),
        clock: () => now,
      );
      var notices = 0;
      try {
        await controller.start();
        expect(await controller.toggleSaved('added-sugar'), isTrue);
        final yesterday = controller.daily.map((item) => item.id).toList();
        controller.addListener(() => notices++);

        now = DateTime(2026, 10, 10);
        await tester.pump(const Duration(seconds: 1));
        expect(controller.refreshCalls, 0);
        expect(controller.daily.map((item) => item.id), yesterday);

        now = DateTime(2026, 10, 10, 0, 0, 1);
        await tester.pump(const Duration(seconds: 1));
        expect(controller.refreshCalls, 1);
        expect(notices, 1);
        expect(controller.daily, hasLength(4));
        expect(controller.daily.map((item) => item.id).toSet(), hasLength(4));
        expect(controller.daily.map((item) => item.id), isNot(yesterday));
        expect(controller.saved.single.id, 'added-sugar');

        await tester.pump(const Duration(seconds: 2));
        expect(controller.refreshCalls, 1);
        expect(notices, 1);
      } finally {
        controller.dispose();
      }

      now = DateTime(2026, 10, 12);
      await tester.pump(const Duration(days: 2));
      expect(controller.refreshCalls, 1);
      expect(notices, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'bookmarks survive restart and only touch their device-local key',
    () async {
      final preferences = _Preferences()
        ..values[LocalStore.savedKey] = 'existing-products'
        ..values['unlabel.account.private.example'] = 'existing-account';
      final first = InsightController(preferences: preferences);
      addTearDown(first.dispose);
      await first.start();
      expect(await first.toggleSaved('added-sugar'), isTrue);
      expect(await first.toggleSaved('fibre-foods'), isTrue);
      final restored = InsightController(preferences: preferences);
      addTearDown(restored.dispose);
      await restored.start();
      expect(restored.saved.map((item) => item.id), [
        'fibre-foods',
        'added-sugar',
      ]);
      expect(await restored.toggleSaved('added-sugar'), isTrue);
      expect(restored.isSaved('added-sugar'), isFalse);
      expect(preferences.values[LocalStore.savedKey], 'existing-products');
      expect(
        preferences.values['unlabel.account.private.example'],
        'existing-account',
      );
      final document =
          jsonDecode(preferences.values[InsightController.savedKey]!) as Map;
      expect(document['ids'], ['fibre-foods']);
    },
  );

  test(
    'failed write keeps the visible saved state and permits retry',
    () async {
      final preferences = _Preferences();
      final controller = InsightController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.start();
      preferences.failWrite = true;
      expect(await controller.toggleSaved('claim-check'), isFalse);
      expect(controller.isSaved('claim-check'), isFalse);
      expect(controller.error, isNotNull);
      preferences.failWrite = false;
      expect(await controller.toggleSaved('claim-check'), isTrue);
      expect(controller.isSaved('claim-check'), isTrue);
      expect(controller.error, isNull);
    },
  );

  test(
    'unreadable storage is not silently replaced by a bookmark action',
    () async {
      final preferences = _Preferences()
        ..values[InsightController.savedKey] = '{unreadable';
      final controller = InsightController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.daily, hasLength(4));
      expect(controller.error, isNotNull);
      expect(await controller.toggleSaved('added-sugar'), isFalse);
      expect(preferences.values[InsightController.savedKey], '{unreadable');
      expect(await controller.clearSaved(), isTrue);
      expect(await controller.toggleSaved('added-sugar'), isTrue);
    },
  );

  test(
    'known saved IDs recover once without inventing removed articles',
    () async {
      final preferences = _Preferences()
        ..values[InsightController.savedKey] = jsonEncode({
          'schema_version': 1,
          'ids': [
            'added-sugar',
            'removed-article',
            'added-sugar',
            'claim-check',
          ],
        });
      final controller = InsightController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.saved.map((item) => item.id), [
        'added-sugar',
        'claim-check',
      ]);
      expect(await controller.toggleSaved('unknown'), isFalse);
      expect(controller.saved.map((item) => item.id), [
        'added-sugar',
        'claim-check',
      ]);
    },
  );
}
