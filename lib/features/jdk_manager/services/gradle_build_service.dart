import 'dart:convert';
import 'dart:async';
import 'dart:io';

import '../../sdk_manager/services/android_sdk_service.dart';
import 'jdk_service.dart';

class GradleBuildResult {
  final int exitCode;
  final String output;

  const GradleBuildResult(this.exitCode, this.output);

  bool get success => exitCode == 0;
}

class GradleBuildService {
  static Future<GradleBuildResult> assembleDebug({
    required String projectPath,
    void Function(String line)? onOutput,
  }) async {
    final javaHome = await JdkService.activeJavaHome();
    if (javaHome == null) {
      throw Exception('Install and select a JDK in JDK Manager first.');
    }

    final sdkStatus = await AndroidSdkService.status();
    if (!sdkStatus.ready) {
      throw Exception('Install the required packages in Android SDK Manager first.');
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Gradle process execution requires DroidForge to run in Linux/Ubuntu.',
      );
    }

    await AndroidSdkService.writeLocalProperties(projectPath);

    final rootGradlew = File('$projectPath/gradlew');
    final androidGradlew = File('$projectPath/android/gradlew');
    late final String workingDirectory;
    late final String command;

    if (await rootGradlew.exists()) {
      workingDirectory = projectPath;
      command = './gradlew';
      await Process.run('chmod', ['+x', rootGradlew.path]);
    } else if (await androidGradlew.exists()) {
      workingDirectory = '$projectPath/android';
      command = './gradlew';
      await Process.run('chmod', ['+x', androidGradlew.path]);
    } else {
      workingDirectory = projectPath;
      command = 'gradle';
    }

    final sdkPath = sdkStatus.sdkPath;
    final process = await Process.start(
      'bash',
      ['-lc', '$command assembleDebug'],
      workingDirectory: workingDirectory,
      environment: {
        ...Platform.environment,
        'JAVA_HOME': javaHome,
        'GRADLE_JAVA_HOME': javaHome,
        'ANDROID_HOME': sdkPath,
        // Kept for compatibility with tools that still read the old name.
        'ANDROID_SDK_ROOT': sdkPath,
        'PATH': '$javaHome/bin:$sdkPath/cmdline-tools/latest/bin:'
            '$sdkPath/platform-tools:${Platform.environment['PATH'] ?? ''}',
      },
      runInShell: false,
    );

    final output = StringBuffer();

    Future<void> consume(Stream<List<int>> stream) async {
      await for (final chunk in stream
          .transform(SystemEncoding().decoder)
          .transform(const LineSplitter())) {
        output.writeln(chunk);
        onOutput?.call(chunk);
      }
    }

    await Future.wait([consume(process.stdout), consume(process.stderr)]);
    final code = await process.exitCode;
    return GradleBuildResult(code, output.toString());
  }
}
