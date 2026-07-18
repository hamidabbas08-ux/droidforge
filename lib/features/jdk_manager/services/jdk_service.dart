
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
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
    if (!await dir.exists()) return null;

    final javaHome = await _findJavaHome(dir);
    return javaHome?.path;
  }

  static Future<bool> isInstalled(JdkVersion version) async {
    final dir = await installDirectory(version);
    return (await _findJavaHome(dir)) != null;
  }

  static Future<void> select(JdkVersion version) async {
    if (!await isInstalled(version)) {
      throw Exception('${version.label} is not installed yet.');
    }
    final file = await _activeFile();
    await file.writeAsString(jsonEncode({'major': version.major}));
  }

  static Future<void> install(
    JdkVersion version, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final target = await installDirectory(version);
    final javaHome = await _findJavaHome(target);
    if (javaHome != null) {
      await select(version);
      onProgress?.call(1, 'Ready');
      return;
    }

    if (!Platform.isLinux) {
      throw UnsupportedError(
        'DroidForge JDK installation currently requires the Linux/Ubuntu runtime.',
      );
    }

    final arch = _linuxArchitecture();
    final url =
        'https://api.adoptium.net/v3/binary/latest/${version.major}/ga/linux/'
        '$arch/jdk/hotspot/normal/eclipse';

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('JDK download failed: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    final bytes = BytesBuilder(copy: false);
    var received = 0;

    await for (final chunk in response.stream) {
      bytes.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call(received / total * 0.7, 'Downloading ${version.label}...');
      }
    }

    onProgress?.call(0.72, 'Extracting ${version.label}...');
    final archiveBytes = bytes.takeBytes();
    final tarBytes = GZipDecoder().decodeBytes(archiveBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    for (final entry in archive) {
      final relative = entry.name;
      if (relative.isEmpty) continue;

      // The Temurin archive has one top-level directory. Strip it so the
      // selected JDK has a stable JAVA_HOME regardless of patch version.
      final parts = relative.split('/');
      final stripped = parts.length > 1 ? parts.sublist(1).join('/') : '';
      if (stripped.isEmpty) continue;

      final destination = File('${target.path}/$stripped');
      if (entry.isFile) {
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(destination.path).create(recursive: true);
      }
    }

    onProgress?.call(0.95, 'Activating ${version.label}...');
    final installedHome = await _findJavaHome(target);
    if (installedHome == null) {
      throw Exception('JDK extraction completed, but java executable was not found.');
    }

    if (Platform.isLinux) {
      await Process.run('chmod', ['-R', 'u+rx', '${installedHome.path}/bin']);
    }

    await select(version);
    onProgress?.call(1, 'Ready');
  }

  static String _linuxArchitecture() {
    final arch = Platform.version.toLowerCase();
    // On the Ubuntu/Termux mobile environment this is normally ARM64.
    if (arch.contains('arm64') || arch.contains('aarch64')) return 'aarch64';
    return 'x64';
  }

  static Future<Directory?> _findJavaHome(Directory root) async {
    if (!await root.exists()) return null;

    final directJava = File('${root.path}/bin/java');
    if (await directJava.exists()) return root;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.path.endsWith('/bin/java') &&
          !entity.path.contains('/jmods/')) {
        return Directory(entity.path.substring(0, entity.path.length - 9));
      }
    }
    return null;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
