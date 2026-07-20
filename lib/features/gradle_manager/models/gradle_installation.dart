enum GradleInstallState {
  notInstalled,
  downloading,
  verifying,
  extracting,
  testing,
  installed,
  active,
  failed,
}

class GradleInstallation {
  const GradleInstallation({
    required this.version,
    required this.displayName,
    required this.state,
    this.progress = 0,
    this.installPath,
    this.error,
  });

  final String version;
  final String displayName;
  final GradleInstallState state;
  final double progress;
  final String? installPath;
  final String? error;

  bool get isInstalled =>
      state == GradleInstallState.installed ||
      state == GradleInstallState.active;

  bool get isActive => state == GradleInstallState.active;

  GradleInstallation copyWith({
    GradleInstallState? state,
    double? progress,
    String? installPath,
    String? error,
    bool clearError = false,
  }) {
    return GradleInstallation(
      version: version,
      displayName: displayName,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      installPath: installPath ?? this.installPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}
