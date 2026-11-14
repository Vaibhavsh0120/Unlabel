import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/notifications/notification_controller.dart';
import 'package:unlabel/core/notifications/reminder_gateway.dart';
import 'package:unlabel/core/network/unlabel_repository.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/notifications_page.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('disk');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Repository extends UnlabelRepository {
  _Repository() : super(baseUrl: 'https://example.invalid');
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> notifications() async {
    if (fail) throw const AppFailure('network', 'offline');
    return [
      {
        'id': 'update-1',
        'title': 'App update',
        'body': 'Your inbox is ready.',
        'published_at': '2026-11-01T00:00:00Z',
        'destination': 'profile',
      },
    ];
  }
}

class _Gateway implements ReminderGateway {
  int schedules = 0, cancellations = 0, tests = 0;
  bool denied = false, enabled = false;
  @override
  bool get supported => true;
  @override
  bool get webPush => false;
  @override
  Future<void> initialize(VoidCallback onOpen) async {}
  @override
  Future<bool> permitted() async => enabled;
  @override
  Future<void> schedule(int hour, int minute) async {
    if (denied) throw const AppFailure('permission', 'Permission denied');
    schedules++;
    enabled = true;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    enabled = false;
  }

  @override
  Future<void> test() async {
    tests++;
  }

  @override
  void dispose() {}
}

void main() {
  test('inbox persists reads, deduplicates updates and keeps cleared messages cleared offline', () async {
    final preferences = _Preferences(),
        repository = _Repository(),
        gateway = _Gateway();
    addTearDown(repository.close);
    final c = NotificationController(
      preferences: preferences,
      repository: repository,
      gateway: gateway,
    );
    await c.start(() {});
    await c.refresh();
    expect(c.entries, hasLength(1));
    expect(c.unread, 1);
    await c.markRead();
    expect(c.unread, 0);
    await c.refresh();
    expect(c.entries, hasLength(1));
    await c.clear();
    await c.refresh();
    expect(c.entries, isEmpty);
    await c.activity(saved: true);
    expect(c.entries.single.title, 'Report saved');
    expect(
      jsonDecode(
        preferences.values[NotificationController.storageKey]!,
      )['entries'][0]['body'],
      isNot(contains('barcode')),
    );
    c.dispose();
    repository.fail = true;
    final restored = NotificationController(
      preferences: preferences,
      repository: repository,
      gateway: gateway,
    );
    await restored.start(() {});
    await restored.refresh();
    expect(restored.entries.single.title, 'Report saved');
    expect(restored.feedError, isNotNull);
    expect(gateway.schedules, 0);
    restored.dispose();
  });
  test('permission denial stays off; enable schedules; unsubscribe cancels; failed persistence rolls back', () async {
    final preferences = _Preferences(),
        repository = _Repository(),
        gateway = _Gateway();
    addTearDown(repository.close);
    final c = NotificationController(
      preferences: preferences,
      repository: repository,
      gateway: gateway,
    );
    await c.start(() {});
    await c.refresh();
    gateway.denied = true;
    await c.setReminder(true);
    expect(c.reminderEnabled, false);
    expect(c.error, 'Permission denied');
    gateway.denied = false;
    await c.setReminder(true, atHour: 20, atMinute: 30);
    expect(c.reminderEnabled, true);
    expect(c.hour, 20);
    expect(gateway.schedules, 1);
    await c.test();
    expect(gateway.tests, 1);
    await c.setReminder(false);
    expect(c.reminderEnabled, false);
    expect(gateway.cancellations, 1);
    preferences.fail = true;
    await c.setReminder(true);
    expect(c.reminderEnabled, false);
    expect(gateway.enabled, false);
    expect(c.error, isNotNull);
    c.dispose();
  });
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(834, 1194),
    const Size(1194, 834),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'notifications fit $size with enlarged text and a working unsubscribe action',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository(), gateway = _Gateway();
        addTearDown(repository.close);
        final c = NotificationController(
          preferences: _Preferences(),
          repository: repository,
          gateway: gateway,
        );
        addTearDown(c.dispose);
        await c.start(() {});
        await c.refresh();
        await c.setReminder(true);
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(Brightness.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: NotificationsPage(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final unsubscribe = find.text('Unsubscribe from reminders');
        await tester.ensureVisible(unsubscribe);
        await tester.pumpAndSettle();
        await tester.tap(unsubscribe);
        await tester.pumpAndSettle();
        expect(gateway.cancellations, 1);
        expect(c.reminderEnabled, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
