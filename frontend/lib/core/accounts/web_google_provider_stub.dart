Future<Map<String, Object?>> googleOAuth(String backend, {String? token}) =>
    throw UnsupportedError('Browser authorization is web only.');

void prepareGoogleOAuth() {}
void cancelGoogleOAuth() {}

Future<void> startGoogleRedirect(String backend) =>
    throw UnsupportedError('Browser authorization is web only.');
Map<String, Object?>? takeGoogleRedirect() => null;
