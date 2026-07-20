class ProcessExecutionResult {
  const ProcessExecutionResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
    required this.durationMs,
  });

  factory ProcessExecutionResult.fromMap(Map<Object?, Object?> map) {
    final rawCommand = map['command'];

    return ProcessExecutionResult(
      command: rawCommand is List
          ? rawCommand.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      exitCode: (map['exitCode'] as num?)?.toInt() ?? -1,
      stdout: map['stdout']?.toString() ?? '',
      stderr: map['stderr']?.toString() ?? '',
      timedOut: map['timedOut'] == true,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  final List<String> command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final int durationMs;

  bool get succeeded => !timedOut && exitCode == 0;

  String get combinedOutput {
    return <String>[
      if (stdout.trim().isNotEmpty) stdout.trim(),
      if (stderr.trim().isNotEmpty) stderr.trim(),
    ].join('\n');
  }
}
