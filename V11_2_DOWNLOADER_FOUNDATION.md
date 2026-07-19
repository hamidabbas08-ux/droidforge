# DroidForge V11.2 — Downloader/Foundation Fix

This milestone does not advance to the Android SDK yet. It fixes the two failures observed during the JDK 17 test:

- GitHub connection closed before the archive completed.
- XZ/TAR extraction froze the Flutter UI and triggered Android's ANR dialog.

Changes:

- Four download attempts with exponential delay.
- `.part` downloads and HTTP Range resume when supported.
- Redirects are requested fresh from the permanent release URL.
- Connection and idle timeouts.
- Download length and minimum-size validation.
- Temporary signed GitHub URLs are removed from user-facing errors.
- XZ/TAR decoding and file extraction run in a background Dart isolate.
- Partial extraction is removed after failure.
- The runtime is never marked installed until `java -version` succeeds.

Milestone status: Embedded Runtime Foundation remains under test. JDK/SDK work must not advance until this download/extraction test passes.
