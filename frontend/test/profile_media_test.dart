import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/unlabel_theme.dart';
import 'package:unlabel/core/accounts/account_auth.dart';
import 'package:unlabel/core/accounts/profile_media.dart';
import 'package:unlabel/core/models/app_failure.dart';
import 'package:unlabel/core/storage/local_store.dart';
import 'package:unlabel/features/account/presentation/profile_avatar.dart';

class _Preferences implements PreferencesAdapter {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Auth extends UnavailableAccountAuth {
  AccountIdentity? user;
  @override
  AccountIdentity? get identity => user;
  void change(AccountIdentity? value) {
    user = value;
    notifyListeners();
  }
}

class _Repository implements ProfileMediaRepository {
  final streams = <String, StreamController<ProfileMedia>>{};
  final written = <(String, ProfileMedia)>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Stream<ProfileMedia> watch(String uid) =>
      (streams[uid] ??= StreamController<ProfileMedia>.broadcast()).stream;
  void emit(String uid, ProfileMedia value) => streams[uid]!.add(value);
  @override
  Future<void> write(String uid, ProfileMedia value) async {
    if (fail) throw StateError('Synthetic offline response');
    written.add((uid, value));
    await pending?.future;
  }

  Future<void> dispose() async {
    for (final controller in streams.values) {
      await controller.close();
    }
  }
}

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 400, 200),
    Paint()..color = Colors.red,
  );
  canvas.drawRect(
    const Rect.fromLTWH(200, 0, 200, 200),
    Paint()..color = Colors.blue,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 200);
  picture.dispose();
  return image;
}

