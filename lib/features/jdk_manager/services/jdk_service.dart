import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/runtime_archive_installer.dart';
import '../../../core/runtime/native_runtime_service.dart';
import '../models/jdk_version.dart';

class JdkService {
  static const _activeFileName = 'active-jdk.json';
  static const _jdk17Url =
      'https://github.com/itsaky/openjdk-17-android/releases/download/01-01-2022/jdk17-arm64.tar.xz';

  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/DroidForge/jdks');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _activeFile() async {
    final root = await _root();
    return File('${root.parent.path}/$_activeFileName');
  }

  static Future<Directory> installDirectory(JdkVersion version) async {
    final root = await _root();
    return Directory('${root.path}/${version.id}');
  }

  static Future<JdkVersion?> activeVersion() async {
    final file = await _activeFile();
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final major = data['major'] as int?;
      return JdkVersion.supported.where((v) => v.major == major).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> activeJavaHome() async {
    final version = await activeVersion();
    if (version == null) return null;
    final dir = await installDirectory(version);
    final home = await _findJavaHome(dir);
    if (home == null || !await _verifyJava(home)) return null;
    return home.path;
  }

  static Future<bool> isInstalled(JdkVersion version) async {
    final dir = await installDirectory(version);
    final home = await _findJavaHome(dir);
    return home != null && await _verifyJava(home);
  }

  static Future<void> select(JdkVersion version) async {
    if (!await isInstalled(version)) {
      throw Exception('${version.label} is not installed or cannot run on Android.');
    }
    await (await _activeFile()).writeAsString(jsonEncode({'major': version.major}));
  }

  static Future<void> install(
    JdkVersion version, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge supports Android only.');
    }
    await NativeRuntimeService.requireHealthyFoundation();
    if (!version.available) {
      throw UnsupportedError('${version.label} is Coming Soon.');
    }
    if (version.major != 17) {
      throw UnsupportedError('${version.label} is Coming Soon.');
    }

    final installDir = await installDirectory(version);
    if (await installDir.exists()) await installDir.delete(recursive: true);
    await installDir.create(recursive: true);

    final cache = Directory('${installDir.parent.path}/downloads');
    final archive = File('${cache.path}/jdk17-arm64.tar.xz');
    await RuntimeArchiveInstaller.download(
      uri: Uri.parse(_jdk17Url),
      destination: archive,
      onProgress: (p, s) => onProgress?.call(p * 0.65, s),
    );
    await RuntimeArchiveInstaller.extractTarXz(
      archiveFile: archive,
      destination: installDir,
      onProgress: (p, s) => onProgress?.call(0.65 + p * 0.25, s),
    );
    await RuntimeArchiveInstaller.makeExecutableTree(installDir);

    final home = await _findJavaHome(installDir);
    if (home == null) {
      throw Exception('JDK archive extracted, but bin/java was not found.');
    }
    onProgress?.call(0.93, 'Verifying Java runtime...');
    if (!await _verifyJava(home)) {
      throw Exception(
        'Android JDK 17 was downloaded but could not execute. '
        'This device may block executables from app storage.',
      );
    }
    await (await _activeFile()).writeAsString(jsonEncode({'major': 17}));
    onProgress?.call(1, 'JDK 17 installed and selected');
  }

  static Future<bool> _verifyJava(Directory javaHome) async {
    final java = File('${javaHome.path}/bin/java');
    if (!await java.exists()) return false;
    try {
      final info = await NativeRuntimeService.runtimeInfo();
      if (!info.isArm64) return false;
      await NativeRuntimeService.chmodExecutable(java.path);
      final result = await NativeRuntimeService.run(
        executable: java.path,
        arguments: const ['-version'],
        environment: {
          'JAVA_HOME': javaHome.path,
          'HOME': javaHome.parent.path,
          'TMPDIR': Directory.systemTemp.path,
          'LD_LIBRARY_PATH': '${javaHome.path}/lib:${javaHome.path}/lib/server',
        },
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory?> _findJavaHome(Directory root) async {
    if (!await root.exists()) return null;
    final direct = File('${root.path}/bin/java');
    if (await direct.exists()) return root;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('/bin/java')) {
        return Directory(entity.path.substring(0, entity.path.length - 9));
      }
    }
    return null;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
