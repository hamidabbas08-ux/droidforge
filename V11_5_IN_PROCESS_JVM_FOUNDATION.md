# DroidForge V11.5 — In-Process JVM Foundation Test

This milestone removes the external `bin/java`/JLI process path from JDK 17 verification.

## Included

- Android ARM64 OpenJDK 17 runtime image (`lib/modules` and configuration) bundled in the APK.
- OpenJDK native libraries packaged in the APK native-library directory.
- Kotlin asset preparation and native-library layout creation.
- JNI bridge that calls `JNI_CreateJavaVM()` in the DroidForge process.
- A real verification call to `System.getProperty("java.version")`.

## Pass condition

The JDK Manager must display a completed state containing:

`embedded-jvm-ok|java.version=...`

## Important boundary

This is an experimental JVM-startup foundation test. It does not yet prove that Gradle can run inside the Android app process, and it is not the final SDK/Gradle implementation.
