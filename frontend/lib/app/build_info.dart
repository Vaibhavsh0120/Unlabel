/// Non-secret build metadata injected by the manual release workflow.
abstract final class BuildInfo {
  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'development',
  );
  static const buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: 'local',
  );
  static const commitSha = String.fromEnvironment(
    'COMMIT_SHA',
    defaultValue: 'local',
  );
  static const backendBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');
}
