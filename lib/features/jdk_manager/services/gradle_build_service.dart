
import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
      throw Exception('Please install and select a JDK in JDK Manager first.');
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Gradle process execution requires DroidForge to run in the Linux/Ubuntu environment.',
      );
    }

    final gradlew = File('$projectPath/gradlew');
    final command = await gradlew.exists() ? './gradlew' : 'gradle';

    final process = await Process.start(
      'bash',
      ['-lc', '$command assembleDebug'],
      workingDirectory: projectPath,
      environment: {
        ...Platform.environment,
        'JAVA_HOME': javaHome,
        'PATH': '$javaHome/bin:${Platform.environment['PATH'] ?? ''}',
        'GRADLE_JAVA_HOME': javaHome,
      },
      runInShell: false,
    );

    final output = StringBuffer();

    Future<void> consume(Stream<List<int>> stream) async {
      await for (final chunk in stream.transform(SystemEncoding().decoder).transform(const LineSplitter())) {
        output.writeln(chunk);
        onOutput?.call(chunk);
      }
    }

    await Future.wait([consume(process.stdout), consume(process.stderr)]);
    final code = await process.exitCode;
    return GradleBuildResult(code, output.toString());
  }
}
