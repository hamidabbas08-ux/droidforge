import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/jdk_version.dart';

class JdkService {
  static const _activeFileName = 'active-jdk.json';

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
      throw UnsupportedError('DroidForge V9 supports Android only.');
    }
    if (!version.available) {
      throw UnsupportedError('${version.label} is Coming Soon.');
    }

    onProgress?.call(0.1, 'Checking Android ARM64 runtime package...');
    throw UnsupportedError(
      'JDK 17 UI is ready, but a verified Android ARM64 Java runtime bundle is not included in this ZIP. '
      'Desktop/Linux JDK archives are intentionally blocked because Android cannot execute them reliably.',
    );
  }

  static Future<bool> _verifyJava(Directory javaHome) async {
    final java = File('${javaHome.path}/bin/java');
    if (!await java.exists()) return false;
    try {
      final result = await Process.run(java.path, ['-version']);
      return result.exitCode == 0;
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
