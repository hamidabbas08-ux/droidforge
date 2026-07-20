import 'package:flutter/foundation.dart';

import '../models/jdk_installation.dart';
import '../services/jdk_storage_service.dart';

class JdkManagerController extends ChangeNotifier {
  JdkManagerController({JdkStorageService? storage})
    : _storage = storage ?? JdkStorageService();

  final JdkStorageService _storage;

  bool _loading = true;

  bool get loading => _loading;

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
    await _storage.removeVersion(version);
    await load();
  }
}
