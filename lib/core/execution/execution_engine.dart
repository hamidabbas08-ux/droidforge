import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'execution_mode.dart';
import 'execution_settings.dart';

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
    final saved = await ExecutionSettings.load();
    if (saved != ExecutionMode.automatic) return saved;
    if (Platform.isLinux) return ExecutionMode.linuxDirect;
    if (Platform.isAndroid) return ExecutionMode.androidLocal;
    return ExecutionMode.automatic;
  }

  static Future<String> supportMessage() async {
    final mode = await resolvedMode();
    return switch (mode) {
      ExecutionMode.linuxDirect => 'Commands run directly in Linux/Ubuntu.',
      ExecutionMode.androidLocal =>
        'Android local mode can run /system/bin/sh commands, but it cannot access Termux or Ubuntu files.',
      ExecutionMode.termuxBridge =>
        'Termux bridge is selected. The native bridge must be installed before commands can run.',
      ExecutionMode.prootUbuntu =>
        'Ubuntu PRoot mode is selected. It requires the Termux bridge and the Ubuntu distribution name/path.',
      ExecutionMode.automatic => 'No compatible execution mode was detected.',
    };
  }

  static Future<ExecutionResult> run({
    required String command,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onOutput,
  }) async {
    final mode = await resolvedMode();
    switch (mode) {
      case ExecutionMode.linuxDirect:
        return _runProcess(
          command: command,
          arguments: arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          onOutput: onOutput,
        );
      case ExecutionMode.androidLocal:
        if (!Platform.isAndroid) {
          throw UnsupportedError('Android local mode requires Android.');
        }
        final shellCommand = _shellJoin(command, arguments);
        return _runProcess(
          command: '/system/bin/sh',
          arguments: ['-c', shellCommand],
          workingDirectory: workingDirectory,
          environment: environment,
          onOutput: onOutput,
        );
      case ExecutionMode.termuxBridge:
      case ExecutionMode.prootUbuntu:
        throw UnsupportedError(
          'The Termux/Ubuntu bridge is selected but is not installed in this build yet. '
          'Do not replace Platform.isLinux with Platform.isAndroid: an Android APK and Ubuntu PRoot are separate sandboxes.',
        );
      case ExecutionMode.automatic:
        throw UnsupportedError('No compatible execution mode is available.');
    }
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
