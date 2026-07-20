import 'package:flutter/services.dart';

import 'process_result.dart';

class NativeProcessService {
  const NativeProcessService();

  static const MethodChannel _channel = MethodChannel(
    'com.hamid.droidforge/process',
  );

  Future<ProcessExecutionResult> runBundledNativeTest() async {
    final rawResult = await _channel.invokeMethod<Object?>(
      'runBundledNativeTest',
    );

    if (rawResult is! Map) {
      throw StateError('Bundled native test returned an invalid response.');
    }

    return ProcessExecutionResult.fromMap(rawResult);
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
