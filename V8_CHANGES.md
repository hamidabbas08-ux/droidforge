# DroidForge V8 — Android-only cleanup

- Removed Flutter platform folders for iOS, web, Windows, macOS and desktop Linux.
- Removed all alternate execution modes; only Android local execution remains.
- Removed selectable execution-mode persistence.
- Removed the incompatible desktop command-line SDK downloader and execution path.
- Kept JDK and SDK installation disabled until verified Android ARM64 components are bundled.
- Retained Android project support and GitHub Actions configuration.
