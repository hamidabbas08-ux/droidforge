import 'dart:io';

class ProjectService {
  static Future<void> createProject({
    required String projectName,
    required String packageName,
  }) async {
    final root =
        Directory('/storage/emulated/0/DroidForgeProjects/$projectName');

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    await Directory('${root.path}/lib').create(recursive: true);
    await Directory('${root.path}/android').create(recursive: true);
    await Directory('${root.path}/assets').create(recursive: true);

    final pubspec = File('${root.path}/pubspec.yaml');
    if (!await pubspec.exists()) {
      await pubspec.writeAsString('''
name: ${projectName.toLowerCase()}
description: Created by DroidForge

environment:
  sdk: ">=3.0.0 <4.0.0"
''');
    }

    final package = File('${root.path}/package.txt');
    await package.writeAsString(packageName);
  }

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
