import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/process/native_process_service.dart';
import '../../android_sdk_manager/services/android_sdk_storage_service.dart';
import '../../gradle_manager/services/gradle_storage_service.dart';
import '../../jdk_manager/services/jdk_storage_service.dart';
import '../models/project_build_result.dart';
import 'project_service.dart';

typedef ProjectBuildProgress = void Function(String stage, double progress);

class ProjectBuildService {
  ProjectBuildService({
    JdkStorageService? jdkStorage,
    GradleStorageService? gradleStorage,
    AndroidSdkStorageService? sdkStorage,
    NativeProcessService processService = const NativeProcessService(),
  }) : _jdkStorage = jdkStorage ?? JdkStorageService(),
       _gradleStorage = gradleStorage ?? GradleStorageService(),
       _sdkStorage = sdkStorage ?? AndroidSdkStorageService(),
       _processService = processService;

  final JdkStorageService _jdkStorage;
  final GradleStorageService _gradleStorage;
  final AndroidSdkStorageService _sdkStorage;
  final NativeProcessService _processService;

  Future<ProjectBuildResult> build({
    required String projectName,
    required ProjectBuildType type,
    required ProjectBuildProgress onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'DroidForge project builds are supported only on Android.',
      );
    }

    final normalizedName = projectName.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        projectName,
        'projectName',
        'Project name cannot be empty.',
      );
    }

    onProgress('Checking project', 0.05);

    final projectDirectory = await ProjectService.getProjectDirectory(
      normalizedName,
    );

    if (!await projectDirectory.exists()) {
      throw StateError(
        'Project directory does not exist: ${projectDirectory.path}',
      );
    }

    await _validateProject(projectDirectory);

    onProgress('Checking JDK', 0.12);

    final activeJdkVersion = await _jdkStorage.readActiveVersion();

    if (activeJdkVersion == null) {
      throw StateError(
        'No active JDK selected. Select JDK 17 before building.',
      );
    }

    final jdkPath = await _jdkStorage.getInstalledPath(activeJdkVersion);

    if (jdkPath == null) {
      throw StateError(
        'Active JDK $activeJdkVersion is not installed correctly.',
      );
    }

    onProgress('Checking Gradle', 0.20);

    final activeGradleVersion = await _gradleStorage.readActiveVersion();

    if (activeGradleVersion == null || activeGradleVersion.trim().isEmpty) {
      throw StateError('No active Gradle version selected.');
    }

    final gradlePath = await _gradleStorage.getInstalledPath(
      activeGradleVersion,
    );

    if (gradlePath == null) {
      throw StateError(
        'Active Gradle $activeGradleVersion is not installed correctly.',
      );
    }

    final gradleExecutable = File('$gradlePath/bin/gradle');

    if (!await gradleExecutable.exists()) {
      throw StateError('Gradle launcher is missing: ${gradleExecutable.path}');
    }

    onProgress('Checking Android SDK', 0.28);

    final sdkPath = await _sdkStorage.getInstalledPath();

    if (sdkPath == null) {
      throw StateError('Android SDK 35 is not installed correctly.');
    }

    await _writeLocalProperties(
      projectDirectory: projectDirectory,
      sdkPath: sdkPath,
    );

    final supportDirectory = await getApplicationSupportDirectory();

    final gradleUserHome = Directory(
      '${supportDirectory.path}/DroidForge/'
      'build-cache/gradle-user-home',
    );

    final temporaryDirectory = Directory(
      '${supportDirectory.path}/DroidForge/build-cache/tmp',
    );

    await gradleUserHome.create(recursive: true);
    await temporaryDirectory.create(recursive: true);

    await _makeExecutable(gradleExecutable);

    onProgress('Running ${type.displayName} build', 0.35);

    final environment = <String, String>{
      'JAVA_HOME': jdkPath,
      'ANDROID_HOME': sdkPath,
      'ANDROID_SDK_ROOT': sdkPath,
      'GRADLE_HOME': gradlePath,
      'GRADLE_USER_HOME': gradleUserHome.path,
      'HOME': supportDirectory.path,
      'TMPDIR': temporaryDirectory.path,
      'PATH': [
        '$jdkPath/bin',
        '$gradlePath/bin',
        '$sdkPath/build-tools/35.0.0',
        '$sdkPath/platform-tools',
        '/system/bin',
        '/system/xbin',
      ].join(':'),
      'LD_LIBRARY_PATH': ['$jdkPath/lib', '$jdkPath/lib/server'].join(':'),
    };

    final result = await _processService.run(
      executable: '/system/bin/sh',
      arguments: <String>[
        gradleExecutable.path,
        '--no-daemon',
        '--stacktrace',
        '--console=plain',
        type.gradleTask,
      ],
      workingDirectory: projectDirectory.path,
      environment: environment,
      timeout: const Duration(minutes: 30),
    );

    if (!result.succeeded) {
      final reason = result.timedOut
          ? 'Build timed out after 30 minutes.'
          : 'Gradle exited with code ${result.exitCode}.';

      final output = result.combinedOutput;

      throw StateError(
        '$reason'
        '${output.trim().isEmpty ? '' : '\n\n$output'}',
      );
    }

    onProgress('Checking build output', 0.95);

    final outputFile = File(
      '${projectDirectory.path}/${type.relativeOutputPath}',
    );

    if (!await outputFile.exists()) {
      throw StateError(
        '${type.displayName} completed but output file was not found: '
        '${outputFile.path}',
      );
    }

    if (await outputFile.length() <= 0) {
      throw StateError('Generated ${type.displayName} file is empty.');
    }

    onProgress('${type.displayName} ready', 1);

    return ProjectBuildResult(
      type: type,
      processResult: result,
      outputPath: outputFile.path,
    );
  }

  Future<void> _validateProject(Directory projectDirectory) async {
    final requiredFiles = <String>[
      'settings.gradle.kts',
      'build.gradle.kts',
      'app/build.gradle.kts',
      'app/src/main/AndroidManifest.xml',
    ];

    final missing = <String>[];

    for (final relativePath in requiredFiles) {
      final file = File('${projectDirectory.path}/$relativePath');

      if (!await file.exists()) {
        missing.add(relativePath);
      }
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Kotlin Android project is incomplete. '
        'Missing: ${missing.join(', ')}',
      );
    }
  }

  Future<void> _writeLocalProperties({
    required Directory projectDirectory,
    required String sdkPath,
  }) async {
    final localProperties = File('${projectDirectory.path}/local.properties');

    final escapedSdkPath = sdkPath
        .replaceAll(r'\', r'\\')
        .replaceAll(':', r'\:');

    await localProperties.writeAsString(
      'sdk.dir=$escapedSdkPath\n',
      flush: true,
    );
  }

  Future<void> _makeExecutable(File file) async {
    final result = await _processService.run(
      executable: '/system/bin/chmod',
      arguments: <String>['700', file.path],
      timeout: const Duration(seconds: 15),
    );

    if (!result.succeeded) {
      throw StateError(
        'Failed to make Gradle executable: ${file.path}. '
        '${result.combinedOutput}',
      );
    }
  }
}
