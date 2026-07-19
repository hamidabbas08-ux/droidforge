# DroidForge V11.6 — Isolated JVM Crash Guard

- JDK 17 JVM verification now runs in a dedicated Android process (`:runtime_probe`).
- A native HotSpot/JNI crash no longer closes the Flutter UI process.
- The main app waits up to 20 seconds for a probe result and returns a controlled error if the probe process dies or hangs.
- No Wireless ADB or developer option is required for normal users.
- JDK 21 and JDK 24 remain visible as Coming Soon.

This is a safety/foundation patch. A successful JVM probe still depends on the bundled Android-compatible JDK binaries being genuinely compatible with the device and Android linker/runtime.
