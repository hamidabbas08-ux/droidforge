import 'dart:io';

class ProjectService {
  static Future<void> createFolder(
    String parent,
    String name,
  ) async {
    final dir = Directory('$parent/$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> createFile(
    String parent,
    String name,
  ) async {
    final file = File('$parent/$name');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }
}
