import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_failure.dart';
import '../storage/local_store.dart';
import 'account_auth.dart';

enum ProfileGender {
  unspecified('Prefer not to say'),
  male('Male'),
  female('Female');

  const ProfileGender(this.label);
  final String label;
}

enum ProfileAvatarSource { automatic, custom, google, defaultAvatar }

/// A private profile thumbnail, deliberately separate from label photos, dietary
/// preferences and the existing account-library sync contract.
class ProfileMedia {
  ProfileMedia({
    this.gender = ProfileGender.unspecified,
    this.source = ProfileAvatarSource.automatic,
    Uint8List? avatarPng,
  }) : avatarPng = avatarPng == null
           ? null
           : Uint8List.fromList(avatarPng).asUnmodifiableView() {
    if ((source == ProfileAvatarSource.custom) != (avatarPng != null)) {
      throw const FormatException('Invalid profile photo selection');
    }
    if (avatarPng != null) validateAvatarPng(avatarPng);
  }

  static const maxAvatarBytes = 96 * 1024;
  static const avatarEdge = 192;
  final ProfileGender gender;
  final ProfileAvatarSource source;
  final Uint8List? avatarPng;

  ProfileMedia withGender(ProfileGender value) =>
      ProfileMedia(gender: value, source: source, avatarPng: avatarPng);

  Map<String, Object> get deviceJson => {
    'gender': gender.name,
    // Guests never persist a photo or a provider identity on this device.
    'source': source == ProfileAvatarSource.defaultAvatar
        ? ProfileAvatarSource.defaultAvatar.name
        : ProfileAvatarSource.automatic.name,
  };

  factory ProfileMedia.fromMap(Map<String, dynamic> value) {
    final gender = ProfileGender.values.byName(value['gender'] as String);
    final source = ProfileAvatarSource.values.byName(value['source'] as String);
    final photo = value['avatar_png'];
    return ProfileMedia(
      gender: gender,
      source: source,
      avatarPng: photo == null
          ? null
          : photo is Blob
          ? photo.bytes
          : throw const FormatException('Invalid profile thumbnail'),
    );
  }

  static void validateAvatarPng(Uint8List value) {
    if (value.length < 24 || value.length > maxAvatarBytes) {
      throw const FormatException('Invalid profile thumbnail size');
    }
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var index = 0; index < signature.length; index++) {
      if (value[index] != signature[index]) {
        throw const FormatException('Profile thumbnail must be PNG');
      }
    }
    final header = ByteData.sublistView(value);
    if (String.fromCharCodes(value.sublist(12, 16)) != 'IHDR' ||
        header.getUint32(16) != avatarEdge ||
        header.getUint32(20) != avatarEdge) {
      throw const FormatException('Invalid profile thumbnail dimensions');
    }
  }
}

abstract interface class ProfileMediaRepository {
  Stream<ProfileMedia> watch(String uid);
  Future<void> write(String uid, ProfileMedia value);
}

class FirebaseProfileMediaRepository implements ProfileMediaRepository {
  FirebaseProfileMediaRepository({required this.options});
  final FirebaseOptions options;
  static const databaseId = 'unlabel';
  static const collection = 'profile_media';
  FirebaseFirestore? _firestore;

  Future<FirebaseFirestore> _database(String uid) async {
    final auth = await resolveAccountFirebaseAuth(options);
    if (auth.currentUser?.uid != uid ||
        auth.currentUser?.isAnonymous != false) {
      throw const AppFailure(
        'account_changed',
        'Your account changed. Reopen your profile before changing its photo.',
      );
    }
    final existing = _firestore;
    if (existing != null) return existing;
    final database = FirebaseFirestore.instanceFor(
      app: auth.app,
      databaseId: databaseId,
    )..settings = const Settings(persistenceEnabled: false);
    return _firestore = database;
  }

  @override
  Stream<ProfileMedia> watch(String uid) async* {
    final database = await _database(uid);
    yield* database
        .collection(collection)
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        // An empty SDK cache does not prove this owner has no cloud photo.
        .where((snapshot) => !snapshot.metadata.isFromCache)
        .map((snapshot) {
          final value = snapshot.data();
          return value == null ? ProfileMedia() : ProfileMedia.fromMap(value);
        });
  }

  @override
  Future<void> write(String uid, ProfileMedia value) async {
    final database = await _database(uid);
    final reference = database.collection(collection).doc(uid);
    // Transactions require a connection. A photo is never silently queued for a
    // later sign-in session by Firestore's offline write queue.
    await database.runTransaction((transaction) async {
      await _database(uid);
      await transaction.get(reference);
      transaction.set(reference, {
        'schema': 1,
        'gender': value.gender.name,
        'source': value.source.name,
        'updated_at': FieldValue.serverTimestamp(),
        if (value.avatarPng != null) ...{
          'avatar_png': Blob(value.avatarPng!),
          'content_type': 'image/png',
        },
      });
    }, maxAttempts: 1);
  }
}

class ProfileMediaController extends ChangeNotifier {
  ProfileMediaController({
    required this.auth,
    required this.preferences,
    this.repository,
  });

