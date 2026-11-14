import 'package:flutter/foundation.dart';

import '../network/unlabel_repository.dart';
import 'reminder_native.dart'
    if (dart.library.js_interop) 'reminder_web.dart'
    as platform;

abstract interface class ReminderGateway {
  bool get supported;
  bool get webPush;
  Future<void> initialize(VoidCallback onOpen);
  Future<bool> permitted();
  Future<void> schedule(int hour, int minute);
  Future<void> cancel();
  Future<void> test();
  void dispose();
}

ReminderGateway createReminderGateway(UnlabelRepository repository) =>
    platform.createGateway(repository);
