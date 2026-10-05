# Flutter frontend

One Flutter application lives directly here: lib, android, ios and web. It targets Android, iPhone/iPad and the website. The backend is a separate FastAPI application and later a separate Vercel project.

## What works now

A responsive, honest starter screen with the Unlabel tagline and a System/Light/Dark appearance selector. Native/platform files and dependency lockfile exist. The stock Material appearance is temporary; the brand palette is undecided. No camera, OCR, analysis or API request is implemented.

From this directory, use:

~~~sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
~~~

Use Flutter **3.47.4** for the current lockfile/manual release workflow. A web run can use a supported browser target. iOS builds require macOS/Xcode; the release workflow produces an unsigned device IPA, not an installable signed distribution.

## Folder ownership

| Folder | Responsibility |
| --- | --- |
| lib/app | App composition, appearance state and non-secret build metadata |
| lib/core/models | Shared scan/result/coordinate models |
| lib/core/camera, ocr | Future platform adapters: native ML Kit, browser OCR worker |
| lib/core/analysis, knowledge | Future supported offline rules, coverage and bundled glossary lookup |
| lib/core/network, storage | Future backend adapter and device/browser-local persistence |
| lib/core/localization, theme, widgets | Future bilingual copy, semantic tokens and shared widgets |
| lib/features/*/presentation | Views and view models; scanner currently contains the starter screen |
| lib/features/*/data | Future feature repositories/adapters |
| android, ios | Generated native platform projects |
| web | Flutter's website platform files, not a second frontend app |
| assets/knowledge, l10n, images, icons | Future versioned bundles/translations/assets |
| test | Starter layout/theme checks; future feature tests |
| integration_test | Reserved physical-device journeys |
| config | Non-secret client configuration policy |

One Dart offline evaluator will serve all Flutter targets. Shared canonical rules/fixtures keep it aligned with the optional Python online evaluator. Missing/unsupported local rules remain uncertain.

Native OCR requires platform integration later; its Flutter ML Kit wrapper is mobile-only. Web OCR/caching must be implemented explicitly and measured in real browsers. A first website visit cannot work without loading its assets.

See [UI requirements](../docs/planning/UI_REQUIREMENTS.md), [data flow](../docs/architecture/DATA_FLOW.md), [API plan](../docs/architecture/API_PLAN.md) and [release/versioning](../docs/planning/RELEASE_VERSIONING.md).
