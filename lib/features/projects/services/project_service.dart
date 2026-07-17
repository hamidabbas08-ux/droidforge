import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/file_tree_node.dart';
import '../templates/android_templates.dart';

class ProjectService {
  static Future<Directory> _projectsRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory("${dir.path}/DroidForgeProjects");

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    return root;
  }

  static Future<Directory> getProjectDirectory(String projectName) async {
    final root = await _projectsRoot();
    return Directory('${root.path}/$projectName');
  }

  static Future<FileTreeNode> loadProjectTree(String projectName) async {
    final project = await getProjectDirectory(projectName);

    if (!await project.exists()) {
      throw Exception('Project not found');
    }

    return FileTreeNode.fromDirectory(project);
  }

  static Future<void> createProject({
    required String projectName,
    required String packageName,
  }) async {
    final project = await getProjectDirectory(projectName);

    await project.create(recursive: true);

    await Directory("${project.path}/app").create(recursive: true);
    await Directory("${project.path}/gradle").create(recursive: true);
    await Directory("${project.path}/gradle/wrapper").create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/java/${packageName.replaceAll(".", "/")}",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/res/layout",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/res/values",
    ).create(recursive: true);

    await File(
      "${project.path}/app/src/main/AndroidManifest.xml",
    ).writeAsString(
      AndroidTemplates.manifest(packageName: packageName, appName: projectName),
    );

    await File(
      "${project.path}/app/src/main/java/${packageName.replaceAll(".", "/")}/MainActivity.kt",
    ).writeAsString(AndroidTemplates.mainActivity(packageName: packageName));

    await File(
      "${project.path}/app/src/main/res/layout/activity_main.xml",
    ).writeAsString(AndroidTemplates.activityMain());

    await File(
      "${project.path}/build.gradle.kts",
    ).writeAsString(AndroidTemplates.rootBuildGradle());

    await File(
      "${project.path}/app/build.gradle.kts",
    ).writeAsString(AndroidTemplates.appBuildGradle(packageName: packageName));

    await File(
      "${project.path}/settings.gradle.kts",
    ).writeAsString(AndroidTemplates.settingsGradle(appName: projectName));

    await File(
      "${project.path}/gradle.properties",
    ).writeAsString(AndroidTemplates.gradleProperties());

    await File(
      "${project.path}/gradle/libs.versions.toml",
    ).writeAsString(AndroidTemplates.libsVersionsToml());

    await File(
      "${project.path}/gradle/wrapper/gradle-wrapper.properties",
    ).writeAsString(AndroidTemplates.gradleWrapperProperties());

    await File(
      "${project.path}/app/src/main/res/values/colors.xml",
    ).writeAsString(AndroidTemplates.colorsXml());

    await File(
      "${project.path}/app/src/main/res/values/strings.xml",
    ).writeAsString(AndroidTemplates.stringsXml(appName: projectName));

    await File(
      "${project.path}/app/src/main/res/values/themes.xml",
    ).writeAsString(AndroidTemplates.themesXml());
  }

  static Future<void> createFolder(String parent, String name) async {
    final dir = Directory("$parent/$name");

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> createFile(String parent, String name) async {
    final file = File("$parent/$name");

    if (!await file.exists()) {
      await file.create(recursive: true);
    }
  }

  static Future<void> rename(String path, String newName) async {
    final entityType = FileSystemEntity.typeSync(path);
    final newPath = "${File(path).parent.path}/$newName";

    switch (entityType) {
      case FileSystemEntityType.file:
        await File(path).rename(newPath);
        break;

      case FileSystemEntityType.directory:
        await Directory(path).rename(newPath);
        break;

      default:
        throw Exception("Unsupported file system entity");
    }
  }

  static Future<void> delete(String path) async {
    final entityType = FileSystemEntity.typeSync(path);

    switch (entityType) {
      case FileSystemEntityType.file:
        await File(path).delete();
        break;

      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        break;

      default:
        throw Exception("Unsupported file system entity");
    }
  }
}
