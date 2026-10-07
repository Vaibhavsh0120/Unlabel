# Client configuration

Only public configuration belongs in this app. BuildInfo reads APP_VERSION,
BUILD_NUMBER, COMMIT_SHA and BACKEND_BASE_URL from Dart build defines. The current
defaults are frontend 0.1.0+2 and the stable production API,
https://unlabel-api.vercel.app. Local-run and release scripts inject their actual
metadata; the URL is an address, never a credential.

The HTTP adapter accepts an HTTPS origin without credentials, query or fragment.
Debug loopback HTTP is allowed for local web development. It does not enable
arbitrary cleartext LAN traffic. On a physical phone localhost refers to the
phone; use an appropriate reachable HTTPS endpoint and validate the device
configuration separately. Production builds must not embed an expiring preview
URL or a private shared token.

Public Firebase app identifiers live in lib/app/firebase_options.dart and
firebase/client-config.json at the repository root. The Firebase SDK initializes
lazily for a confirmed-label submission and uses only anonymous scanner
authentication. It owns token refresh; report/history preferences do not contain
tokens. Read-only lookup, search and opening saved reports create no account.
There is no admin/reviewer user role. Direct Firestore client access remains
denied; structured submissions go through the bounded backend API.

The backend's service-account JSON, actor-secret and optional provider keys stay
outside the client and outside plaintext Git files. Encrypted backend/.env.age is
a backend recovery artifact, not a mobile/web asset. Gemini stays disabled;
there is no model-training or cloud-AI dependency in the connected client.

Next accepted v0.7.0/v0.2.0 adds optional scanner login/private sync; it must retain guest use without personal uploads and keep signed-in personal records private. [Next plan](../../docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md).

Local report/bookmark/appearance keys have their own namespace. Clearing history
does not remove saved reports or Firebase SDK identity data; clearing saved
reports does not remove history. Browser storage may be cleared or evicted and
is not a backup. Locale selection, personal allergy preferences and fixture/demo
selection remain future configuration, not implemented current settings.

[Frontend guide](../README.md) ·
[Local development](../../docs/planning/LOCAL_DEVELOPMENT.md) ·
[Firebase policy](../../docs/architecture/COMMUNITY_CATALOGUE.md)
