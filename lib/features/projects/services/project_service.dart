import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/file_tree_node.dart';
import '../templates/android_templates.dart';

class ProjectService {
  static Future<Directory> _projectsRoot() async {
    final dir = await getApplicationDocumentsDirectory();

    final root = Directory('${dir.path}/DroidForgeProjects');

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

    final javaPath = packageName.replaceAll('.', '/');
    await Directory(
      "${project.path}/app/src/main/java/$javaPath",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/res/layout",
    ).create(recursive: true);

    await Directory(
      "${project.path}/app/src/main/res/values",
    ).create(recursive: true);

    await Directory("${project.path}/gradle").create(recursive: true);

    await Directory("${project.path}/gradle/wrapper").create(recursive: true);

    final manifest = AndroidTemplates.manifest(
      packageName: packageName,
      appName: projectName,
    );

    if (manifest.trim().isEmpty) {
      print("PROJECT PATH: ${project.path}");
      print("MANIFEST LENGTH: ${manifest.length}");
      print(manifest.substring(0, manifest.length > 80 ? 80 : manifest.length));

      throw Exception("AndroidManifest template is empty");
    }

    await File(
      "${project.path}/app/src/main/AndroidManifest.xml",
    ).writeAsString(manifest);

    await File(
      "${project.path}/app/src/main/java/$javaPath/MainActivity.kt",
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
    final type = FileSystemEntity.typeSync(path);

    final newPath = "${File(path).parent.path}/$newName";

    switch (type) {
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
    final type = FileSystemEntity.typeSync(path);

    switch (type) {
      case FileSystemEntityType.file:
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        break;

      case FileSystemEntityType.directory:
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        break;

      default:
        throw Exception("Unsupported file system entity");
    }
  }

  static Future<String> readFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception("File not found");
    }

    return await file.readAsString();
  }

  static Future<void> saveFile(String path, String content) async {
    final file = File(path);

    await file.writeAsString(content);
  }
}
