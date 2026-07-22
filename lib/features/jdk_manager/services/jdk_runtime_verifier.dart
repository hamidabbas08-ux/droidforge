import 'dart:io';

import '../../../core/process/native_process_service.dart';
import '../../../core/process/process_result.dart';

class JdkRuntimeVerification {
  const JdkRuntimeVerification({
    required this.javaResult,
    required this.javacResult,
  });

  final ProcessExecutionResult javaResult;
  final ProcessExecutionResult javacResult;

  bool get succeeded => javaResult.succeeded && javacResult.succeeded;

  String get javaVersion => javaResult.combinedOutput;

  String get javacVersion => javacResult.combinedOutput;
}

class JdkRuntimeVerifier {
  const JdkRuntimeVerifier({
    NativeProcessService processService = const NativeProcessService(),
  }) : _processService = processService;

  final NativeProcessService _processService;

  Future<JdkRuntimeVerification> verify(String jdkPath) async {
    final directory = Directory(jdkPath);
    final javaFile = File('$jdkPath/bin/java');
    final javacFile = File('$jdkPath/bin/javac');

    if (!await directory.exists()) {
      throw StateError('JDK directory does not exist: $jdkPath');
    }

    if (!await javaFile.exists()) {
      throw StateError('Java executable is missing: ${javaFile.path}');
    }

    if (!await javacFile.exists()) {
      throw StateError('Javac executable is missing: ${javacFile.path}');
    }

    await _makeExecutable(javaFile);
    await _makeExecutable(javacFile);

    final environment = <String, String>{
      'JAVA_HOME': jdkPath,
      'HOME': jdkPath,
      'PATH': '$jdkPath/bin:/system/bin:/system/xbin',
      'TMPDIR': Directory.systemTemp.path,
      'LD_LIBRARY_PATH':
          '$jdkPath/lib/droidforge-deps:$jdkPath/lib:$jdkPath/lib/server',
    };

    final javaResult = await _processService.runAndroidElf(
      executable: javaFile.path,
      arguments: const <String>['-version'],
      workingDirectory: jdkPath,
      environment: environment,
      timeout: const Duration(seconds: 30),
    );

    if (!javaResult.succeeded) {
      throw StateError(_failureMessage('java -version', javaResult));
    }

    final javacResult = await _processService.runAndroidElf(
      executable: javacFile.path,
      arguments: const <String>['-version'],
      workingDirectory: jdkPath,
      environment: environment,
      timeout: const Duration(seconds: 30),
    );

    if (!javacResult.succeeded) {
      throw StateError(_failureMessage('javac -version', javacResult));
    }

    return JdkRuntimeVerification(
      javaResult: javaResult,
      javacResult: javacResult,
    );
  }

  Future<void> _makeExecutable(File file) async {
    final result = await _processService.run(
      executable: '/system/bin/chmod',
      arguments: <String>['700', file.path],
      timeout: const Duration(seconds: 10),
    );

    if (!result.succeeded) {
      throw StateError(
        'Failed to make executable: ${file.path}. '
        '${result.combinedOutput}',
      );
    }
  }

  String _failureMessage(String command, ProcessExecutionResult result) {
    if (result.timedOut) {
      return '$command timed out.';
    }

    final output = result.combinedOutput;

    return '$command failed with exit code ${result.exitCode}.'
        '${output.isEmpty ? '' : ' $output'}';
  }
}
