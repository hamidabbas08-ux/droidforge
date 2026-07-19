# DroidForge V11 Embedded Android Runtime Foundation

This version adds a real Android native runtime bridge between Flutter and the Android host process.

Implemented:
- Android ABI/runtime diagnostics.
- Native `ProcessBuilder` execution through Kotlin instead of Dart `Process.start`.
- Native executable permission handling through `android.system.Os.chmod`.
- JDK, SDK manager and Gradle services routed through the native bridge.
- ARM64-only validation.
- JDK 21 and 24 remain Coming Soon.

Not bundled yet:
- A licensed, verified embedded JDK 17 payload.
- A complete embedded shell/bootstrap filesystem.
- Verified Android SDK/build-tools payloads.

Therefore this is a foundation build, not a claim that JDK/SDK installation is already end-to-end functional on every device.
