import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class GradleStorageService {
  static const String _managerDirectoryName = 'DroidForge';
  static const String _toolchainsDirectoryName = 'toolchains';
  static const String _gradleDirectoryName = 'gradle';
  static const String _stateFileName = 'gradle_manager_state.json';

  Future<Directory> getRootDirectory() async {
    final support = await getApplicationSupportDirectory();

    final directory = Directory(
      '${support.path}/$_managerDirectoryName/'
      '$_toolchainsDirectoryName/$_gradleDirectoryName',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> getVersionDirectory(String version) async {
    final root = await getRootDirectory();
    return Directory('${root.path}/gradle-$version');
  }

  Future<File> getStateFile() async {
    final root = await getRootDirectory();
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
      // Invalid state will be rebuilt from installed files.
    }

    return <String, dynamic>{};
  }

  Future<void> writeState(Map<String, dynamic> state) async {
    final file = await getStateFile();
    final temporary = File('${file.path}.tmp');

    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state),
      flush: true,
    );

    if (await file.exists()) {
      await file.delete();
    }

    await temporary.rename(file.path);
  }

  Future<String?> readActiveVersion() async {
    final state = await readState();
    final value = state['activeVersion'];

    return value is String ? value : null;
  }

  Future<void> setActiveVersion(String version) async {
    final state = await readState();
    state['activeVersion'] = version;
    await writeState(state);
  }

  Future<bool> hasInstalledVersion(String version) async {
    final directory = await getVersionDirectory(version);

    final executable = File('${directory.path}/bin/gradle');
    final launcher = File('${directory.path}/lib/gradle-launcher-$version.jar');

    return await executable.exists() && await launcher.exists();
  }

  Future<String?> getInstalledPath(String version) async {
    if (!await hasInstalledVersion(version)) {
      return null;
    }

    return (await getVersionDirectory(version)).path;
  }

  Future<void> removeVersion(String version) async {
    final directory = await getVersionDirectory(version);

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }

    final state = await readState();

    if (state['activeVersion'] == version) {
      state.remove('activeVersion');
      await writeState(state);
    }
  }
}
