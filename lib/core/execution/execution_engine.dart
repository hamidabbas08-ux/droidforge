import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'execution_mode.dart';

class ExecutionResult {
  final int exitCode;
  final String stdoutText;
  final String stderrText;

  const ExecutionResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  bool get success => exitCode == 0;
}

class ExecutionEngine {
  static Future<ExecutionMode> resolvedMode() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('DroidForge runs on Android only.');
    }
    return ExecutionMode.androidLocal;
  }

  static Future<String> supportMessage() async {
    await resolvedMode();
    return 'Android local execution is active.';
  }

  static Future<ExecutionResult> run({
    required String command,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  }) async {
    await resolvedMode();
    final shellCommand = _shellJoin(command, arguments);
    return _runProcess(
      command: '/system/bin/sh',
      arguments: ['-c', shellCommand],
      workingDirectory: workingDirectory,
      environment: environment,
      onOutput: onOutput,
    );
  }

  static Future<ExecutionResult> _runProcess({
    required String command,
    required List<String> arguments,
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  }) async {
    final process = await Process.start(
      command,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );
    final out = StringBuffer();
    final err = StringBuffer();

    Future<void> consume(Stream<List<int>> stream, StringBuffer target) async {
      await for (final line in stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        target.writeln(line);
        onOutput?.call(line);
      }
    }

    await Future.wait([
      consume(process.stdout, out),
      consume(process.stderr, err),
    ]);
    final exitCode = await process.exitCode;
    return ExecutionResult(
      exitCode: exitCode,
      stdoutText: out.toString(),
      stderrText: err.toString(),
    );
  }

  static String _shellJoin(String command, List<String> arguments) {
    String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    return ([command, ...arguments].map(quote)).join(' ');
  }
}
