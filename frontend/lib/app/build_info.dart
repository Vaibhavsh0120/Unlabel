import 'package:flutter/services.dart' show appBuildName, appBuildNumber;

/// Non-secret metadata embedded by Flutter from pubspec or build overrides.
abstract final class BuildInfo {
  static const version = appBuildName ?? 'local';
  static const buildNumber = appBuildNumber ?? 'unversioned';
  static const commitSha = String.fromEnvironment(
    'COMMIT_SHA',
    defaultValue: 'local',
  );
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://unlabel-api.vercel.app',
  );
}
