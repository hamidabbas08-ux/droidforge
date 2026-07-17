import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/file_tree_node.dart';
import '../templates/android_templates.dart';

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

  static Future<Directory> getProjectDirectory(
    String projectName,
  ) async {
    final root = await _projectsRoot();
    return Directory("${root.path}/$projectName");
  }

  static Future<FileTreeNode> loadProjectTree(
    String projectName,
  ) async {
    final project = await getProjectDirectory(projectName);

    if (!await project.exists()) {
      throw Exception("Project not found");
    }

    return FileTreeNode.fromDirectory(project);
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

    final javaPath = packageName.replaceAll('.', '/');

    await Directory(
      "${project.path}/app/src/main/java/$javaPath",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/res",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/assets",
    ).create(recursive: true);

    await File(
      "${project.path}/app/src/main/AndroidManifest.xml",
    ).writeAsString(
      AndroidTemplates.manifest(
        packageName: packageName,
        projectName: projectName,
      ),
    );    await File(
      "${project.path}/app/src/main/java/$javaPath/MainActivity.kt",
    ).writeAsString(
      AndroidTemplates.mainActivity(
        packageName: packageName,
      ),
    );

    await File(
      "${project.path}/build.gradle.kts",
    ).writeAsString(
      AndroidTemplates.rootBuildGradle(),
    );

    await File(
      "${project.path}/app/build.gradle.kts",
    ).writeAsString(
      AndroidTemplates.appBuildGradle(
        packageName: packageName,
      ),
    );

    await File(
      "${project.path}/settings.gradle.kts",
    ).writeAsString(
      AndroidTemplates.settingsGradle(
        projectName: projectName,
      ),
    );

    await File(
      "${project.path}/gradle.properties",
    ).writeAsString(
      AndroidTemplates.gradleProperties(),
    );

    await File(
      "${project.path}/package.txt",
    ).writeAsString(packageName);
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
  }  static Future<void> rename(
    String path,
    String newName,
  ) async {
    final entity = FileSystemEntity.typeSync(path);

    final newPath =
        "${File(path).parent.path}/$newName";

    if (entity == FileSystemEntityType.directory) {
      await Directory(path).rename(newPath);
    } else {
      await File(path).rename(newPath);
    }
  }

  static Future<void> delete(
    String path,
  ) async {
    final entity = FileSystemEntity.typeSync(path);

    if (entity == FileSystemEntityType.directory) {
      await Directory(path).delete(
        recursive: true,
      );
    } else {
      await File(path).delete();
    }
  }
}
