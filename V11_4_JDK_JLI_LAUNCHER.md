# V11.4 — APK-packaged JLI launcher test

This version keeps the validated V11.3 runtime foundation and changes only JDK execution.

- Packages Android ARM64 `libjli.so` in the APK native library area.
- Launches `JLI_Launch` from a forked native child through JNI.
- Uses the already downloaded/extracted JDK directory as `JAVA_HOME`.
- Captures stdout, stderr and exit code.
- Marks JDK 17 installed only when Java reports a version and exits successfully.

This is a device test build for Milestone 2 execution. It is not yet the SDK milestone.
