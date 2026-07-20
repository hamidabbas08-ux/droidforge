enum JdkInstallState {
  notInstalled,
  downloading,
  verifying,
  extracting,
  installed,
  active,
  failed,
}

class JdkInstallation {
  const JdkInstallation({
    required this.version,
    required this.displayName,
    required this.state,
    this.progress = 0,
    this.installPath,
    this.error,
  });

  final int version;
  final String displayName;
  final JdkInstallState state;
  final double progress;
  final String? installPath;
  final String? error;

  bool get isInstalled =>
      state == JdkInstallState.installed || state == JdkInstallState.active;

  bool get isActive => state == JdkInstallState.active;

  JdkInstallation copyWith({
    JdkInstallState? state,
    double? progress,
    String? installPath,
    String? error,
    bool clearError = false,
  }) {
    return JdkInstallation(
      version: version,
      displayName: displayName,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      installPath: installPath ?? this.installPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}
