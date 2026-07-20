import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class JdkStorageService {
  static const _managerDirectoryName = 'DroidForge';
  static const _toolchainsDirectoryName = 'toolchains';
  static const _jdkDirectoryName = 'jdks';
  static const _stateFileName = 'jdk_manager_state.json';

  Future<Directory> getRootDirectory() async {
    final support = await getApplicationSupportDirectory();

    final directory = Directory(
      '${support.path}/$_managerDirectoryName/'
      '$_toolchainsDirectoryName/$_jdkDirectoryName',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> getVersionDirectory(int version) async {
    final root = await getRootDirectory();
    return Directory('${root.path}/jdk-$version');
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
      final value = jsonDecode(await file.readAsString());

      if (value is Map<String, dynamic>) {
        return value;
      }
    } catch (_) {
      // Corrupt state is ignored. Installed files will be inspected again.
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

  Future<int?> readActiveVersion() async {
    final state = await readState();
    final value = state['activeVersion'];

    return value is int ? value : null;
  }

  Future<void> setActiveVersion(int version) async {
    final state = await readState();
    state['activeVersion'] = version;
    await writeState(state);
  }

  Future<bool> hasInstalledVersion(int version) async {
    final directory = await getVersionDirectory(version);
    final java = File('${directory.path}/bin/java');
    final javac = File('${directory.path}/bin/javac');
    final release = File('${directory.path}/release');

    return await java.exists() &&
        await javac.exists() &&
        await release.exists();
  }

  Future<String?> getInstalledPath(int version) async {
    if (!await hasInstalledVersion(version)) {
      return null;
    }

    return (await getVersionDirectory(version)).path;
  }

  Future<void> removeVersion(int version) async {
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
