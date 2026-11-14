import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../network/unlabel_repository.dart';
import 'reminder_gateway.dart';

@JS('unlabelNotifications.supported')
external bool get _supported;
@JS('unlabelNotifications.initialize')
external void _initialize(JSFunction callback);
@JS('unlabelNotifications.permitted')
external JSPromise<JSBoolean> _permitted();
@JS('unlabelNotifications.requestPermission')
external JSPromise<JSBoolean> _requestPermission();
@JS('unlabelNotifications.subscribe')
external JSPromise<JSString> _subscribe(JSString key);
@JS('unlabelNotifications.subscription')
external JSPromise<JSString> _subscription();
@JS('unlabelNotifications.unsubscribe')
external JSPromise<JSAny?> _unsubscribe();

ReminderGateway createGateway(UnlabelRepository repository) =>
    WebReminderGateway(repository);

class WebReminderGateway implements ReminderGateway {
  WebReminderGateway(this.repository);
  final UnlabelRepository repository;
  @override
  bool get supported => _supported;
  @override
  bool get webPush => true;
  @override
  Future<void> initialize(VoidCallback onOpen) async {
    _initialize(onOpen.toJS);
  }

  @override
  Future<bool> permitted() async => (await _permitted().toDart).toDart;
  Future<Map<String, dynamic>> _current() async {
    final value = jsonDecode((await _subscription().toDart).toDart);
    if (value is! Map<String, dynamic>) {
      throw const AppFailure(
        'subscription_missing',
        'Enable the daily reminder first.',
      );
    }
    return value;
  }

  @override
  Future<void> schedule(int hour, int minute) async {
    // Request in the tap gesture before fetching server configuration (Safari).
    if (!(await _requestPermission().toDart).toDart) {
      throw const AppFailure(
        'notification_permission',
        'Allow notifications in your browser settings. On iPhone or iPad, add Unlabel to the Home Screen and open it there first.',
      );
    }
    final config = await repository.notificationPushConfig();
    if (config['available'] != true || config['public_key'] is! String) {
      throw const AppFailure(
        'push_unavailable',
        'The reminder service could not connect. Please try again.',
      );
    }
    try {
      final raw = (await _subscribe(
        (config['public_key'] as String).toJS,
      ).toDart).toDart;
      final subscription = jsonDecode(raw) as Map<String, dynamic>;
      try {
        await repository.notificationSubscription(subscription, enabled: true);
      } catch (_) {
        await _unsubscribe().toDart;
        rethrow;
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'notification_permission',
        'Allow notifications in your browser settings. On iPhone or iPad, add Unlabel to the Home Screen and open it there first.',
      );
    }
  }

  @override
  Future<void> cancel() async {
    final raw = (await _subscription().toDart).toDart;
    final subscription = jsonDecode(raw);
    if (subscription is Map<String, dynamic>) {
      await repository.notificationSubscription(subscription, enabled: false);
    }
    await _unsubscribe().toDart;
  }

  @override
  Future<void> test() async => repository.testNotification(await _current());
  @override
  void dispose() {
    _initialize((() {}).toJS);
  }
}
