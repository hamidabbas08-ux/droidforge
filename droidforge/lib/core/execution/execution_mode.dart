enum ExecutionMode {
  automatic,
  androidLocal,
  linuxDirect,
  termuxBridge,
  prootUbuntu,
}

extension ExecutionModeInfo on ExecutionMode {
  String get label => switch (this) {
        ExecutionMode.automatic => 'Automatic',
        ExecutionMode.androidLocal => 'Android local shell',
        ExecutionMode.linuxDirect => 'Linux / Ubuntu direct',
        ExecutionMode.termuxBridge => 'Termux bridge',
        ExecutionMode.prootUbuntu => 'Ubuntu PRoot through Termux',
      };

  String get description => switch (this) {
        ExecutionMode.automatic => 'Choose the safest mode for the current platform.',
        ExecutionMode.androidLocal => 'Runs Android system shell commands only.',
        ExecutionMode.linuxDirect => 'Runs commands directly when DroidForge itself is a Linux app.',
        ExecutionMode.termuxBridge => 'Runs commands in Termux. Requires the DroidForge Termux bridge.',
        ExecutionMode.prootUbuntu => 'Runs commands inside the Ubuntu PRoot distribution through Termux.',
      };
}
