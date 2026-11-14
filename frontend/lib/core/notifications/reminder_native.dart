import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../network/unlabel_repository.dart';
import 'reminder_gateway.dart';

ReminderGateway createGateway(UnlabelRepository _) => NativeReminderGateway();

class NativeReminderGateway implements ReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _reminderId = 7001;
  bool _initialized = false;
  @override
  bool get supported =>
      !kIsWeb &&
      const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  @override
  bool get webPush => false;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'label_reading_reminder',
      'Label-reading reminder',
      channelDescription:
          'Your optional daily reminder to read a package label.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );
  @override
  Future<void> initialize(VoidCallback onOpen) async {
    if (!supported || _initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onOpen(),
    );
    _initialized = true;
    if ((await _plugin.getNotificationAppLaunchDetails())
            ?.didNotificationLaunchApp ==
        true) {
      onOpen();
    }
  }

  @override
  Future<bool> permitted() async {
    if (!supported || !_initialized) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    return (await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  Future<bool> _request() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
  }

  @override
  Future<void> schedule(int hour, int minute) async {
    if (!supported || !_initialized) {
      throw const AppFailure(
        'reminder_unavailable',
        'Reminders are unavailable on this device.',
      );
    }
    if (!await _request()) {
      throw const AppFailure(
        'notification_permission',
        'Notifications are blocked. Allow Unlabel notifications in your device settings, then try again.',
      );
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(zone.identifier);
    final now = tz.TZDateTime.now(location);
    var next = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Take a closer look at a label',
      body: 'Compare the stated amounts and check the ingredients on your next package.',
      scheduledDate: next,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'notifications',
    );
  }

  @override
  Future<void> cancel() async {
    if (_initialized) await _plugin.cancel(id: _reminderId);
  }

  @override
  Future<void> test() async {
    if (!await permitted()) {
      throw const AppFailure(
        'notification_permission',
        'Allow notifications in your device settings first.',
      );
    }
    await _plugin.show(
      id: 7002,
      title: 'Notifications are connected',
      body: 'Your device received this test from Unlabel.',
      notificationDetails: _details,
      payload: 'notifications',
    );
  }

  @override
  void dispose() {}
}
