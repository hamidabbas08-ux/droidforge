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

class NativeRuntimeService {
  static const MethodChannel _channel =
      MethodChannel('com.hamid.droidforge/runtime');

  static Future<NativeRuntimeInfo> runtimeInfo() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('runtimeInfo');
    if (raw == null) {
      throw StateError('Android runtime bridge returned no information.');
    }
    return NativeRuntimeInfo(
      abi: raw['abi'] as String? ?? 'unknown',
      nativeLibraryDir: raw['nativeLibraryDir'] as String? ?? '',
      filesDir: raw['filesDir'] as String? ?? '',
      cacheDir: raw['cacheDir'] as String? ?? '',
      sdkInt: raw['sdkInt'] as int? ?? 0,
    );
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
}
