import 'package:flutter/services.dart';

import 'process_result.dart';

class NativeProcessService {
  const NativeProcessService();

  static const MethodChannel _channel = MethodChannel(
    'com.hamid.droidforge/process',
  );

  Future<String> getBundledPointerTagDisablerPath() async {
    final path = await _channel.invokeMethod<String>(
      'getBundledPointerTagDisablerPath',
    );

    if (path == null || path.trim().isEmpty) {
      throw StateError('Bundled pointer-tag disabler path was not returned.');
    }

    return path;
  }

  Future<String> getBundledJavaShimPath() async {
    final path = await _channel.invokeMethod<String>('getBundledJavaShimPath');

    if (path == null || path.trim().isEmpty) {
      throw StateError('Bundled Java shim path was not returned.');
    }

    return path;
  }

  Future<String> getBundledAapt2ShimPath() async {
    final path = await _channel.invokeMethod<String>('getBundledAapt2ShimPath');

    if (path == null || path.trim().isEmpty) {
      throw StateError('Bundled AAPT2 shim path was not returned.');
    }

    return path;
  }

  Future<String> getBundledAapt2AgentPath() async {
    final path = await _channel.invokeMethod<String>(
      'getBundledAapt2AgentPath',
    );

    if (path == null || path.trim().isEmpty) {
      throw StateError('Bundled AAPT2 agent path was not returned.');
    }

    return path;
  }

  Future<ProcessExecutionResult> runBundledNativeTest() async {
    final rawResult = await _channel.invokeMethod<Object?>(
      'runBundledNativeTest',
    );

    if (rawResult is! Map) {
      throw StateError('Bundled native test returned an invalid response.');
    }

    return ProcessExecutionResult.fromMap(rawResult);
  }

  Future<ProcessExecutionResult> runAndroidElf({
    required String executable,
    List<String> arguments = const <String>[],
    String? workingDirectory,
    Map<String, String> environment = const <String, String>{},
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (executable.trim().isEmpty) {
      throw ArgumentError.value(
        executable,
        'executable',
        'Executable path cannot be empty.',
      );
    }

    return run(
      executable: '/system/bin/linker64',
      arguments: <String>[executable, executable, ...arguments],
      workingDirectory: workingDirectory,
      environment: environment,
      timeout: timeout,
    );
  }

  Future<ProcessExecutionResult> run({
    required String executable,
    List<String> arguments = const <String>[],
    String? workingDirectory,
    Map<String, String> environment = const <String, String>{},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (executable.trim().isEmpty) {
      throw ArgumentError.value(
        executable,
        'executable',
        'Executable path cannot be empty.',
      );
    }

    final rawResult = await _channel
        .invokeMethod<Object?>('runProcess', <String, Object?>{
          'executable': executable,
          'arguments': arguments,
          'workingDirectory': workingDirectory,
          'environment': environment,
          'timeoutSeconds': timeout.inSeconds.clamp(1, 3600),
        });

    if (rawResult is! Map) {
      throw StateError('Native process runner returned an invalid response.');
    }

    return ProcessExecutionResult.fromMap(rawResult);
  }
}
