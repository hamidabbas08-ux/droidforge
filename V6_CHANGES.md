# DroidForge v6 patch

- Runs `sdkmanager` through `/system/bin/sh` to avoid direct-script `Permission denied` from app storage.
- Verifies the selected Java runtime can actually execute before starting SDK installation.
- Uses Android system `chmod` and shell for Gradle wrapper execution.
- Replaces the outdated PRoot/Ubuntu UI note with Android/ARM64 compatibility guidance.

Important: this patch fixes the direct shell-script permission failure. It cannot make an incompatible glibc Linux JDK or x86-64 SDK native binary run on Android/ARM64. The app now reports that incompatibility clearly instead of marking file presence as successful execution.