void main() {
  testWidgets('crop exports the selected region as bounded metadata-free PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final image = await _image();
      addTearDown(image.dispose);
      final bytes = await encodeAvatarCrop(
        image,
        center: const Offset(.75, .5),
      );
      expect(bytes.length, lessThanOrEqualTo(ProfileMedia.maxAvatarBytes));
      ProfileMedia.validateAvatarPng(bytes);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pixel = await frame.image.toByteData();
      expect(frame.image.width, 192);
      expect(frame.image.height, 192);
      expect(
        pixel!.getUint8(2),
        243,
      ); // Selected blue half, rather than center.
      frame.image.dispose();
      codec.dispose();
      final chunks = <String>[];
      final data = ByteData.sublistView(bytes);
      var offset = 8;
      while (offset + 12 <= bytes.length) {
        chunks.add(String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)));
        offset += data.getUint32(offset) + 12;
      }
      expect(chunks, isNot(contains('eXIf')));
      expect(chunks, isNot(contains('tEXt')));
      expect(chunks, isNot(contains('iTXt')));
      expect(
        avatarCropRect(image, center: const Offset(9, -9), zoom: 4),
        const Rect.fromLTWH(350, 0, 50, 50),
      );
    });
  });

  testWidgets(
    'noisy photo remains a 192px thumbnail below the private byte cap',
    (tester) async {
      await tester.runAsync(() async {
        final random = math.Random(42);
        final pixels = Uint8List(192 * 192 * 4);
        for (var index = 0; index < pixels.length; index++) {
          pixels[index] = random.nextInt(256);
        }
        final decoded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          192,
          192,
          ui.PixelFormat.rgba8888,
          decoded.complete,
        );
        final image = await decoded.future;
        try {
          final bytes = await encodeAvatarCrop(image);
          ProfileMedia.validateAvatarPng(bytes);
          expect(bytes.length, lessThanOrEqualTo(ProfileMedia.maxAvatarBytes));
        } finally {
          image.dispose();
        }
      });
    },
  );

  test(
    'guest gender/source stays local; custom photo requires account',
    () async {
      final auth = _Auth();
      final preferences = _Preferences();
      final repository = _Repository();
      final media = ProfileMediaController(
        auth: auth,
        preferences: preferences,
        repository: repository,
      );
      addTearDown(() {
        media.dispose();
        auth.dispose();
        return repository.dispose();
      });
      await media.start();
      await media.updateGender(ProfileGender.female);
      await media.useDefaultAvatar();
      final stored = jsonDecode(
        preferences.values[ProfileMediaController.guestKey]!,
      );
      expect(stored, {'gender': 'female', 'source': 'defaultAvatar'});
      expect(repository.written, isEmpty);
      await expectLater(
        media.saveCustomPhoto(Uint8List(0)),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  testWidgets(
    'same UID gender preserves custom photo; removing it restores automatic fallback',
    (tester) async {
      final auth = _Auth()
        ..user = const AccountIdentity(
          uid: 'owner-a',
          photoUrl: 'https://lh3.googleusercontent.com/synthetic',
        );
      final repository = _Repository();
      final media = ProfileMediaController(
        auth: auth,
        preferences: _Preferences(),
        repository: repository,
      );
      addTearDown(() {
        media.dispose();
        auth.dispose();
        return repository.dispose();
      });
      await media.start();
      repository.emit('owner-a', ProfileMedia());
      await tester.pump();
      final png = (await tester.runAsync(() async {
        final image = await _image();
        final encoded = await encodeAvatarCrop(image);
        image.dispose();
        return encoded;
      }))!;
      await media.saveCustomPhoto(png);
      await media.updateGender(ProfileGender.male);
      expect(media.value.avatarPng, orderedEquals(png));
      expect(media.value.gender, ProfileGender.male);
      await media.removeCustomPhoto();
      expect(media.value.avatarPng, isNull);
      expect(media.value.source, ProfileAvatarSource.automatic);
      expect(media.value.gender, ProfileGender.male);
      expect(repository.written.last.$1, 'owner-a');
      expect(repository.written.last.$2.avatarPng, isNull);
    },
  );

  test(
    'failed initial read cannot overwrite an existing private profile',
    () async {
      final auth = _Auth()..user = const AccountIdentity(uid: 'owner-a');
      final repository = _Repository();
      final media = ProfileMediaController(
        auth: auth,
        preferences: _Preferences(),
        repository: repository,
      );
      addTearDown(() {
        media.dispose();
        auth.dispose();
        return repository.dispose();
      });
      await media.start();
      await expectLater(
        media.updateGender(ProfileGender.female),
        throwsA(isA<AppFailure>()),
      );
      expect(repository.written, isEmpty);
    },
  );

  testWidgets('old owner completion never paints over the new owner', (
    tester,
  ) async {
    final auth = _Auth()..user = const AccountIdentity(uid: 'owner-a');
    final repository = _Repository();
    final media = ProfileMediaController(
      auth: auth,
      preferences: _Preferences(),
      repository: repository,
    );
    addTearDown(() {
      media.dispose();
      auth.dispose();
      return repository.dispose();
    });
    await media.start();
    repository.emit('owner-a', ProfileMedia(gender: ProfileGender.male));
    await tester.pump();
    repository.pending = Completer<void>();
    final writing = media.updateGender(ProfileGender.female);
    final assertion = expectLater(writing, throwsA(isA<AppFailure>()));
    auth.change(const AccountIdentity(uid: 'owner-b'));
    repository.emit(
      'owner-b',
      ProfileMedia(
        gender: ProfileGender.male,
        source: ProfileAvatarSource.defaultAvatar,
      ),
    );
    await tester.pump();
    expect(media.value.gender, ProfileGender.male);
    repository.pending!.complete();
    await assertion;
    expect(media.ownerUid, 'owner-b');
    expect(media.value.gender, ProfileGender.male);
    expect(media.value.source, ProfileAvatarSource.defaultAvatar);
  });

  test(
    'Google photo URL refuses lookalike, insecure and credentialed hosts',
    () {
      expect(
        safeGooglePhotoUrl('https://lh3.googleusercontent.com/a/s96-c'),
        isNotNull,
      );
      for (final url in [
        'http://lh3.googleusercontent.com/a',
        'https://googleusercontent.com.evil.invalid/a',
        'https://evilgoogleusercontent.com/a',
        'https://person@lh3.googleusercontent.com/a',
        'https://lh3.googleusercontent.com:444/a',
        'data:image/png;base64,AAA',
      ]) {
        expect(safeGooglePhotoUrl(url), isNull, reason: url);
      }
    },
  );

  testWidgets(
    'timed-out writes are not replayed and failed writes preserve photo choice',
    (tester) async {
      final auth = _Auth()..user = const AccountIdentity(uid: 'owner-a');
      final repository = _Repository();
      final media = ProfileMediaController(
        auth: auth,
        preferences: _Preferences(),
        repository: repository,
      );
      addTearDown(() {
        media.dispose();
        auth.dispose();
        return repository.dispose();
      });
      await media.start();
      repository.emit('owner-a', ProfileMedia(gender: ProfileGender.male));
      await tester.pump();
      repository.pending = Completer<void>();
      final operation = media.updateGender(ProfileGender.female);
      final assertion = expectLater(operation, throwsA(isA<AppFailure>()));
      await tester.pump(ProfileMediaController.operationTimeout);
      await assertion;
      expect(media.busy, isTrue);
      await expectLater(media.useDefaultAvatar(), throwsA(isA<AppFailure>()));
      expect(repository.written.length, 1);
      repository.pending!.complete();
      await tester.pump();
      expect(media.busy, isFalse);
      expect(media.value.gender, ProfileGender.female);
      expect(media.error, isNull);
      repository.fail = true;
      await expectLater(
        media.updateGender(ProfileGender.male),
        throwsA(isA<AppFailure>()),
      );
      expect(media.value.gender, ProfileGender.female);
    },
  );

  testWidgets(
    'default artwork follows explicit gender without assigning an unset gender',
    (tester) async {
      final auth = _Auth();
      final preferences = _Preferences();
      final media = ProfileMediaController(
        auth: auth,
        preferences: preferences,
      );
      addTearDown(() {
        media.dispose();
        auth.dispose();
      });
      await media.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountAvatar(media: media)),
        ),
      );
      String assetName() {
        final provider = tester.widget<Image>(find.byType(Image)).image;
        final asset = provider is ResizeImage
            ? provider.imageProvider
            : provider;
        return (asset as AssetImage).assetName;
      }

      expect(assetName(), 'assets/artwork/profile-avatar.webp');
      expect(media.value.gender, ProfileGender.unspecified);
      expect(preferences.values, isEmpty);
      await media.updateGender(ProfileGender.female);
      await tester.pump();
      expect(assetName(), 'assets/artwork/profile-avatar-female.webp');
      await media.updateGender(ProfileGender.male);
      await tester.pump();
      expect(assetName(), 'assets/artwork/profile-avatar.webp');
      await media.updateGender(ProfileGender.unspecified);
      await tester.pump();
      expect(assetName(), 'assets/artwork/profile-avatar.webp');
      expect(media.value.gender, ProfileGender.unspecified);
    },
  );

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('photo window actions remain reachable $width $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth();
        final media = ProfileMediaController(
          auth: auth,
          preferences: _Preferences(),
        );
        await media.start();
        addTearDown(() {
          media.dispose();
          auth.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: UnlabelTheme.forBrightness(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      ProfilePhotoEditor.show(context, media: media),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('profile-photo-window')),
          findsOneWidget,
        );
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(700));
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-photo-window')),
          findsNothing,
        );
      });
    }
  }
}
