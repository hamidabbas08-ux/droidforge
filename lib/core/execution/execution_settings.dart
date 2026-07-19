import 'execution_mode.dart';

class ExecutionSettings {
  static Future<ExecutionMode> load() async => ExecutionMode.androidLocal;

  static Future<void> save(ExecutionMode mode) async {
    // DroidForge V8 is Android-only, so there is no selectable execution mode.
  }
}
