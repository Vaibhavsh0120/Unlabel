# Frontend 0.12.0+17 — readability, profile and notifications

14 November 2026. Canonical version: `frontend/pubspec.yaml`.

## Delivered source

- Larger Inter body/form/navigation text and stronger weights; Manrope headings.
  Dark surfaces use neutral charcoal, fine borders and restrained glass. Blur
  stays limited to navigation; high-contrast and reduced-motion paths remain.
- Phone navigation sits 12px lower within the home-indicator inset while its
  controls remain above that indicator. Landscape side safe areas are respected.
- Profile email has a full-width selectable row. Two compact, real library
  counts replace the unrecorded comparison total. Library sync is in Settings.
  Preferences, allergen reminders, identity editing and private account controls
  retain their behavior. Narrow/large-text statistics stack without text scaling.
- Insights headings, source cards and provider controls reflow for larger type.
  Auth retains stationary art and a whole movable phone card; form text and
  controls grow. The mascot/sprout/gardens are retained as lossless WebP layers.
  The animated face waits for the mascot image to decode, avoiding floating eyes.
- A device-local persistent inbox records actual completed scan/save activity,
  receives bounded backend announcements, remembers read state and supports
  clearing without redisplaying the same announcement.
- Browser reminders use real Web Push subscriptions and VAPID delivery. Current
  free hosting schedules one daily window at 13:30–14:30 UTC (displayed locally).
  Android/iOS use an opt-in native OS scheduler with a selectable local time,
  notification-tap handling, test notification and cancellation. Android uses
  inexact alarms, reboot rescheduling and a retained monochrome notification icon.
- Explicit **Unsubscribe from reminders** cancels the native reminder or removes
  the server subscription and browser subscription. Permission/storage/network
  failures are surfaced; settings are not reported as saved before completion.

## Verification

The full Flutter suite passed **532 tests** before the final mascot loading guard;
the affected auth/notification/artwork checks passed another **68 tests**, and
the final analyzer reports no issues. Web release build and isolated-cache
Android debug compilation both passed. Node web checks passed **37 tests** and
repository script checks passed **19 tests**. New
notification tests cover persistence, deduplication, offline reads, permission
denial, storage rollback and unsubscribe across phone/tablet/laptop at 2x text.
Browser bridge/service-worker tests cover permission, subscription, unsubscribe,
bounded notification payload and click-to-inbox behavior.

The real Flutter auth/profile preview was captured at 390×844, 834×1194,
1194×834 and 1440×900 in both themes, covering sign-in, signup, forgot password,
neutral sent state and profile. Early captures taken before artwork decoding
were rejected; fully loaded mascot renders are the visual evidence. Screenshots
and logs stay in ignored `output/`, not in GitHub. Synthetic identities only.
Other screen families are covered by the full responsive/overflow/interaction
suite and production-preview navigation checks. No Safari or physical iPhone,
iPad or MacBook execution is implied by Chromium viewport checks.

Better Design design/review/comprehension/spacing calls were attempted, but the
monthly service quota returned no guidance or measurement. There is no tool
approval or spacing score. Flutter paints its UI on canvas; DOM geometry alone
does not measure those cards.

Native compilation, release publication, hosted checks and physical notification
delivery remain separate gates. The initial Android build found an existing
Gradle transform-cache integrity failure; the isolated-cache Android build passed; release CI separately checks the
published native artifacts. Unsigned IPA publication does not establish LiveContainer
execution or notification permission on a physical device.

## Hosting boundary

This release retains Vercel API/web and Firebase authentication/private storage.
The [Coolify rebuild](COOLIFY_ARCHITECTURE_REBUILD_PLAN.md) is a separate next major
version. No Firebase records are deleted and no hosting cutover occurs here.
See [backend review](BACKEND_V0_16_0_REVIEW.md) and
[source audit](SOURCE_AND_ASSET_AUDIT_2026_11_14.md).
