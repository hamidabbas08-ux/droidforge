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
    if (home == null) return null;
    return await _isAndroidJavaExecutable(home) ? home.path : null;
  }

  static Future<bool> isInstalled(JdkVersion version) async {
    final dir = await installDirectory(version);
    final home = await _findJavaHome(dir);
    if (home == null) return false;
    return _isAndroidJavaExecutable(home);
  }

  static Future<void> select(JdkVersion version) async {
    if (!await isInstalled(version)) {
      throw Exception('${version.label} Android runtime is not installed.');
    }
    final file = await _activeFile();
    await file.writeAsString(jsonEncode({'major': version.major}));
  }

  static Future<void> install(
    JdkVersion version, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge v7 supports Android only.');
    }
    if (version.major != 17) {
      throw UnsupportedError('Only Android-compatible JDK 17 is supported.');
    }

    onProgress?.call(0.05, 'Checking Android runtime package...');

    // Important: desktop/Linux Temurin archives are intentionally not used.
    // Android cannot safely execute a downloaded desktop JDK from app storage.
    // The next implementation step is a native Android runtime component that
    // ships executable code through the APK native-library directory.
    throw UnsupportedError(
      'Android-native JDK 17 runtime component is not bundled yet. '
      'DroidForge no longer downloads Linux/Desktop JDK archives. '
      'The runtime must be packaged inside the APK as Android ARM64 native code.',
    );
  }

  static Future<bool> _isAndroidJavaExecutable(Directory home) async {
    if (!Platform.isAndroid) return false;
    final java = File('${home.path}/bin/java');
    if (!await java.exists()) return false;
    try {
      final result = await Process.run(
        java.path,
        const ['-version'],
        environment: {
          ...Platform.environment,
          'JAVA_HOME': home.path,
          'PATH': '${home.path}/bin:${Platform.environment['PATH'] ?? ''}',
        },
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory?> _findJavaHome(Directory root) async {
    if (!await root.exists()) return null;
    final directJava = File('${root.path}/bin/java');
    if (await directJava.exists()) return root;
    return null;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
