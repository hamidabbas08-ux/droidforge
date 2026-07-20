import 'package:flutter/foundation.dart';

import '../models/gradle_installation.dart';
import '../models/gradle_release.dart';
import '../services/gradle_installer_service.dart';
import '../services/gradle_storage_service.dart';

class GradleManagerController extends ChangeNotifier {
  GradleManagerController({
    GradleStorageService? storage,
    GradleInstallerService? installer,
  }) : _storage = storage ?? GradleStorageService(),
       _installer = installer ?? GradleInstallerService();

  final GradleStorageService _storage;
  final GradleInstallerService _installer;

  bool _loading = true;
  bool get loading => _loading;

  bool _busy = false;
  bool get busy => _busy;

  List<GradleInstallation> _installations = const <GradleInstallation>[
    GradleInstallation(
      version: '8.10',
      displayName: 'Gradle 8.10',
      state: GradleInstallState.notInstalled,
    ),
  ];

  List<GradleInstallation> get installations =>
      List<GradleInstallation>.unmodifiable(_installations);

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final activeVersion = await _storage.readActiveVersion();
      final updated = <GradleInstallation>[];

      for (final item in _installations) {
        final path = await _storage.getInstalledPath(item.version);

        updated.add(
          item.copyWith(
            state: path == null
                ? GradleInstallState.notInstalled
                : activeVersion == item.version
                ? GradleInstallState.active
                : GradleInstallState.installed,
            progress: path == null ? 0 : 1,
            installPath: path,
            clearError: true,
          ),
        );
      }

      _installations = updated;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> install(String version) async {
    if (_busy) {
      return;
    }

    final release = GradleReleaseCatalog.forVersion(version);

    if (release == null) {
      throw StateError('Gradle $version package is not enabled.');
    }

    _busy = true;

    _update(
      version,
      state: GradleInstallState.downloading,
      progress: 0,
      clearError: true,
    );

    try {
      final path = await _installer.install(
        release,
        onProgress: (stage, progress) {
          final state = switch (stage) {
            'Downloading' => GradleInstallState.downloading,
            'Verifying size' ||
            'Verifying SHA-256' => GradleInstallState.verifying,
            'Extracting' ||
            'Validating Gradle' ||
            'Finalizing' => GradleInstallState.extracting,
            'Testing Gradle' => GradleInstallState.testing,
            _ => GradleInstallState.downloading,
          };

          _update(version, state: state, progress: progress);
        },
      );

      _installations = <GradleInstallation>[
        for (final item in _installations)
          if (item.version == version)
            item.copyWith(
              state: GradleInstallState.active,
              progress: 1,
              installPath: path,
              clearError: true,
            )
          else
            item.copyWith(
              state: item.isInstalled
                  ? GradleInstallState.installed
                  : GradleInstallState.notInstalled,
            ),
      ];

      notifyListeners();
    } catch (error) {
      _update(
        version,
        state: GradleInstallState.failed,
        progress: 0,
        error: error.toString(),
      );

      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> activate(String version) async {
    final target = _installations.firstWhere((item) => item.version == version);

    if (!target.isInstalled) {
      throw StateError('Gradle $version is not installed.');
    }

    await _storage.setActiveVersion(version);

    _installations = <GradleInstallation>[
      for (final item in _installations)
        item.copyWith(
          state: item.version == version
              ? GradleInstallState.active
              : item.isInstalled
              ? GradleInstallState.installed
              : GradleInstallState.notInstalled,
        ),
    ];

    notifyListeners();
  }

  Future<void> remove(String version) async {
    if (_busy) {
      return;
    }

    _busy = true;
    notifyListeners();

    try {
      await _storage.removeVersion(version);
      await load();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _update(
    String version, {
    required GradleInstallState state,
    required double progress,
    String? error,
    bool clearError = false,
  }) {
    _installations = <GradleInstallation>[
      for (final item in _installations)
        if (item.version == version)
          item.copyWith(
            state: state,
            progress: progress,
            error: error,
            clearError: clearError,
          )
        else
          item,
    ];

    notifyListeners();
  }
}
