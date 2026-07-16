import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileService {
  static Future<Directory> _projectDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/myapp');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  static Future<String> readFile(String relativePath) async {
    try {
      final projectDir = await _projectDir();
      final file = File('${projectDir.path}/$relativePath');

      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString('');
      }

      return await file.readAsString();
    } catch (e) {
      return '// Error reading file\n$e';
    }
  }

  static Future<void> saveFile(
    String relativePath,
    String content,
  ) async {
    final projectDir = await _projectDir();
    final file = File('${projectDir.path}/$relativePath');

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    await file.writeAsString(content);
  }
}
