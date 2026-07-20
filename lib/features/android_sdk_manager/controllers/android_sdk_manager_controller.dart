import 'package:flutter/foundation.dart';

import '../models/android_sdk_bundle.dart';
import '../models/android_sdk_installation.dart';
import '../services/android_sdk_installer_service.dart';
import '../services/android_sdk_storage_service.dart';

class AndroidSdkManagerController extends ChangeNotifier {
  AndroidSdkManagerController({
    AndroidSdkStorageService? storage,
    AndroidSdkInstallerService? installer,
  }) {
    _storage = storage ?? AndroidSdkStorageService();
    _installer = installer ?? AndroidSdkInstallerService(storage: _storage);
  }

  late final AndroidSdkStorageService _storage;
  late final AndroidSdkInstallerService _installer;

  AndroidSdkInstallation installation = const AndroidSdkInstallation(
    state: AndroidSdkInstallState.notInstalled,
  );

  bool loading = false;
  bool busy = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      await _refreshInstallation();
    } catch (error) {
      installation = installation.copyWith(
        state: AndroidSdkInstallState.failed,
        error: error.toString(),
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (busy) {
      return;
    }

    busy = true;
    notifyListeners();

    try {
      await _refreshInstallation();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> install() async {
    if (busy) {
      return;
    }

    busy = true;

    installation = const AndroidSdkInstallation(
      state: AndroidSdkInstallState.downloading,
      progress: 0,
    );

    notifyListeners();

    try {
      final installPath = await _installer.install(
        AndroidSdkBundleCatalog.sdk35Arm64,
        onProgress: (stage, progress) {
          installation = AndroidSdkInstallation(
            state: _stateForStage(stage),
            progress: progress.clamp(0.0, 1.0).toDouble(),
            installPath: installation.installPath,
          );

          notifyListeners();
        },
      );

      installation = AndroidSdkInstallation(
        state: AndroidSdkInstallState.active,
        progress: 1,
        installPath: installPath,
      );
    } catch (error) {
      installation = AndroidSdkInstallation(
        state: AndroidSdkInstallState.failed,
        progress: installation.progress,
        installPath: installation.installPath,
        error: error.toString(),
      );

      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> remove() async {
    if (busy) {
      return;
    }

    busy = true;
    notifyListeners();

    try {
      await _storage.removeSdk();

      installation = const AndroidSdkInstallation(
        state: AndroidSdkInstallState.notInstalled,
      );
    } catch (error) {
      installation = installation.copyWith(
        state: AndroidSdkInstallState.failed,
        error: error.toString(),
      );

      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  AndroidSdkInstallState _stateForStage(String stage) {
    if (stage.startsWith('Downloading')) {
      return AndroidSdkInstallState.downloading;
    }

    if (stage.startsWith('Verifying')) {
      return AndroidSdkInstallState.verifying;
    }

    if (stage == 'Installed and active') {
      return AndroidSdkInstallState.active;
    }

    return AndroidSdkInstallState.extracting;
  }

  Future<void> _refreshInstallation() async {
    final installed = await _storage.isSdkInstalled();

    final installPath = installed ? await _storage.getInstalledPath() : null;

    installation = AndroidSdkInstallation(
      state: installed
          ? AndroidSdkInstallState.active
          : AndroidSdkInstallState.notInstalled,
      progress: installed ? 1 : 0,
      installPath: installPath,
    );
  }
}
