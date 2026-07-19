import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;

class RuntimeArchiveInstaller {
  static Future<File> download({
    required Uri uri,
    required File destination,
    required void Function(double progress, String status)? onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    final request = http.Request('GET', uri);
    final response = await http.Client().send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Download failed (${response.statusCode}) for $uri');
    }

    final sink = destination.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total, 'Downloading ${destination.uri.pathSegments.last}');
        }
      }
    } finally {
      await sink.close();
    }
    return destination;
  }

  static Future<void> extractTarXz({
    required File archiveFile,
    required Directory destination,
    required void Function(double progress, String status)? onProgress,
  }) async {
    await destination.create(recursive: true);
    onProgress?.call(0.0, 'Extracting ${archiveFile.uri.pathSegments.last}');
    final compressed = await archiveFile.readAsBytes();
    final xz = XZDecoder().decodeBytes(compressed);
    final tar = TarDecoder().decodeBytes(xz);

    var index = 0;
    for (final entry in tar) {
      final safePath = _safeJoin(destination.path, entry.name);
      if (entry.isFile) {
        final out = File(safePath);
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>, flush: true);
      } else if (entry.isDirectory) {
        await Directory(safePath).create(recursive: true);
      }
      index++;
      onProgress?.call(tar.isEmpty ? 1 : index / tar.length, 'Extracting ${entry.name}');
    }
  }

  static String _safeJoin(String root, String relative) {
    final normalized = relative.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.split('/').contains('..')) {
      throw FormatException('Unsafe archive path: $relative');
    }
    return '$root/$normalized';
  }

  static Future<void> makeExecutableTree(Directory root) async {
    if (!await root.exists()) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.contains('/bin/') ||
          path.endsWith('/java') ||
          path.endsWith('/javac') ||
          path.endsWith('/aapt2') ||
          path.endsWith('/aapt') ||
          path.endsWith('/adb') ||
          path.endsWith('/apksigner') ||
          path.endsWith('/d8') ||
          path.endsWith('/sdkmanager')) {
        await Process.run('/system/bin/chmod', ['700', path]);
      }
    }
  }
}
