export 'web_route_stub.dart' if (dart.library.js_interop) 'web_route_web.dart';

/// Only Firebase password-reset actions enter the in-app password form. Codes
/// stay in memory and are verified by the SDK before the form is enabled.
String? passwordResetCodeFromUri(Uri uri) {
  final fragment = Uri.tryParse(uri.fragment);
  final query = fragment?.path == '/account-reset'
      ? fragment!.queryParameters
      : uri.queryParameters;
  if (query['mode'] != 'resetPassword') return null;
  final code = query['oobCode'];
  if (code == null || code.isEmpty || code.length > 2048) return null;
  return code;
}
