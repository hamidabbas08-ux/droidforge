import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProjectService {
  static Future<void> createProject({
    required String projectName,
    required String packageName,
  }) async {
    final base = await getExternalStorageDirectory();

    if (base == null) {
      throw Exception("Storage not available");
    }

    final root = Directory(
      "${base.path}/DroidForgeProjects/$projectName",
    );

    await root.create(recursive: true);

    final folders = [
      "app",
      "app/src",
      "app/src/main",
      "app/src/main/java",
      "app/src/main/res",
      "app/src/main/res/layout",
      "app/src/main/res/drawable",
      "app/src/main/res/mipmap",
      "app/src/main/res/values",
      "app/src/main/assets",
      "gradle",
      "gradle/wrapper",
    ];

    for (final folder in folders) {
      await Directory("${root.path}/$folder").create(recursive: true);
    }

    await File("${root.path}/README.md")
        .writeAsString("# $projectName");

    await File("${root.path}/settings.gradle.kts")
        .writeAsString('rootProject.name="$projectName"');

    await File("${root.path}/build.gradle.kts")
        .writeAsString("// Root Build File");

    await File("${root.path}/gradle.properties")
        .writeAsString("");

    await File("${root.path}/app/src/main/AndroidManifest.xml")
        .writeAsString('''
<manifest package="$packageName">
    <application android:label="$projectName">
    </application>
</manifest>
''');

    await File("${root.path}/app/src/main/java/MainActivity.kt")
        .writeAsString('''
package $packageName

class MainActivity {
}
''');
  }
}
