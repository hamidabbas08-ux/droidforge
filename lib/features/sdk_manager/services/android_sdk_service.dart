import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../jdk_manager/services/jdk_service.dart';

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

  static Future<AndroidSdkStatus> status() async {
    final root = await sdkRoot();
    return AndroidSdkStatus(
      commandLineTools: await File('${root.path}/cmdline-tools/latest/bin/sdkmanager').exists(),
      platformTools: await File('${root.path}/platform-tools/adb').exists(),
      platform: await File('${root.path}/platforms/android-$apiLevel/android.jar').exists(),
      buildTools: await File('${root.path}/build-tools/$buildToolsVersion/aapt2').exists(),
      sdkPath: root.path,
    );
  }

  static Future<void> installRequired({
    void Function(double progress, String status)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge V9 supports Android only.');
    }
    final javaHome = await JdkService.activeJavaHome();
    if (javaHome == null) {
      throw Exception('Install and verify JDK 17 before installing the Android SDK.');
    }
    onProgress?.call(0.1, 'Checking Android ARM64 SDK packages...');
    onOutput?.call('Desktop Linux command-line tools are blocked in V9.');
    throw UnsupportedError(
      'A verified Android ARM64 SDK bundle (platform tools, build tools, and platform files) '
      'is not included in this ZIP. V9 will not download incompatible Linux x86-64 tools.',
    );
  }

  static Future<void> writeLocalProperties(String projectPath) async {
    final root = await sdkRoot();
    final androidDir = Directory('$projectPath/android');
    final targetDir = await androidDir.exists() ? androidDir : Directory(projectPath);
    final file = File('${targetDir.path}/local.properties');
    final escaped = root.path.replaceAll('\\', '\\\\').replaceAll(':', '\\:');
    final existing = await file.exists() ? await file.readAsLines() : <String>[];
    final retained = existing.where((line) => !line.trimLeft().startsWith('sdk.dir=')).toList();
    retained.add('sdk.dir=$escaped');
    await file.writeAsString('${retained.join('\n')}\n');
  }
}
