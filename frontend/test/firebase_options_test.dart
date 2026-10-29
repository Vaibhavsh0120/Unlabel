import 'package:flutter_test/flutter_test.dart';
import 'package:unlabel/app/firebase_options.dart';

void main() {
  test('production uses the proxied same-origin Firebase auth helper', () {
    final options = UnlabelFirebaseOptions.webForOrigin(
      Uri.parse('https://unlabel-india.vercel.app/#/account-signin'),
    );
    expect(options.authDomain, 'unlabel-india.vercel.app');
    expect(options.apiKey, UnlabelFirebaseOptions.web.apiKey);
    expect(options.appId, UnlabelFirebaseOptions.web.appId);
    expect(options.projectId, UnlabelFirebaseOptions.web.projectId);
  });

  test('local and untrusted hosts retain the Firebase-hosted helper', () {
    for (final origin in [
      'http://localhost:5000/',
      'http://127.0.0.1:5000/',
      'https://unlabel-preview.vercel.app/',
      'https://unlabel-india.vercel.app.example.com/',
      'http://unlabel-india.vercel.app/',
      'https://unlabel-india.vercel.app:8443/',
    ]) {
      expect(
        UnlabelFirebaseOptions.webForOrigin(Uri.parse(origin)).authDomain,
        'unlabel-india-catalogue.firebaseapp.com',
        reason: origin,
      );
    }
  });
}
