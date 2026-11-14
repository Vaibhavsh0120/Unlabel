import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../network/unlabel_repository.dart';
import '../storage/local_store.dart';
import 'reminder_gateway.dart';

class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.destination = 'profile',
  });
  final String id, title, body, destination;
  final DateTime at;
  final bool read;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'published_at': at.toUtc().toIso8601String(),
    'read': read,
    'destination': destination,
  };
  factory InboxEntry.fromJson(Map<String, dynamic> value) {
    final id = value['id'], title = value['title'], body = value['body'];
    final at = DateTime.tryParse(
      value['published_at'] is String ? value['published_at'] as String : '',
    );
    if (id is! String ||
        id.isEmpty ||
        id.length > 100 ||
        title is! String ||
        title.length > 100 ||
        body is! String ||
        body.length > 360 ||
        at == null ||
        !const [
          'profile',
          'insights',
          'scan',
          'saved',
        ].contains(value['destination'])) {
      throw const FormatException('Invalid inbox entry');
    }
    return InboxEntry(
      id: id,
      title: title,
      body: body,
      at: at,
      read: value['read'] == true,
      destination: value['destination'] as String,
    );
  }
  InboxEntry markRead() => InboxEntry(
    id: id,
    title: title,
    body: body,
    at: at,
    destination: destination,
    read: true,
  );
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.preferences,
    required this.repository,
    ReminderGateway? gateway,
    DateTime Function()? clock,
  }) : gateway = gateway ?? createReminderGateway(repository),
       clock = clock ?? DateTime.now;
  static const storageKey = 'unlabel.notifications.v1';
  final PreferencesAdapter preferences;
  final UnlabelRepository repository;
  final ReminderGateway gateway;
  final DateTime Function() clock;
  List<InboxEntry> _entries = [];
  Set<String> _seen = {};
  List<InboxEntry> get entries => List.unmodifiable(_entries);
  int get unread => _entries.where((e) => !e.read).length;
  bool reminderEnabled = false, busy = false, loading = true;
  int hour = 19, minute = 0;
  String? error, feedError;
  bool _disposed = false;
  bool _storageReady = false;
  VoidCallback _onOpen = () {};
  Future<void> _tail = Future.value();
  Future<void>? _refresh;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(VoidCallback onOpen) async {
    _onOpen = onOpen;
    loading = true;
    error = null;
    try {
      final raw = await preferences.read(storageKey);
      if (raw != null) {
        if (raw.length > 64000) throw const FormatException('Oversize inbox');
        final value = jsonDecode(raw) as Map<String, dynamic>;
        final rows = value['entries'] as List;
        if (rows.length > 50) throw const FormatException('Oversize inbox');
        _entries = rows
            .map((row) => InboxEntry.fromJson(row as Map<String, dynamic>))
            .toList();
        _seen = (value['seen'] as List).whereType<String>().take(100).toSet();
        reminderEnabled = value['reminder'] == true;
        hour =
            value['hour'] is int &&
                (value['hour'] as int) >= 0 &&
                (value['hour'] as int) < 24
            ? value['hour'] as int
            : 19;
        minute =
            value['minute'] is int &&
                (value['minute'] as int) >= 0 &&
                (value['minute'] as int) < 60
            ? value['minute'] as int
            : 0;
      }
    } catch (_) {
      error = 'Your inbox could not be read. Retry before changing notification settings.';
      loading = false;
      _notify();
      return;
    }
    _storageReady = true;
    try {
      await gateway.initialize(onOpen);
      if (reminderEnabled && !await gateway.permitted()) {
        error = 'Notification permission was removed. Allow notifications in settings, then enable the reminder again.';
        reminderEnabled = false;
        await gateway.cancel();
        await _persist();
      }
    } catch (_) {
      error = 'Device notifications could not start. Your inbox is still available.';
    }
    loading = false;
    _notify();
    unawaited(refresh());
  }

  Future<void> _persist() async {
    try {
      await preferences.write(
        storageKey,
        jsonEncode({
          'entries': _entries.map((e) => e.toJson()).toList(),
          'seen': _seen.toList(),
          'reminder': reminderEnabled,
          'hour': hour,
          'minute': minute,
        }),
      );
    } catch (_) {
      throw const AppFailure(
        'notification_storage',
        'Your notification changes could not be saved on this device. Please retry.',
      );
    }
  }

  Future<void> _serial(Future<void> Function() operation) {
    final result = _tail.then((_) async {
      if (!_storageReady) {
        throw const AppFailure(
          'notification_storage',
          'Your inbox could not be read. Retry before changing notification settings.',
        );
      }
      if (!_disposed) await operation();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> refresh() => !_storageReady
      ? start(_onOpen)
      : (_refresh ??= _loadFeed().whenComplete(() => _refresh = null));
  Future<void> _loadFeed() async {
    try {
      final items = await repository.notifications();
      final parsed = items.map(InboxEntry.fromJson).toList();
      await _serial(() async {
        final oldEntries = _entries, oldSeen = _seen;
        _entries = [
          ...parsed.where(
            (entry) =>
                !_seen.contains(entry.id) && !entry.at.isAfter(clock().toUtc()),
          ),
          ..._entries,
        ];
        _entries.sort((a, b) => b.at.compareTo(a.at));
        _entries = _entries.take(50).toList();
        _seen = {
          ..._seen,
          ...parsed
              .where((e) => !e.at.isAfter(clock().toUtc()))
              .map((e) => e.id),
        }.toList().reversed.take(100).toList().reversed.toSet();
        try {
          await _persist();
        } catch (_) {
          _entries = oldEntries;
          _seen = oldSeen;
          rethrow;
        }
        feedError = null;
        _notify();
      });
    } catch (_) {
      feedError =
          'App updates could not refresh. Your saved inbox is still available.';
      _notify();
    }
  }

  Future<void> activity({required bool saved}) => _serial(() async {
    if (loading) return;
    final now = clock();
    final entry = InboxEntry(
      id: 'activity-${now.microsecondsSinceEpoch}',
      title: saved ? 'Report saved' : 'Your scan report is ready',
      body: saved
          ? 'Find it in Saved whenever you want to read it again.'
          : 'Review the available facts and their sources in History.',
      destination: saved ? 'saved' : 'scan',
      at: now,
    );
    final old = _entries;
    _entries = [entry, ..._entries].take(50).toList();
    try {
      await _persist();
    } catch (_) {
      _entries = old;
      return;
    }
    _notify();
  });
  Future<void> markRead([String? id]) => _serial(() async {
    final old = _entries;
    _entries = _entries
        .map((e) => id == null || e.id == id ? e.markRead() : e)
        .toList();
    try {
      await _persist();
    } catch (_) {
      _entries = old;
      rethrow;
    }
    _notify();
  });
  Future<void> clear() => _serial(() async {
    final old = _entries;
    _entries = [];
    try {
      await _persist();
    } catch (_) {
      _entries = old;
      rethrow;
    }
    _notify();
  });
  Future<void> setReminder(bool enabled, {int? atHour, int? atMinute}) async {
    if (busy || loading || !_storageReady) return;
    busy = true;
    error = null;
    _notify();
    final oldEnabled = reminderEnabled, oldHour = hour, oldMinute = minute;
    try {
      final nextHour = atHour ?? hour, nextMinute = atMinute ?? minute;
      if (enabled) {
        await gateway.schedule(nextHour, nextMinute);
      } else {
        await gateway.cancel();
      }
      await _serial(() async {
        reminderEnabled = enabled;
        hour = nextHour;
        minute = nextMinute;
        try {
          await _persist();
        } catch (_) {
          reminderEnabled = oldEnabled;
          hour = oldHour;
          minute = oldMinute;
          if (oldEnabled) {
            await gateway.schedule(oldHour, oldMinute);
          } else {
            await gateway.cancel();
          }
          rethrow;
        }
      });
    } on AppFailure catch (failure) {
      error = failure.userMessage;
    } catch (_) {
      error = 'The reminder could not be changed. Please try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> test() async {
    if (busy || !reminderEnabled) return;
    busy = true;
    error = null;
    _notify();
    try {
      await gateway.test();
    } on AppFailure catch (failure) {
      error = failure.userMessage;
    } catch (_) {
      error = 'The test notification could not be sent. Check your notification settings and retry.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    gateway.dispose();
    super.dispose();
  }
}

class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    required NotificationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static NotificationController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>()?.notifier;
}

class NotificationBell extends StatelessWidget {
  const NotificationBell({required this.onPressed, super.key});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final count = NotificationScope.maybeOf(context)?.unread ?? 0;
    return IconButton(
      onPressed: onPressed,
      tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.notifications_none_outlined),
      ),
    );
  }
}
