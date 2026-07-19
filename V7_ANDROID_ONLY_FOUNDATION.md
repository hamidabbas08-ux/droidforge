# DroidForge v7 Android-only foundation

This revision removes the invalid desktop/Linux JDK download path.

## Enforced decisions

- Android is the only supported target for the in-app build runtime.
- JDK 17 is the first supported Gradle runtime.
- JDK 21 and 24 are hidden until Android-native packages are verified.
- Adoptium Linux archives are not downloaded.
- A downloaded file is not treated as installed until `java -version` runs successfully on Android.

## Required next native milestone

The Java launcher and its dependent native libraries must be delivered through the APK's Android native-library mechanism (or an equivalent embedded Android runtime). A Dart-only `chmod` fix cannot turn a Linux desktop JDK into an Android runtime.

After that runtime is bundled, the SDK installer should use Android/ARM64 build-tools packages rather than Google's x86_64 Linux executables.
