import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'execution_mode.dart';

class ExecutionSettings {
  static Future<File> _settingsFile() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/DroidForge');
    await dir.create(recursive: true);
    return File('${dir.path}/execution_mode.txt');
  }

  static Future<ExecutionMode> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) return ExecutionMode.automatic;
    final value = (await file.readAsString()).trim();
    return ExecutionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ExecutionMode.automatic,
    );
  }

  static Future<void> save(ExecutionMode mode) async {
    await (await _settingsFile()).writeAsString(mode.name, flush: true);
  }
}
