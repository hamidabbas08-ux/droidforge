import 'package:flutter/services.dart';

class NativeProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const NativeProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get success => exitCode == 0;
}

class NativeRuntimeInfo {
  final String abi;
  final String nativeLibraryDir;
  final String filesDir;
  final String cacheDir;
  final int sdkInt;

  const NativeRuntimeInfo({
    required this.abi,
    required this.nativeLibraryDir,
    required this.filesDir,
    required this.cacheDir,
    required this.sdkInt,
  });

  bool get isArm64 => abi == 'arm64-v8a';
}

class RuntimeFoundationReport {
  final bool ready;
  final Map<String, bool> checks;
  final Map<String, String> details;
  final List<String> logs;
  final Map<String, String> environment;
  final NativeRuntimeInfo runtimeInfo;

  const RuntimeFoundationReport({
    required this.ready,
    required this.checks,
    required this.details,
    required this.logs,
    required this.environment,
    required this.runtimeInfo,
  });
}

class NativeRuntimeService {
  static const MethodChannel _channel =
      MethodChannel('com.hamid.droidforge/runtime');

  static Future<NativeRuntimeInfo> runtimeInfo() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('runtimeInfo');
    if (raw == null) {
      throw StateError('Android runtime bridge returned no information.');
    }
    return _parseRuntimeInfo(raw);
  }

  static Future<Map<String, String>> prepareEnvironment() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('prepareEnvironment');
    if (raw == null) {
      throw StateError('Android runtime environment was not created.');
    }
    return raw.map((key, value) => MapEntry(key, value.toString()));
  }

  static Future<RuntimeFoundationReport> foundationHealthCheck() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'foundationHealthCheck',
    );
    if (raw == null) {
      throw StateError('Foundation health check returned no report.');
    }

    final checksRaw = Map<Object?, Object?>.from(
      raw['checks'] as Map? ?? const {},
    );
    final detailsRaw = Map<Object?, Object?>.from(
      raw['details'] as Map? ?? const {},
    );
    final environmentRaw = Map<Object?, Object?>.from(
      raw['environment'] as Map? ?? const {},
    );
    final runtimeRaw = Map<String, dynamic>.from(
      raw['runtimeInfo'] as Map? ?? const {},
    );

    return RuntimeFoundationReport(
      ready: raw['ready'] as bool? ?? false,
      checks: checksRaw.map(
        (key, value) => MapEntry(key.toString(), value == true),
      ),
      details: detailsRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      logs: (raw['logs'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      environment: environmentRaw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      runtimeInfo: _parseRuntimeInfo(runtimeRaw),
    );
  }

  static Future<void> requireHealthyFoundation() async {
    final report = await foundationHealthCheck();
    if (!report.ready) {
      final failed = report.checks.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .join(', ');
      throw StateError(
        'Runtime foundation is not ready. Failed checks: $failed',
      );
    }
  }

  static Future<void> chmodExecutable(String path) async {
    await _channel.invokeMethod<void>('chmodExecutable', {'path': path});
  }

  static Future<NativeProcessResult> run({
    required String executable,
    List<String> arguments = const [],
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('runProcess', {
      'executable': executable,
      'arguments': arguments,
      'workingDirectory': workingDirectory,
      'environment': environment,
    });
    if (raw == null) {
      throw StateError('Android runtime bridge returned no process result.');
    }
    return NativeProcessResult(
      exitCode: raw['exitCode'] as int? ?? -1,
      stdout: raw['stdout'] as String? ?? '',
      stderr: raw['stderr'] as String? ?? '',
    );
  }

  static NativeRuntimeInfo _parseRuntimeInfo(Map<String, dynamic> raw) {
    return NativeRuntimeInfo(
      abi: raw['abi'] as String? ?? 'unknown',
      nativeLibraryDir: raw['nativeLibraryDir'] as String? ?? '',
      filesDir: raw['filesDir'] as String? ?? '',
      cacheDir: raw['cacheDir'] as String? ?? '',
      sdkInt: raw['sdkInt'] as int? ?? 0,
    );
  }
}
