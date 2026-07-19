# DroidForge Android SDK Manager v3

## Included

- Android SDK Manager screen
- Official Android command-line tools download
- Platform Tools
- Android Platform API 35
- Build Tools 35.0.0
- Gradle integration through JAVA_HOME, ANDROID_HOME, PATH and local.properties

## Use

1. Open JDK Manager and select an installed JDK.
2. Open Android SDK Manager.
3. Tap **Install Required SDK**.
4. Build a project from DroidForge.

## ARM64 mobile warning

The SDK Manager itself is Java-based, but some Google Linux packages contain
x86-64 native executables. On an ARM64 Ubuntu/PRoot phone, downloads may finish
while tools such as aapt2, adb or zipalign may need ARM64-compatible binaries or
an x86-64 translation layer.
