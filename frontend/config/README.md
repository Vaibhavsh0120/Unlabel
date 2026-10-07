# Client configuration

Only public configuration belongs in this app. BuildInfo reads APP_VERSION,
BUILD_NUMBER, COMMIT_SHA and BACKEND_BASE_URL from Dart build defines. The current
defaults are frontend 0.2.0+3 and the stable production API,
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
through the shared account/scanner adapter to restore an existing SDK session or
perform an explicit authentication action. Confirmed public submissions create
anonymous scanner authentication for guests and retain an existing password
scanner session. The SDK owns token refresh; report/history preferences do not
contain tokens. Read-only lookup, search and opening saved reports create no account.
There is no admin/reviewer user role. Direct Firestore client access remains
denied; structured submissions go through the bounded backend API.

The backend's service-account JSON, actor-secret and optional provider keys stay
outside the client and outside plaintext Git files. Encrypted backend/.env.age is
a backend recovery artifact, not a mobile/web asset. Gemini stays disabled;
there is no model-training or cloud-AI dependency in the connected client.

Published backend v0.7.0 and locally validated frontend v0.2.0+3 implement optional
password scanner login/private sync. Guest workflows retain local personal records.
Signed-in display name/saved/history uses a separate verified-UID local namespace
and private backend snapshot; differing cloud/device data requires an explicit
choice. Photos/raw OCR, dietary/health preferences, appearance and Welcome
completion are excluded from private sync. Frontend hosted verification/publication
remain pending. [Account/screen plan](../../docs/planning/ACCOUNT_SYNC_SCREEN_PLAN.md)
· [Frontend review](../../docs/planning/FRONTEND_V0_2_0_REVIEW.md).

Local report/bookmark keys belong to the guest or selected signed-in UID namespace;
appearance and Welcome completion remain device-local. Clearing history
does not remove saved reports or Firebase SDK identity data; clearing saved
reports does not remove history. Browser storage may be cleared or evicted and
is not a backup. Locale selection, personal allergy preferences and fixture/demo
selection remain future configuration, not implemented current settings.

[Frontend guide](../README.md) ·
[Local development](../../docs/planning/LOCAL_DEVELOPMENT.md) ·
[Firebase policy](../../docs/architecture/COMMUNITY_CATALOGUE.md)
