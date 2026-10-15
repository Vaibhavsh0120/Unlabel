import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/core/capture/live_camera.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);
const _rear = CameraDescription(
  name: 'rear',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

class _Session implements LiveCameraSession, LiveCameraControls {
  final notifier = ChangeNotifier();
  Completer<void>? initialization;
  Completer<XFile>? photograph;
  Object? initializationError;
  Object? captureError;
  XFile photo = XFile.fromData(Uint8List.fromList([1, 2, 3]));
  int initializeCount = 0;
  int captureCount = 0;
  int disposeCount = 0;
  bool failed = false;
  final torchChanges = <bool>[];
  bool torchUnsupported = false;

  @override
  Future<void> setTorch(bool enabled) async {
    if (torchUnsupported) throw CameraException('unsupported', 'detail');
    torchChanges.add(enabled);
  }

  @override
  Listenable get changes => notifier;
  @override
  bool get hasError => failed;
  @override
  double get aspectRatio => 4 / 3;

  @override
  Future<void> initialize() async {
    initializeCount++;
    if (initialization != null) await initialization!.future;
    if (initializationError case final error?) throw error;
  }

  @override
  Future<XFile> takePicture() async {
    captureCount++;
    if (captureError case final error?) throw error;
    return photograph?.future ?? photo;
  }

  @override
  Widget buildPreview() => const SizedBox(key: Key('live-preview'));

  @override
  Future<void> dispose() async {
    disposeCount++;
    notifier.dispose();
  }

  void disconnect() {
    failed = true;
    notifier.notifyListeners();
  }
}

class _Platform implements LiveCameraPlatform {
  _Platform(this.sessions);

  final List<_Session> sessions;
  List<CameraDescription> cameras = [_front, _rear];
  final selected = <CameraDescription>[];
  final audio = <bool>[];
  int enumerateCount = 0;
  bool supported = true;

  @override
  bool get isSupported => supported;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    enumerateCount++;
    return cameras;
  }

  @override
  LiveCameraSession createSession(
    CameraDescription description, {
    required bool enableAudio,
  }) {
    selected.add(description);
    audio.add(enableAudio);
    return sessions[selected.length - 1];
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'switching releases the old lens and remembers the chosen lens',
    () async {
      final rear = _Session(), front = _Session(), resumed = _Session();
      final platform = _Platform([rear, front, resumed]);
      final camera = LiveCamera(platform: platform);
      await camera.start();
      expect(camera.canSwitchCamera, isTrue);
      await camera.switchCamera();
      expect(rear.disposeCount, 1);
      expect(platform.selected, [_rear, _front]);
      await camera.stop();
      await camera.start();
      expect(platform.selected.last, _front);
      await camera.stop();
      camera.dispose();
    },
  );

  test('torch toggles and unsupported hardware leaves camera usable', () async {
    final session = _Session();
    final camera = LiveCamera(platform: _Platform([session]));
    await camera.start();
    expect(camera.canToggleTorch, isTrue);
    await camera.toggleTorch();
    expect(camera.torchOn, isTrue);
    await camera.toggleTorch();
    expect(session.torchChanges, [true, false]);
    session.torchUnsupported = true;
    await camera.toggleTorch();
    expect(camera.canToggleTorch, isFalse);
    expect(camera.ready, isTrue);
    expect(camera.error, contains('Flash is unavailable'));
    await camera.stop();
    expect(camera.torchOn, isFalse);
    camera.dispose();
  });

  test(
    'rear camera is preferred, audio disabled and repeated start coalesced',
    () async {
      final session = _Session()..initialization = Completer<void>();
      final platform = _Platform([session]);
      final camera = LiveCamera(platform: platform);
      final first = camera.start();
      final duplicate = camera.start();
      expect(identical(first, duplicate), isTrue);
      await _flush();
      expect(camera.busy, isTrue);
      expect(camera.ready, isFalse);
      expect(platform.selected, [_rear]);
      expect(platform.audio, [false]);
      session.initialization!.complete();
      await first;
      expect(camera.ready, isTrue);
      expect(camera.busy, isFalse);
      expect(camera.aspectRatio, 4 / 3);
      await camera.start();
      expect(session.initializeCount, 1);
      await camera.stop();
      camera.dispose();
    },
  );

  test('front camera works when a rear camera is unavailable', () async {
    final platform = _Platform([_Session()])..cameras = [_front];
    final camera = LiveCamera(platform: platform);
    await camera.start();
    expect(camera.ready, isTrue);
    expect(platform.selected, [_front]);
    await camera.stop();
    camera.dispose();
  });

  test('unsupported hosts do not enumerate devices', () async {
    final platform = _Platform([])..supported = false;
    final camera = LiveCamera(platform: platform);
    await camera.start();
    expect(camera.ready, isFalse);
    expect(camera.busy, isFalse);
    expect(camera.error, contains('supported web browsers'));
    expect(platform.enumerateCount, 0);
    camera.dispose();
  });

  test('no-camera state can be retried after connecting a device', () async {
    final platform = _Platform([_Session()])..cameras = [];
    final camera = LiveCamera(platform: platform);
    await camera.start();
    expect(camera.error, contains('No camera'));
    platform.cameras = [_rear];
    await camera.start();
    expect(camera.ready, isTrue);
    expect(camera.error, isNull);
    await camera.stop();
    camera.dispose();
  });

  for (final code in [
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
    'cameraPermission',
    'NotAllowedError',
  ]) {
    test(
      'permission $code is actionable and does not expose plugin details',
      () async {
        final failed = _Session()
          ..initializationError = CameraException(
            code,
            'private-native-detail',
          );
        final replacement = _Session();
        final camera = LiveCamera(platform: _Platform([failed, replacement]));
        await camera.start();
        expect(camera.ready, isFalse);
        expect(camera.busy, isFalse);
        expect(camera.error, isNot(contains('private-native-detail')));
        expect(
          camera.error,
          anyOf(
            contains('settings'),
            contains('Settings'),
            contains('restricted'),
          ),
        );
        expect(failed.disposeCount, 1);
        await camera.start();
        expect(camera.ready, isTrue);
        expect(camera.error, isNull);
        await camera.stop();
        camera.dispose();
      },
    );
  }

  test(
    'stopping during permission initialization discards the late session',
    () async {
      final session = _Session()..initialization = Completer<void>();
      final camera = LiveCamera(platform: _Platform([session]));
      final starting = camera.start();
      await _flush();
      final stopping = camera.stop();
      expect(camera.ready, isFalse);
      expect(camera.busy, isFalse);
      session.initialization!.complete();
      await Future.wait([starting, stopping]);
      expect(camera.ready, isFalse);
      expect(camera.error, isNull);
      expect(session.disposeCount, 1);
      camera.dispose();
    },
  );

  test(
    'stop then start waits for old session disposal before restarting',
    () async {
      final first = _Session()..initialization = Completer<void>();
      final second = _Session();
      final camera = LiveCamera(platform: _Platform([first, second]));
      final initialStart = camera.start();
      await _flush();
      final stopping = camera.stop();
      final newStart = camera.start();
      first.initialization!.complete();
      await Future.wait([initialStart, stopping, newStart]);
      expect(first.disposeCount, 1);
      expect(second.initializeCount, 1);
      expect(second.disposeCount, 0);
      expect(camera.ready, isTrue);
      await camera.stop();
      expect(second.disposeCount, 1);
      camera.dispose();
    },
  );

  test(
    'dispose during initialization releases late completion without notifying',
    () async {
      final session = _Session()..initialization = Completer<void>();
      final camera = LiveCamera(platform: _Platform([session]));
      var notifications = 0;
      camera.addListener(() => notifications++);
      final starting = camera.start();
      await _flush();
      camera.dispose();
      final countAtDisposal = notifications;
      session.initialization!.complete();
      await starting;
      await _flush();
      expect(camera.ready, isFalse);
      expect(session.disposeCount, 1);
      expect(notifications, countAtDisposal);
    },
  );

  test(
    'capture returns local bytes and suppresses overlapping captures',
    () async {
      final session = _Session()..photograph = Completer<XFile>();
      final camera = LiveCamera(platform: _Platform([session]));
      await camera.start();
      final capture = camera.capture();
      expect(camera.busy, isTrue);
      await expectLater(camera.capture(), throwsA(isA<LiveCameraException>()));
      await _flush();
      expect(session.captureCount, 1);
      session.photograph!.complete(session.photo);
      expect(await capture, [1, 2, 3]);
      expect(camera.busy, isFalse);
      expect(camera.ready, isTrue);
      await camera.stop();
      camera.dispose();
    },
  );

  test(
    'leaving during capture drops the photo and releases the camera',
    () async {
      final session = _Session()..photograph = Completer<XFile>();
      final camera = LiveCamera(platform: _Platform([session]));
      await camera.start();
      final capture = camera.capture();
      final cancelled = expectLater(
        capture,
        throwsA(
          isA<LiveCameraException>().having(
            (error) => error.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
      await _flush();
      final stopping = camera.stop();
      session.photograph!.complete(session.photo);
      await cancelled;
      await stopping;
      expect(camera.ready, isFalse);
      expect(session.disposeCount, 1);
      camera.dispose();
    },
  );

  test('capture failures are sanitized and permit another capture', () async {
    final session = _Session()
      ..captureError = CameraException('unknown', 'private-photo-path');
    final camera = LiveCamera(platform: _Platform([session]));
    await camera.start();
    await expectLater(camera.capture(), throwsA(isA<LiveCameraException>()));
    expect(camera.error, isNot(contains('private-photo-path')));
    expect(camera.busy, isFalse);
    expect(camera.ready, isTrue);
    session.captureError = null;
    expect(await camera.capture(), [1, 2, 3]);
    expect(camera.error, isNull);
    await camera.stop();
    camera.dispose();
  });

  test('empty or oversized captured images are rejected before use', () async {
    final session = _Session()..photo = XFile.fromData(Uint8List(0));
    final camera = LiveCamera(platform: _Platform([session]));
    await camera.start();
    await expectLater(camera.capture(), throwsA(isA<LiveCameraException>()));
    session.photo = XFile.fromData(Uint8List(LiveCamera.maxCaptureBytes + 1));
    await expectLater(camera.capture(), throwsA(isA<LiveCameraException>()));
    expect(camera.error, contains('12 MB'));
    await camera.stop();
    camera.dispose();
  });

  test('runtime camera disconnect clears preview and can be retried', () async {
    final first = _Session();
    final second = _Session();
    final camera = LiveCamera(platform: _Platform([first, second]));
    await camera.start();
    first.disconnect();
    expect(camera.ready, isFalse);
    expect(camera.error, contains('interrupted'));
    await camera.start();
    expect(first.disposeCount, 1);
    expect(camera.ready, isTrue);
    await camera.stop();
    camera.dispose();
  });

  testWidgets('preview contains the live session only while ready', (
    tester,
  ) async {
    final camera = LiveCamera(platform: _Platform([_Session()]));
    await tester.pumpWidget(camera.buildPreview());
    expect(find.byKey(const Key('live-preview')), findsNothing);
    await camera.start();
    await tester.pumpWidget(camera.buildPreview());
    expect(find.byKey(const Key('live-preview')), findsOneWidget);
    await camera.stop();
    await tester.pumpWidget(camera.buildPreview());
    expect(find.byKey(const Key('live-preview')), findsNothing);
    camera.dispose();
  });
}
