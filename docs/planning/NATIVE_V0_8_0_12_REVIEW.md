# Frontend 0.8.0+12 native signing repair

This release builds the already-approved 0.8.0+12 application. The later local
0.8.1+13 profile/reset changes are excluded from this repair and remain unpublished.

GitHub run `38349828445`, attempt 2, built the Android APK successfully but rejected
its SHA-1 `A5:F8:6D:17:FF:E8:84:43:B8:D8:AC:DE:F5:0F:29:46:AF:3B:D2:8C`.
The registered private demo key instead has SHA-1
`3E:7F:9E:3A:26:DC:4E:A8:0C:85:8A:48:12:BC:59:C7:2D:5F:D8:0A`.
The Kotlin plugin warnings did not prevent compilation.

The repair selects a separate explicit `registeredDemo` signing configuration
from a private runner-temporary keystore. CI verifies the restored certificate
before building and retains the APK certificate check after building. Local
builds without that environment variable keep their developer debug signing.
No key material is tracked, regenerated or printed.

Workflow lint and ten release guard tests pass. Native publication and refreshed
LiveContainer feed require the repaired GitHub run to finish and its assets to
pass verification. Physical LiveContainer import/launch remains unverified.
