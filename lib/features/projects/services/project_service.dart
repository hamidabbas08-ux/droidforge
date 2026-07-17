import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProjectService {
  static Future<Directory> _projectsRoot() async {
    final base = await getExternalStorageDirectory();

    if (base == null) {
      throw Exception("External storage not available");
    }

    final root = Directory("${base.path}/DroidForgeProjects");

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    return root;
  }

  static Future<void> createProject({
    required String projectName,
    required String packageName,
  }) async {
    final root = await _projectsRoot();

    final project = Directory("${root.path}/$projectName");

    if (!await project.exists()) {
      await project.create(recursive: true);
    }

    await Directory("${project.path}/app/src/main/java").create(recursive: true);
    await Directory("${project.path}/res").create(recursive: true);

    await File("${project.path}/AndroidManifest.xml").create(recursive: true);
    await File("${project.path}/build.gradle.kts").create(recursive: true);
    await File("${project.path}/settings.gradle.kts").create(recursive: true);
    await File("${project.path}/gradle.properties").create(recursive: true);
    await File("${project.path}/MainActivity.kt").create(recursive: true);

    await File("${project.path}/package.txt").writeAsString(packageName);
  }

  static Future<void> createFolder(
    String parent,
    String name,
  ) async {
    final dir = Directory("$parent/$name");

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> createFile(
    String parent,
    String name,
  ) async {
    final file = File("$parent/$name");

    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }
}
