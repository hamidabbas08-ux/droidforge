import 'package:flutter/foundation.dart';

import '../models/android_sdk_installation.dart';
import '../services/android_sdk_storage_service.dart';

class AndroidSdkManagerController extends ChangeNotifier {
  AndroidSdkManagerController({AndroidSdkStorageService? storage})
    : _storage = storage ?? AndroidSdkStorageService();

  final AndroidSdkStorageService _storage;

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
