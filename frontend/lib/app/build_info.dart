/// Non-secret build metadata injected by the manual release workflow.
abstract final class BuildInfo {
  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.4.0',
  );
  static const buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '5',
  );
  static const commitSha = String.fromEnvironment(
    'COMMIT_SHA',
    defaultValue: 'local',
  );
  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://unlabel-api.vercel.app',
  );
}