  final AccountAuth auth;
  final PreferencesAdapter preferences;
  final ProfileMediaRepository? repository;
  static const guestKey = 'unlabel.client.v1.guestProfileMedia';
  static const operationTimeout = Duration(seconds: 15);
  ProfileMedia value = ProfileMedia();
  bool loading = false;
  bool busy = false;
  String? error;
  String? get ownerUid => _uid;
  AccountIdentity? get identity => auth.identity;
  StreamSubscription<ProfileMedia>? _subscription;
  String? _uid;
  int _generation = 0;
  bool _started = false;
  bool _disposed = false;
  Future<void>? _operation;
  String? _operationUid;
  bool _ready = false;
  Timer? _restoreTimer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    auth.addListener(_identityChanged);
    await _selectOwner();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void _identityChanged() {
    if (auth.identity?.uid != _uid) unawaited(_selectOwner());
    // Same-UID provider/profile refreshes also update the rendered avatar.
    _publish();
  }

  bool _current(int generation, String? uid) =>
      !_disposed &&
      generation == _generation &&
      uid == _uid &&
      uid == auth.identity?.uid;

  Future<void> _selectOwner() async {
    final generation = ++_generation;
    final uid = _uid = auth.identity?.uid;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _restoreTimer?.cancel();
    value = ProfileMedia();
    _ready = false;
    error = null;
    loading = true;
    _publish();
    if (uid == null) {
      try {
        final encoded = await preferences.read(guestKey);
        if (!_current(generation, uid)) return;
        if (encoded != null && encoded.length < 256) {
          final json = jsonDecode(encoded);
          if (json is Map<String, dynamic>) value = ProfileMedia.fromMap(json);
        }
      } catch (_) {
        // Corrupt guest appearance falls back without exposing other accounts.
      }
      if (_current(generation, uid)) {
        _ready = true;
        loading = false;
        _publish();
      }
      return;
    }
    if (repository == null) {
      loading = false;
      _publish();
      return;
    }
    _restoreTimer = Timer(operationTimeout, () {
      if (!_current(generation, uid) || _ready) return;
      loading = false;
      error = 'Your profile photo could not connect. Check your connection and retry.';
      _publish();
    });
    _subscription = repository!
        .watch(uid)
        .listen(
          (next) {
            if (!_current(generation, uid)) return;
            // Keep an explicitly submitted preview stable until its transaction is
            // confirmed; a stale initial snapshot cannot replace it mid-save.
            if (!busy || _operationUid != uid) value = next;
            _ready = true;
            _restoreTimer?.cancel();
            loading = false;
            error = null;
            _publish();
          },
          onError: (Object _) {
            if (!_current(generation, uid)) return;
            _restoreTimer?.cancel();
            loading = false;
            error = 'Your profile photo could not connect. Try again later.';
            _publish();
          },
        );
  }

  Future<void> updateGender(ProfileGender gender) =>
      _write(value.withGender(gender));

  Future<void> refresh() => _selectOwner();

  Future<void> useDefaultAvatar() => _write(
    ProfileMedia(
      gender: value.gender,
      source: ProfileAvatarSource.defaultAvatar,
    ),
  );

  Future<void> useGooglePhoto() async {
    if (auth.identity?.photoUrl == null) {
      throw const AppFailure(
        'google_photo_unavailable',
        'Connect a Google account with a profile photo first.',
      );
    }
    await _write(
      ProfileMedia(gender: value.gender, source: ProfileAvatarSource.google),
    );
  }

  Future<void> removeCustomPhoto() =>
      _write(ProfileMedia(gender: value.gender));

  Future<void> saveCustomPhoto(Uint8List bytes) async {
    if (auth.identity == null) {
      throw const AppFailure(
        'account_required',
        'Sign in to keep a custom profile photo privately in your account.',
      );
    }
    await _write(
      ProfileMedia(
        gender: value.gender,
        source: ProfileAvatarSource.custom,
        avatarPng: bytes,
      ),
    );
  }

  Future<void> _write(ProfileMedia next) async {
    if (_operation != null) {
      throw const AppFailure(
        'profile_busy',
        'Your previous profile change is still finishing.',
      );
    }
    final generation = _generation;
    final uid = _uid;
    if (!_current(generation, uid)) throw _changed;
    if (!_ready) throw _unavailable;
    busy = true;
    _operationUid = uid;
    error = null;
    _publish();
    late final Future<void> pending;
    pending =
        (() async {
          if (uid == null) {
            await preferences.write(guestKey, jsonEncode(next.deviceJson));
          } else {
            if (repository == null) throw _unavailable;
            await repository!.write(uid, next);
          }
          if (!_current(generation, uid)) throw _changed;
          value = next;
          error = null;
        })().whenComplete(() {
          if (identical(pending, _operation)) {
            _operation = null;
            _operationUid = null;
            busy = false;
            _publish();
          }
        });
    _operation = pending;
    try {
      await pending.timeout(
        operationTimeout,
        onTimeout: () => throw _unavailable,
      );
    } on AppFailure catch (failure) {
      if (_current(generation, uid)) error = failure.userMessage;
      rethrow;
    } catch (_) {
      if (_current(generation, uid)) error = _unavailable.userMessage;
      throw _unavailable;
    }
  }

  static const _changed = AppFailure(
    'account_changed',
    'Your account changed. Reopen your profile before trying again.',
  );
  static const _unavailable = AppFailure(
    'profile_unavailable',
    'Your profile change could not be confirmed. Check your connection and try again.',
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _restoreTimer?.cancel();
    auth.removeListener(_identityChanged);
    unawaited(_subscription?.cancel());
    value = ProfileMedia();
    super.dispose();
  }
}
