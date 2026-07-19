import 'dart:io';

import '../../../core/runtime/native_runtime_service.dart';
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
      throw Exception('Install and select a verified JDK 17 first.');
    }

    final sdkStatus = await AndroidSdkService.status();
    if (!sdkStatus.ready) {
      throw Exception('Install and verify the Android SDK first.');
    }

    final info = await NativeRuntimeService.runtimeInfo();
    if (!info.isArm64) {
      throw UnsupportedError('DroidForge V11 supports arm64-v8a Android devices only.');
    }

    await AndroidSdkService.writeLocalProperties(projectPath);

    final rootGradlew = File('$projectPath/gradlew');
    final androidGradlew = File('$projectPath/android/gradlew');
    late final String workingDirectory;
    late final String executable;

    if (await rootGradlew.exists()) {
      workingDirectory = projectPath;
      executable = rootGradlew.path;
    } else if (await androidGradlew.exists()) {
      workingDirectory = '$projectPath/android';
      executable = androidGradlew.path;
    } else {
      throw Exception('Gradle wrapper was not found in the selected project.');
    }

    await NativeRuntimeService.chmodExecutable(executable);
    final sdkPath = sdkStatus.sdkPath;
    final result = await NativeRuntimeService.run(
      executable: '/system/bin/sh',
      arguments: [executable, 'assembleDebug', '--stacktrace'],
      workingDirectory: workingDirectory,
      environment: {
        'JAVA_HOME': javaHome,
        'GRADLE_JAVA_HOME': javaHome,
        'ANDROID_HOME': sdkPath,
        'ANDROID_SDK_ROOT': sdkPath,
        'HOME': info.filesDir,
        'TMPDIR': info.cacheDir,
        'PATH': '$javaHome/bin:$sdkPath/cmdline-tools/latest/bin:$sdkPath/platform-tools:/system/bin',
        'LD_LIBRARY_PATH': '$javaHome/lib:$javaHome/lib/server:${info.nativeLibraryDir}',
      },
    );

    final combined = '${result.stdout}\n${result.stderr}'.trim();
    for (final line in combined.split('\n')) {
      if (line.isNotEmpty) onOutput?.call(line);
    }
    return GradleBuildResult(result.exitCode, combined);
  }
}
