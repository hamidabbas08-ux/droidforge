import '../../../core/process/process_result.dart';

enum ProjectBuildType { debugApk, releaseApk, releaseAab }

extension ProjectBuildTypeDetails on ProjectBuildType {
  String get gradleTask {
    return switch (this) {
      ProjectBuildType.debugApk => 'assembleDebug',
      ProjectBuildType.releaseApk => 'assembleRelease',
      ProjectBuildType.releaseAab => 'bundleRelease',
    };
  }

  String get displayName {
    return switch (this) {
      ProjectBuildType.debugApk => 'Debug APK',
      ProjectBuildType.releaseApk => 'Release APK',
      ProjectBuildType.releaseAab => 'Release AAB',
    };
  }

  String get relativeOutputPath {
    return switch (this) {
      ProjectBuildType.debugApk => 'app/build/outputs/apk/debug/app-debug.apk',
      ProjectBuildType.releaseApk =>
        'app/build/outputs/apk/release/app-release.apk',
      ProjectBuildType.releaseAab =>
        'app/build/outputs/bundle/release/app-release.aab',
    };
  }
}

class ProjectBuildResult {
  const ProjectBuildResult({
    required this.type,
    required this.processResult,
    required this.outputPath,
  });

  final ProjectBuildType type;
  final ProcessExecutionResult processResult;
  final String outputPath;

  bool get succeeded => processResult.succeeded;
}
