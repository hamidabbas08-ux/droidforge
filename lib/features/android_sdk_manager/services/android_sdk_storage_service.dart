import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/android_sdk_package.dart';

class AndroidSdkStorageService {
  static const String _managerDirectoryName = 'DroidForge';
  static const String _toolchainsDirectoryName = 'toolchains';
  static const String _sdkDirectoryName = 'android-sdk';
  static const String _stateFileName = 'android_sdk_manager_state.json';

  Future<Directory> getSdkRootDirectory() async {
    final support = await getApplicationSupportDirectory();

    final directory = Directory(
      '${support.path}/$_managerDirectoryName/'
      '$_toolchainsDirectoryName/$_sdkDirectoryName',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> getStateFile() async {
    final root = await getSdkRootDirectory();
    return File('${root.path}/$_stateFileName');
  }

  Future<Map<String, dynamic>> readState() async {
    final file = await getStateFile();

    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(await file.readAsString());

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Invalid state will be rebuilt from installed SDK files.
    }

    return <String, dynamic>{};
  }

  Future<void> writeState(Map<String, dynamic> state) async {
    final file = await getStateFile();
    final temporaryFile = File('${file.path}.tmp');

    await temporaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state),
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await temporaryFile.rename(file.path);
  }

  Future<void> setInstalled(bool installed) async {
    final state = await readState();
    state['installed'] = installed;
    await writeState(state);
  }

  Future<bool> isPackageInstalled(AndroidSdkPackage package) async {
    final root = await getSdkRootDirectory();
    final packageDirectory = Directory('${root.path}/${package.relativePath}');

    if (!await packageDirectory.exists()) {
      return false;
    }

    for (final relativeFile in package.requiredFiles) {
      final file = File('${packageDirectory.path}/$relativeFile');

      if (!await file.exists()) {
        return false;
      }
    }

    return true;
  }

  Future<bool> isSdkInstalled() async {
    for (final package in AndroidSdkPackageCatalog.requiredPackages) {
      if (!await isPackageInstalled(package)) {
        return false;
      }
    }

    return true;
  }

  Future<String?> getInstalledPath() async {
    if (!await isSdkInstalled()) {
      return null;
    }

    return (await getSdkRootDirectory()).path;
  }

  Future<void> removeSdk() async {
    final root = await getSdkRootDirectory();

    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
