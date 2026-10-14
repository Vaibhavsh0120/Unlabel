export 'web_route_stub.dart' if (dart.library.js_interop) 'web_route_web.dart';

/// Firebase completes the password action before its fixed Continue return.
/// This route only opens sign-in; it never accepts a code or chooses an owner.
bool isAccountSignInReturnUri(Uri uri, {String? rawUrl}) {
  // Dart normalizes percent-encoded unreserved characters while parsing a Uri.
  // Browser callers provide the original URL so encoded lookalikes stay out.
  if (rawUrl != null) {
    final separator = rawUrl.indexOf('#');
    if (separator < 0 || rawUrl.substring(separator + 1) != '/account-signin') {
      return false;
    }
  }
  final supportedOrigin =
      uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          const {'localhost', '127.0.0.1', '::1'}.contains(uri.host));
  return supportedOrigin &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      uri.fragment == '/account-signin';
}
