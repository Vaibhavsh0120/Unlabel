import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_failure.dart';
import 'account_auth.dart';
import 'profile_media.dart';

/// Owner-checked profile reads and revision-checked writes through the API.
final class SelfhostProfileMediaRepository implements ProfileMediaRepository {
  SelfhostProfileMediaRepository({
    required this.origin,
    required this.auth,
    required this.client,
  });
  final Uri origin;
  final AccountAuth auth;
  final http.Client client;
  final _snapshots = <String, Map<String, Object?>>{};

  @override
  Stream<ProfileMedia> watch(String uid) async* {
    final snapshot = await _request(uid, 'GET');
    final value = _decode(snapshot);
    _snapshots[uid] = snapshot;
    yield value;
  }

  ProfileMedia _decode(Map<String, Object?> value) {
    if (value['schema_version'] != '1' ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0) {
      throw _invalid;
    }
    final gender = switch (value['gender']) {
      'unset' => ProfileGender.unspecified,
      'male' => ProfileGender.male,
      'female' => ProfileGender.female,
      _ => throw _invalid,
    };
    final encoded = value['avatar_png_base64'];
    if (encoded != null && (encoded is! String || encoded.length > 131072)) {
      throw _invalid;
    }
    final photo = encoded == null ? null : base64Decode(encoded as String);
    final source = photo != null
        ? ProfileAvatarSource.custom
        : switch (value['avatar_preference']) {
            'automatic' => ProfileAvatarSource.automatic,
            'defaultAvatar' => ProfileAvatarSource.defaultAvatar,
            'google' => ProfileAvatarSource.google,
            _ => throw _invalid,
          };
    return ProfileMedia(gender: gender, source: source, avatarPng: photo);
  }

  @override
  Future<void> write(String uid, ProfileMedia value) async {
    final previous = _snapshots[uid];
    if (previous == null) throw _invalid;
    final result = await _request(uid, 'PUT', {
      'schema_version': '1',
      'expected_revision': previous['revision'],
      'display_name': previous['display_name'],
      'gender': value.gender == ProfileGender.unspecified
          ? 'unset'
          : value.gender.name,
      'avatar_preference': value.source.name,
      'avatar_png_base64': value.avatarPng == null
          ? null
          : base64Encode(value.avatarPng!),
    });
    _decode(result);
    _snapshots[uid] = result;
  }

  Future<Map<String, Object?>> _request(
    String uid,
    String method, [
    Map<String, Object?>? body,
  ]) async {
    final abort = Completer<void>();
    try {
      final token = await auth.token(uid);
      if (auth.identity?.uid != uid) throw _invalid;
      final request = http.AbortableRequest(
        method,
        origin.replace(path: '/v1/account/profile'),
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final result = await (() async {
        final response = await client.send(request);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          bytes.add(chunk);
          if (bytes.length > 150 * 1024) throw _invalid;
        }
        if (auth.identity?.uid != uid) throw _invalid;
        if (response.statusCode == 409) {
          throw const AppFailure(
            'profile_conflict',
            'Your profile changed on another device. Reopen Profile and try again.',
          );
        }
        if (response.statusCode != 200) throw _invalid;
        final value = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (value is! Map<String, Object?>) throw _invalid;
        return value;
      })().timeout(const Duration(seconds: 10));
      return result;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw _invalid;
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  static const _invalid = AppFailure(
    'profile_unavailable',
    'Your profile could not be confirmed. Reopen Profile and try again.',
  );
}
