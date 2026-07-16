import 'dart:io';

class ProjectService {
  static Future<void> createProject({
    required String projectName,
    required String packageName,
  }) async {
    final root = Directory("/storage/emulated/0/DroidForgeProjects/$projectName");

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    await Directory("${root.path}/app").create(recursive: true);
    await Directory("${root.path}/gradle").create(recursive: true);
    await Directory("${root.path}/src").create(recursive: true);
    await Directory("${root.path}/res").create(recursive: true);

    await File("${root.path}/AndroidManifest.xml").writeAsString(
      "<manifest package=\"$packageName\"></manifest>",
    );

    await File("${root.path}/build.gradle.kts").writeAsString("// build.gradle");

    await File("${root.path}/settings.gradle.kts")
        .writeAsString("rootProject.name=\"$projectName\"");

    await File("${root.path}/gradle.properties").writeAsString("");

    await File("${root.path}/MainActivity.kt").writeAsString("""
package $packageName

fun main() {

}
""");
  }
}
