import 'package:flutter/foundation.dart';

import '../models/jdk_installation.dart';
import '../models/jdk_release.dart';
import '../services/jdk_installer_service.dart';
import '../services/jdk_storage_service.dart';

class JdkManagerController extends ChangeNotifier {
  JdkManagerController({
    JdkStorageService? storage,
    JdkInstallerService? installer,
  }) : _storage = storage ?? JdkStorageService(),
       _installer = installer ?? JdkInstallerService();

  final JdkStorageService _storage;
  final JdkInstallerService _installer;

  bool _loading = true;
  bool get loading => _loading;

  bool _busy = false;
  bool get busy => _busy;

  List<JdkInstallation> _installations = const [
    JdkInstallation(
      version: 17,
      displayName: 'JDK 17',
      state: JdkInstallState.notInstalled,
    ),
    JdkInstallation(
      version: 21,
      displayName: 'JDK 21',
      state: JdkInstallState.notInstalled,
    ),
    JdkInstallation(
      version: 24,
      displayName: 'JDK 24',
      state: JdkInstallState.notInstalled,
    ),
  ];

  List<JdkInstallation> get installations => List.unmodifiable(_installations);

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final activeVersion = await _storage.readActiveVersion();
    final updated = <JdkInstallation>[];

    for (final item in _installations) {
      final path = await _storage.getInstalledPath(item.version);

      updated.add(
        item.copyWith(
          state: path == null
              ? JdkInstallState.notInstalled
              : activeVersion == item.version
              ? JdkInstallState.active
              : JdkInstallState.installed,
          installPath: path,
          progress: path == null ? 0 : 1,
          clearError: true,
        ),
      );
    }

    _installations = updated;
    _loading = false;
    notifyListeners();
  }

  Future<void> install(int version) async {
    if (_busy) {
      return;
    }

    final release = JdkReleaseCatalog.forVersion(version);

    if (release == null) {
      throw StateError('JDK $version package is not enabled yet.');
    }

    _busy = true;

    _update(
      version,
      state: JdkInstallState.downloading,
      progress: 0,
      clearError: true,
    );

    try {
      final path = await _installer.install(
        release,
        onProgress: (stage, progress) {
          final state = switch (stage) {
            'Downloading' => JdkInstallState.downloading,
            'Verifying size' ||
            'Verifying SHA-256' => JdkInstallState.verifying,
            'Extracting' ||
            'Validating JDK' ||
            'Finalizing' => JdkInstallState.extracting,
            _ => JdkInstallState.downloading,
          };

          _update(version, state: state, progress: progress);
        },
      );

      _installations = [
        for (final item in _installations)
          if (item.version == version)
            item.copyWith(
              state: JdkInstallState.active,
              progress: 1,
              installPath: path,
              clearError: true,
            )
          else
            item.copyWith(
              state: item.isInstalled
                  ? JdkInstallState.installed
                  : JdkInstallState.notInstalled,
            ),
      ];

      notifyListeners();
    } catch (error) {
      _update(
        version,
        state: JdkInstallState.failed,
        progress: 0,
        error: error.toString(),
      );

      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> activate(int version) async {
    final target = _installations.firstWhere((item) => item.version == version);

    if (!target.isInstalled) {
      throw StateError('JDK $version is not installed.');
    }

    await _storage.setActiveVersion(version);

    _installations = [
      for (final item in _installations)
        item.copyWith(
          state: item.version == version
              ? JdkInstallState.active
              : item.isInstalled
              ? JdkInstallState.installed
              : JdkInstallState.notInstalled,
        ),
    ];

    notifyListeners();
  }

  Future<void> remove(int version) async {
    if (_busy) {
      return;
    }

    await _storage.removeVersion(version);
    await load();
  }

  void _update(
    int version, {
    required JdkInstallState state,
    required double progress,
    String? error,
    bool clearError = false,
  }) {
    _installations = [
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
