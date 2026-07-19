import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AndroidSdkStatus {
  final bool commandLineTools;
  final bool platformTools;
  final bool platform;
  final bool buildTools;
  final String sdkPath;

  const AndroidSdkStatus({
    required this.commandLineTools,
    required this.platformTools,
    required this.platform,
    required this.buildTools,
    required this.sdkPath,
  });

  bool get ready => commandLineTools && platformTools && platform && buildTools;
}

class AndroidSdkService {
  static const int apiLevel = 35;
  static const String buildToolsVersion = '35.0.0';

  static Future<Directory> sdkRoot() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/DroidForge/android-sdk');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<String> sdkPath() async => (await sdkRoot()).path;

  static Future<AndroidSdkStatus> status() async {
    final root = await sdkRoot();
    return AndroidSdkStatus(
      commandLineTools: false,
      platformTools: await Directory('${root.path}/platform-tools').exists(),
      platform: await File('${root.path}/platforms/android-$apiLevel/android.jar').exists(),
      buildTools: await Directory('${root.path}/build-tools/$buildToolsVersion').exists(),
      sdkPath: root.path,
    );
  }

  static Future<void> installRequired({
    void Function(double progress, String status)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge runs on Android only.');
    }

    onProgress?.call(0, 'Android SDK runtime component is not bundled yet.');
    onOutput?.call(
      'V8 removed the incompatible desktop SDK downloader. '
      'An Android ARM64 SDK/build-tools package must be bundled before installation can be enabled.',
    );
    throw UnsupportedError(
      'Android ARM64 SDK component is not bundled yet. '
      'DroidForge V8 will not download or execute incompatible desktop SDK tools.',
    );
  }

  static Future<void> writeLocalProperties(String projectPath) async {
    final root = await sdkRoot();
    final androidDir = Directory('$projectPath/android');
    final targetDir = await androidDir.exists() ? androidDir : Directory(projectPath);
    final file = File('${targetDir.path}/local.properties');

    final escaped = root.path.replaceAll('\\', '\\\\').replaceAll(':', '\\:');
    final existing = await file.exists() ? await file.readAsLines() : <String>[];
    final retained = existing
        .where((line) => !line.trimLeft().startsWith('sdk.dir='))
        .toList();
    retained.add('sdk.dir=$escaped');
    await file.writeAsString('${retained.join('\n')}\n');
  }
}
