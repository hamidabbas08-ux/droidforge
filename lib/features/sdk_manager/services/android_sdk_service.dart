import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/runtime_archive_installer.dart';
import '../../../core/runtime/native_runtime_service.dart';
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
  static const String buildToolsVersion = '34.0.4';
  static const _sdkBaseUrl =
      'https://github.com/AndroidIDEOfficial/androidide-tools/releases/download/sdk/android-sdk.tar.xz';
  static const _cmdlineUrl =
      'https://github.com/AndroidIDEOfficial/androidide-tools/releases/download/sdk/cmdline-tools.tar.xz';
  static const _buildToolsUrl =
      'https://github.com/AndroidIDEOfficial/androidide-tools/releases/download/v34.0.4/build-tools-34.0.4-aarch64.tar.xz';
  static const _platformToolsUrl =
      'https://github.com/AndroidIDEOfficial/androidide-tools/releases/download/v34.0.4/platform-tools-34.0.4-aarch64.tar.xz';

  static Future<Directory> sdkRoot() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/DroidForge/android-sdk');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<AndroidSdkStatus> status() async {
    final root = await sdkRoot();
    return AndroidSdkStatus(
      commandLineTools: await File('${root.path}/cmdline-tools/latest/bin/sdkmanager').exists() ||
          await File('${root.path}/cmdline-tools/bin/sdkmanager').exists(),
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
      throw UnsupportedError('DroidForge supports Android only.');
    }
    await NativeRuntimeService.requireHealthyFoundation();
    final javaHome = await JdkService.activeJavaHome();
    if (javaHome == null) {
      throw Exception('Install and verify JDK 17 before installing the Android SDK.');
    }

    final root = await sdkRoot();
    final downloads = Directory('${root.parent.path}/downloads');
    await downloads.create(recursive: true);
    final packages = <({String name, String url})>[
      (name: 'android-sdk.tar.xz', url: _sdkBaseUrl),
      (name: 'cmdline-tools.tar.xz', url: _cmdlineUrl),
      (name: 'build-tools-34.0.4-aarch64.tar.xz', url: _buildToolsUrl),
      (name: 'platform-tools-34.0.4-aarch64.tar.xz', url: _platformToolsUrl),
    ];

    for (var i = 0; i < packages.length; i++) {
      final package = packages[i];
      final start = i / packages.length;
      final span = 1 / packages.length;
      final archive = File('${downloads.path}/${package.name}');
      await RuntimeArchiveInstaller.download(
        uri: Uri.parse(package.url),
        destination: archive,
        onProgress: (p, s) => onProgress?.call(start + p * span * 0.65, s),
      );
      await RuntimeArchiveInstaller.extractTarXz(
        archiveFile: archive,
        destination: root,
        onProgress: (p, s) => onProgress?.call(start + span * 0.65 + p * span * 0.30, s),
      );
    }
    await RuntimeArchiveInstaller.makeExecutableTree(root);

    onOutput?.call('Base SDK and Android ARM64 tools extracted.');
    final sdkManager = await _findSdkManager(root);
    if (sdkManager == null) {
      throw Exception('sdkmanager was not found after extracting command-line tools.');
    }
    await NativeRuntimeService.chmodExecutable(sdkManager.path);
    onProgress?.call(0.94, 'Installing Android Platform $apiLevel...');
    final result = await NativeRuntimeService.run(
      executable: '/system/bin/sh',
      arguments: [
        sdkManager.path,
        '--sdk_root=${root.path}',
        'platforms;android-$apiLevel',
      ],
      environment: {
        'JAVA_HOME': javaHome,
        'ANDROID_SDK_ROOT': root.path,
        'ANDROID_HOME': root.path,
        'HOME': root.parent.path,
        'TMPDIR': Directory.systemTemp.path,
        'PATH': '$javaHome/bin:${root.path}/cmdline-tools/latest/bin:${root.path}/platform-tools',
        'LD_LIBRARY_PATH': '$javaHome/lib:$javaHome/lib/server',
      },
    );
    onOutput?.call(result.stdout);
    onOutput?.call(result.stderr);
    if (result.exitCode != 0) {
      throw Exception('sdkmanager failed (${result.exitCode}): ${result.stderr}');
    }

    final current = await status();
    if (!current.ready) {
      throw Exception(
        'SDK installation finished but verification failed. '
        'commandLineTools=${current.commandLineTools}, platformTools=${current.platformTools}, '
        'platform=${current.platform}, buildTools=${current.buildTools}',
      );
    }
    onProgress?.call(1, 'Android SDK is ready');
  }

  static Future<File?> _findSdkManager(Directory root) async {
    for (final candidate in [
      File('${root.path}/cmdline-tools/latest/bin/sdkmanager'),
      File('${root.path}/cmdline-tools/bin/sdkmanager'),
    ]) {
      if (await candidate.exists()) return candidate;
    }
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('/bin/sdkmanager')) return entity;
    }
    return null;
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
