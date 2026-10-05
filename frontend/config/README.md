# Future client configuration

Only non-secret settings belong on the client: backend base URL, locale and clearly marked fixture/demo-mode selection. The starter's `lib/app/build_info.dart` reads release metadata and `BACKEND_BASE_URL` from Dart build defines. It does not make network requests. Locale and fixture settings are reserved for later implementation.

A development phone can use the laptop's private LAN address; localhost on a phone points to the phone itself. Production mobile builds use the backend Vercel project's stable HTTPS production URL. Emulators and preview environments have separate documented addresses. Never ship an expiring preview URL as the production endpoint.

A private local demo may use restricted development HTTP settings and a session token entered locally. A shared secret embedded in a released APK/IPA is not authentication. Public hosting requires proper user/session authorization and abuse protection before cloud AI is enabled. Do not widen platform security settings now.

Gemini keys and other provider secrets always stay on the backend. User allergy preferences stay in device storage and never become cloud-AI configuration.
