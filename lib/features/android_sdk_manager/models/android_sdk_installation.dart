enum AndroidSdkInstallState {
  notInstalled,
  downloading,
  verifying,
  extracting,
  installed,
  active,
  failed,
}

class AndroidSdkInstallation {
  const AndroidSdkInstallation({
    required this.state,
    this.progress = 0,
    this.installPath,
    this.error,
  });

  final AndroidSdkInstallState state;
  final double progress;
  final String? installPath;
  final String? error;

  bool get isInstalled =>
      state == AndroidSdkInstallState.installed ||
      state == AndroidSdkInstallState.active;

  bool get isActive => state == AndroidSdkInstallState.active;

  AndroidSdkInstallation copyWith({
    AndroidSdkInstallState? state,
    double? progress,
    String? installPath,
    String? error,
    bool clearError = false,
  }) {
    return AndroidSdkInstallation(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      installPath: installPath ?? this.installPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}
