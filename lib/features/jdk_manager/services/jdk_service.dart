import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/runtime/native_runtime_service.dart';
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
    if (version?.major != 17) return null;
    try {
      return await NativeRuntimeService.prepareEmbeddedJdk();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isInstalled(JdkVersion version) async {
    if (version.major != 17 || !version.available) return false;
    final active = await activeVersion();
    return active?.major == 17;
  }

  static Future<void> select(JdkVersion version) async {
    if (version.major != 17 || !await isInstalled(version)) {
      throw Exception('${version.label} embedded JVM foundation is not ready.');
    }
    await (await _activeFile()).writeAsString(jsonEncode({'major': 17}));
  }

  static Future<void> install(
    JdkVersion version, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge supports Android only.');
    }
    await NativeRuntimeService.requireHealthyFoundation();
    if (!version.available || version.major != 17) {
      throw UnsupportedError('${version.label} is Coming Soon.');
    }

    onProgress?.call(0.10, 'Preparing APK-bundled JDK 17 runtime...');
    final javaHome = await NativeRuntimeService.prepareEmbeddedJdk();

    onProgress?.call(0.75, 'Starting JDK 17 in isolated runtime process...');
    final result = await NativeRuntimeService.startEmbeddedJvm(
      javaHome: javaHome,
    );
    if (!result.success || !result.stdout.contains('embedded-jvm-ok')) {
      final detail = result.stderr.isNotEmpty ? result.stderr : result.stdout;
      throw Exception('Isolated JDK 17 startup failed: $detail');
    }

    await (await _activeFile()).writeAsString(jsonEncode({'major': 17}));
    onProgress?.call(1, result.stdout);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
