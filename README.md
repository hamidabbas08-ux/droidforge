# droidforge

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## JDK Manager / Gradle integration

DroidForge now manages JDK 17, 21, and 24 under its application-support directory.
The selected JDK is persisted and is passed as `JAVA_HOME`, `GRADLE_JAVA_HOME`, and
the first entry in `PATH` when a Gradle debug build is launched.

JDK downloads use the Eclipse Temurin/Adoptium binary API. The JDK manager is designed
for the Linux/Ubuntu runtime where DroidForge can launch the Gradle process. On Android
runtime, a Flutter app cannot generally launch arbitrary Ubuntu/Termux processes from
its Android sandbox; the Linux/Ubuntu target is therefore the execution target for the
integrated Gradle build path.

## Integrated Android SDK Manager

DroidForge now includes an Android SDK Manager that installs:

- Android command-line tools
- Platform Tools
- Android Platform API 35
- Build Tools 35.0.0

Gradle builds use the selected JDK and the managed SDK through `JAVA_HOME`,
`ANDROID_HOME`, `PATH`, and the project's `local.properties` (`sdk.dir`).

The Linux packages published by Google may contain x86-64 native binaries.
On an ARM64 phone/PRoot environment, `sdkmanager` can work through Java while
native tools such as `adb`, `aapt2`, or `zipalign` can require an ARM64 build or
an x86-64 translation layer.

## v4 execution-engine foundation

This build adds an Execution Environment screen and a central execution engine abstraction for Android local shell, direct Linux, Termux bridge, and Ubuntu PRoot modes. Direct Linux and Android local-shell execution are implemented. Termux/Ubuntu bridge modes are intentionally guarded until the native bridge is added, because Android APK, Termux, and PRoot Ubuntu are separate sandboxes.


## V11.8 extracted runtime startup
- Extracts the complete JDK 17 runtime image into app-internal storage.
- Copies native JVM libraries into the extracted runtime layout.
- Starts HotSpot only in the isolated `:runtime_probe` process.
- Sets JAVA_HOME, boot library path, native library path, HOME, TMPDIR, and conservative JVM options before startup.
- Verifies `lib/modules`, `java.security`, and `libjvm.so` before probing.
