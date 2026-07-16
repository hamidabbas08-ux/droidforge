import 'dart:io';

class FileService {
  static final Directory _projectDir =
      Directory("${Directory.current.path}/myapp");

  static Future<String> readFile(String relativePath) async {
    try {
      final file = File("${_projectDir.path}/$relativePath");

      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString("");
      }

      return await file.readAsString();
    } catch (e) {
      return "// Error reading file\n$e";
    }
  }

  static Future<void> saveFile(
      String relativePath,
      String content,
  ) async {
    final file = File("${_projectDir.path}/$relativePath");

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    await file.writeAsString(content);
  }
}
