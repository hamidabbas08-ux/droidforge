import 'lib/features/projects/templates/android_templates.dart';

void main() {
  final manifest = AndroidTemplates.manifest(
    packageName: "com.test.app",
    appName: "Test App",
  );

  print("Manifest length: ${manifest.length}");
  print(manifest);

  final activity = AndroidTemplates.mainActivity(packageName: "com.test.app");

  print("MainActivity length: ${activity.length}");
  print(activity);
}
