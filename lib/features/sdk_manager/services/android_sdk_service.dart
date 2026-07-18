import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
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

  // Current official Linux command-line tools package listed by Google.
  static const String _commandLineToolsUrl =
      'https://dl.google.com/android/repository/'
      'commandlinetools-linux-14742923_latest.zip';

  static Future<Directory> sdkRoot() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/DroidForge/android-sdk');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<String> sdkPath() async => (await sdkRoot()).path;

  static Future<File> sdkManagerFile() async {
    final root = await sdkRoot();
    return File('${root.path}/cmdline-tools/latest/bin/sdkmanager');
  }

  static Future<AndroidSdkStatus> status() async {
    final root = await sdkRoot();
    final sdkManager = await sdkManagerFile();
    return AndroidSdkStatus(
      commandLineTools: await sdkManager.exists(),
      platformTools: await File('${root.path}/platform-tools/adb').exists(),
      platform: await File('${root.path}/platforms/android-$apiLevel/android.jar').exists(),
      buildTools: await Directory('${root.path}/build-tools/$buildToolsVersion').exists(),
      sdkPath: root.path,
    );
  }

  static Future<void> installRequired({
    void Function(double progress, String status)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        'Android SDK installation currently requires DroidForge to run in Linux/Ubuntu.',
      );
    }

    final javaHome = await JdkService.activeJavaHome();
    if (javaHome == null) {
      throw Exception('Install and select a JDK before installing the Android SDK.');
    }

    final root = await sdkRoot();
    if (!await (await sdkManagerFile()).exists()) {
      await _installCommandLineTools(root, onProgress: onProgress);
    }

    onProgress?.call(0.48, 'Preparing Android SDK packages...');
    final sdkManager = await sdkManagerFile();
    await _makeExecutable(sdkManager.path);

    // sdkmanager asks for licenses on stdin. The UI explicitly informs the
    // user that starting installation accepts the Android SDK license terms.
    final process = await Process.start(
      sdkManager.path,
      [
        '--sdk_root=${root.path}',
        'platform-tools',
        'platforms;android-$apiLevel',
        'build-tools;$buildToolsVersion',
      ],
      environment: {
        ...Platform.environment,
        'JAVA_HOME': javaHome,
        'ANDROID_HOME': root.path,
        'ANDROID_SDK_ROOT': root.path,
        'PATH': '$javaHome/bin:${root.path}/cmdline-tools/latest/bin:'
            '${root.path}/platform-tools:${Platform.environment['PATH'] ?? ''}',
        'REPO_OS_OVERRIDE': 'linux',
      },
      runInShell: false,
    );

    // Accept licenses for the requested packages after the user starts install.
    process.stdin.write(List.filled(20, 'y\n').join());
    await process.stdin.flush();
    await process.stdin.close();

    var lastProgress = 0.5;
    final outputTasks = <Future<void>>[
      _consumeLines(process.stdout, (line) {
        onOutput?.call(line);
        lastProgress = (lastProgress + 0.01).clamp(0.5, 0.96).toDouble();
        onProgress?.call(lastProgress, line.isEmpty ? 'Installing SDK packages...' : line);
      }),
      _consumeLines(process.stderr, (line) {
        onOutput?.call(line);
        if (line.isNotEmpty) onProgress?.call(lastProgress, line);
      }),
    ];

    await Future.wait(outputTasks);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('sdkmanager failed with exit code $exitCode.');
    }

    final installed = await status();
    if (!installed.ready) {
      throw Exception('SDK installation ended, but one or more required packages are missing.');
    }

    onProgress?.call(1, 'Android SDK is ready');
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

  static Future<void> _installCommandLineTools(
    Directory root, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.01, 'Downloading Android command-line tools...');
    final request = http.Request('GET', Uri.parse(_commandLineToolsUrl));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Command-line tools download failed: HTTP ${response.statusCode}');
    }

    final temp = File('${root.path}/command-line-tools.zip.part');
    final sink = temp.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call(
          0.01 + (received / total * 0.34),
          'Downloading command-line tools ${((received / total) * 100).round()}%',
        );
      }
    }
    await sink.flush();
    await sink.close();

    onProgress?.call(0.37, 'Extracting command-line tools...');
    final archive = ZipDecoder().decodeBytes(await temp.readAsBytes());
    final latest = Directory('${root.path}/cmdline-tools/latest');
    if (await latest.exists()) await latest.delete(recursive: true);
    await latest.create(recursive: true);

    for (final entry in archive) {
      final parts = entry.name.split('/');
      final relative = parts.isNotEmpty && parts.first == 'cmdline-tools'
          ? parts.skip(1).join('/')
          : entry.name;
      if (relative.isEmpty) continue;

      final destinationPath = '${latest.path}/$relative';
      if (entry.isFile) {
        final file = File(destinationPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content as List<int>, flush: false);
      } else {
        await Directory(destinationPath).create(recursive: true);
      }
    }

    await temp.delete();
    await _makeExecutable('${latest.path}/bin/sdkmanager');
    await _makeExecutable('${latest.path}/bin/avdmanager');
    onProgress?.call(0.45, 'Command-line tools installed');
  }

  static Future<void> _makeExecutable(String path) async {
    if (!Platform.isLinux || !await File(path).exists()) return;
    final result = await Process.run('chmod', ['+x', path]);
    if (result.exitCode != 0) {
      throw Exception('Could not make $path executable: ${result.stderr}');
    }
  }

  static Future<void> _consumeLines(
    Stream<List<int>> stream,
    void Function(String line) onLine,
  ) async {
    await for (final line in stream
        .transform(SystemEncoding().decoder)
        .transform(const LineSplitter())) {
      onLine(line);
    }
  }
}
