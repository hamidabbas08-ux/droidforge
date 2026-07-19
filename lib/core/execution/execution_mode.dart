enum ExecutionMode {
  androidLocal,
}

extension ExecutionModeInfo on ExecutionMode {
  String get label => 'Android local shell';

  String get description =>
      'Runs commands inside DroidForge on the Android device.';
}
