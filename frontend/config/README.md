# Client configuration

Only public configuration belongs in this app. BuildInfo reads Flutter appBuildName/appBuildNumber, derived from pubspec.yaml,
and reads COMMIT_SHA/BACKEND_BASE_URL from public Dart build defines. The stable production API is
https://unlabel-api.vercel.app; frontend version/build come from the selected
source's canonical pubspec. Local-run and release scripts inject their actual
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
anonymous scanner authentication for guests and retain an existing Google/password
scanner session. The SDK owns token refresh; report/history preferences do not
contain tokens. Read-only lookup, search and opening saved reports create no account.
There is no admin/reviewer user role. Direct access to public/library/AI
collections remains denied; structured submissions go through the bounded backend.
The sole client exception is strict owner-only `profile_media/{uid}` in the
existing named `unlabel` database for optional gender/avatar settings.

The backend's service-account JSON, actor-secret and optional provider keys stay
outside the client and outside plaintext Git files. Encrypted backend/.env.age is
a backend recovery artifact, not a mobile/web asset. AI stays disabled in
clean-clone defaults. Configured consented extraction is optional, with local OCR
fallback and no custom training dependency.

Optional Google/password scanner sign-in uses Firebase Auth. Adding a provider
in Profile settings links to the same UID/library and never merges a collision. Guest workflows retain local personal records.
Signed-in display name/saved/history uses a separate verified-UID local namespace
and private backend snapshot; differing cloud/device data requires an explicit
choice. Package photos/raw OCR, dietary/health reminders, appearance and Welcome
completion are excluded from library sync. Profile thumbnails are a separate
bounded private document; no Storage bucket or second database is used.
[Account/profile contract](../../docs/architecture/ACCOUNT_PROFILE.md) ·
[Current local repair](../../docs/planning/FRONTEND_V0_8_1_REVIEW.md).
Reset requests retain Firebase's hosted action handler and an SDK-supplied fixed
`https://unlabel-india.vercel.app/#/account-signin` return; the app never needs a
custom action URL or receives the reset code. The 13 October source completion
and push authorization supersedes the earlier local hold; inbox/provider and
hosted/native verification remain separate.

Local report/bookmark keys belong to the guest or selected signed-in UID namespace;
appearance and Welcome completion remain device-local. Clearing history
does not remove saved reports or Firebase SDK identity data; clearing saved
reports does not remove history. Browser storage may be cleared or evicted and
is not a backup. Dietary/allergen reminders are editable device-only choices
and do not infer suitability. Locale and fixture/demo selection remain future
configuration. Optional user-chosen gender controls the default avatar; unset uses
the approved male art without recording or inferring gender.

[Frontend guide](../README.md) ·
[Local development](../../docs/planning/LOCAL_DEVELOPMENT.md) ·
[Firebase policy](../../docs/architecture/COMMUNITY_CATALOGUE.md)
