import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/process/native_process_service.dart';
import '../../../core/process/process_result.dart';
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
    await _ensureProjectRepositories(projectDirectory);

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
    final gradleLauncher = File(
      '$gradlePath/lib/gradle-launcher-$activeGradleVersion.jar',
    );

    final gradleInstrumentationAgent = File(
      '$gradlePath/lib/agents/'
      'gradle-instrumentation-agent-$activeGradleVersion.jar',
    );

    final javaExecutable = File('$jdkPath/bin/java');
    final javacExecutable = File('$jdkPath/bin/javac');

    if (!await gradleExecutable.exists()) {
      throw StateError(
        'Gradle launcher script is missing: ${gradleExecutable.path}',
      );
    }

    if (!await gradleLauncher.exists()) {
      throw StateError(
        'Gradle launcher JAR is missing: ${gradleLauncher.path}',
      );
    }

    if (!await gradleInstrumentationAgent.exists()) {
      throw StateError(
        'Gradle instrumentation agent is missing: '
        '${gradleInstrumentationAgent.path}',
      );
    }

    if (!await javaExecutable.exists()) {
      throw StateError('Java executable is missing: ${javaExecutable.path}');
    }

    if (!await javacExecutable.exists()) {
      throw StateError('Java compiler is missing: ${javacExecutable.path}');
    }

    onProgress('Preparing Android linker runtime', 0.24);

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

    final javaShimPath = await _processService.getBundledJavaShimPath();

    final syntheticJdkPath = await _prepareSyntheticJdkHome(
      supportDirectory: supportDirectory,
      realJdkPath: jdkPath,
      javaShimPath: javaShimPath,
    );

    final gradleUserHome = Directory(
      '${supportDirectory.path}/DroidForge/'
      'build-cache/gradle-user-home',
    );

    final temporaryDirectory = Directory(
      '${supportDirectory.path}/DroidForge/build-cache/tmp',
    );

    await gradleUserHome.create(recursive: true);
    await temporaryDirectory.create(recursive: true);

    final gradleJvmArguments = <String>[
      '--add-opens=java.base/java.util=ALL-UNNAMED',
      '--add-opens=java.base/java.lang=ALL-UNNAMED',
      '--add-opens=java.base/java.lang.invoke=ALL-UNNAMED',
      '--add-opens=java.prefs/java.util.prefs=ALL-UNNAMED',
      '--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED',
      '--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED',
      '--add-opens=java.base/java.nio.charset=ALL-UNNAMED',
      '--add-opens=java.base/java.net=ALL-UNNAMED',
      '--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED',
      '-XX:MaxMetaspaceSize=384m',
      '-XX:+HeapDumpOnOutOfMemoryError',
      '-Xms256m',
      '-Xmx512m',
      '-Dfile.encoding=UTF-8',
      '-Djava.io.tmpdir=${temporaryDirectory.path}',
      '-Duser.country',
      '-Duser.language=en',
      '-Duser.variant',
      '-javaagent:${gradleInstrumentationAgent.path}',
    ];

    await _writeAndroidGradleProperties(projectDirectory);

    onProgress('Running ${type.displayName} build', 0.35);

    final pointerTagDisablerPath = await _processService
        .getBundledPointerTagDisablerPath();

    final environment = <String, String>{
      'JAVA_HOME': syntheticJdkPath,
      'DROIDFORGE_REAL_JAVA': javaExecutable.path,
      'LD_PRELOAD': pointerTagDisablerPath,
      'LD_LIBRARY_PATH':
          '$jdkPath/lib/droidforge-deps:$jdkPath/lib:$jdkPath/lib/server',
      'ANDROID_HOME': sdkPath,
      'ANDROID_SDK_ROOT': sdkPath,
      'GRADLE_HOME': gradlePath,
      'GRADLE_USER_HOME': gradleUserHome.path,
      'HOME': supportDirectory.path,
      'TMPDIR': temporaryDirectory.path,
      'PATH': [
        '$syntheticJdkPath/bin',
        '$jdkPath/bin',
        '$gradlePath/bin',
        '$sdkPath/build-tools/35.0.0',
        '$sdkPath/platform-tools',
        '/system/bin',
        '/system/xbin',
      ].join(':'),
    };

    final result = await _processService.run(
      executable: javaShimPath,
      arguments: <String>[
        ...gradleJvmArguments,
        '-Dorg.gradle.daemon=false',
        '-Dorg.gradle.native=false',
        '-Dorg.gradle.vfs.watch=false',
        '-Dorg.gradle.workers.max=1',
        '-classpath',
        gradleLauncher.path,
        'org.gradle.launcher.GradleMain',
        '--no-daemon',
        '--stacktrace',
        '--info',
        '--console=plain',
        '--no-watch-fs',
        '--max-workers=1',
        '--project-dir',
        projectDirectory.path,
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

  Future<String> runRuntimeDiagnostic({
    required String projectName,
    required ProjectBuildProgress onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Runtime diagnostic is supported only on Android.',
      );
    }

    final projectDirectory = await ProjectService.getProjectDirectory(
      projectName.trim(),
    );

    if (!await projectDirectory.exists()) {
      throw StateError(
        'Project directory does not exist: ${projectDirectory.path}',
      );
    }

    onProgress('Checking active JDK', 0.08);

    final activeJdkVersion = await _jdkStorage.readActiveVersion();

    if (activeJdkVersion == null) {
      throw StateError('No active JDK selected.');
    }

    final jdkPath = await _jdkStorage.getInstalledPath(activeJdkVersion);

    if (jdkPath == null) {
      throw StateError(
        'Active JDK $activeJdkVersion is not installed correctly.',
      );
    }

    onProgress('Checking active Gradle', 0.16);

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

    final javaExecutable = File('$jdkPath/bin/java');
    final javacExecutable = File('$jdkPath/bin/javac');
    final gradleLauncher = File(
      '$gradlePath/lib/gradle-launcher-$activeGradleVersion.jar',
    );

    if (!await javaExecutable.exists()) {
      throw StateError('Java executable is missing: ${javaExecutable.path}');
    }

    if (!await javacExecutable.exists()) {
      throw StateError('Javac executable is missing: ${javacExecutable.path}');
    }

    if (!await gradleLauncher.exists()) {
      throw StateError(
        'Gradle launcher JAR is missing: ${gradleLauncher.path}',
      );
    }

    final supportDirectory = await getApplicationSupportDirectory();

    final diagnosticDirectory = Directory(
      '${supportDirectory.path}/DroidForge/'
      'runtime-diagnostic',
    );

    final temporaryDirectory = Directory('${diagnosticDirectory.path}/tmp');

    final gradleUserHome = Directory(
      '${diagnosticDirectory.path}/gradle-user-home',
    );

    await temporaryDirectory.create(recursive: true);
    await gradleUserHome.create(recursive: true);

    final pointerTagDisablerPath = await _processService
        .getBundledPointerTagDisablerPath();

    final environment = <String, String>{
      'JAVA_HOME': jdkPath,
      'LD_PRELOAD': pointerTagDisablerPath,
      'LD_LIBRARY_PATH':
          '$jdkPath/lib/droidforge-deps:$jdkPath/lib:$jdkPath/lib/server',
      'GRADLE_HOME': gradlePath,
      'GRADLE_USER_HOME': gradleUserHome.path,
      'HOME': diagnosticDirectory.path,
      'TMPDIR': temporaryDirectory.path,
      'PATH': <String>[
        '$jdkPath/bin',
        '$gradlePath/bin',
        '/system/bin',
        '/system/xbin',
      ].join(':'),
    };

    final report = StringBuffer()
      ..writeln('DROIDFORGE RUNTIME DIAGNOSTIC')
      ..writeln('================================')
      ..writeln('Project: ${projectDirectory.path}')
      ..writeln('JDK: $jdkPath')
      ..writeln('Gradle: $gradlePath')
      ..writeln('Gradle launcher: ${gradleLauncher.path}')
      ..writeln('Pointer-tag disabler: $pointerTagDisablerPath')
      ..writeln('LD_PRELOAD: ${environment['LD_PRELOAD']}')
      ..writeln();

    onProgress('Testing java -version', 0.28);

    final javaResult = await _processService.runAndroidElf(
      executable: javaExecutable.path,
      arguments: const <String>['-version'],
      workingDirectory: diagnosticDirectory.path,
      environment: environment,
      timeout: const Duration(seconds: 45),
    );

    _appendDiagnosticResult(
      report: report,
      title: 'TEST 1 — JAVA VERSION',
      result: javaResult,
    );

    onProgress('Testing javac -version', 0.48);

    final javacResult = await _processService.runAndroidElf(
      executable: javacExecutable.path,
      arguments: const <String>['-version'],
      workingDirectory: diagnosticDirectory.path,
      environment: environment,
      timeout: const Duration(seconds: 45),
    );

    _appendDiagnosticResult(
      report: report,
      title: 'TEST 2 — JAVAC VERSION',
      result: javacResult,
    );

    onProgress('Testing Gradle launcher', 0.68);

    final gradleResult = await _processService.runAndroidElf(
      executable: javaExecutable.path,
      arguments: <String>[
        '-Xmx512m',
        '-Xint',
        '-Dfile.encoding=UTF-8',
        '-Djava.io.tmpdir=${temporaryDirectory.path}',
        '-Duser.home=${diagnosticDirectory.path}',
        '-Dorg.gradle.daemon=false',
        '-Dorg.gradle.native=false',
        '-Dorg.gradle.vfs.watch=false',
        '-Dorg.gradle.workers.max=1',
        '-classpath',
        gradleLauncher.path,
        'org.gradle.launcher.GradleMain',
        '--version',
        '--no-daemon',
        '--no-watch-fs',
        '--console=plain',
      ],
      workingDirectory: projectDirectory.path,
      environment: environment,
      timeout: const Duration(minutes: 3),
    );

    _appendDiagnosticResult(
      report: report,
      title: 'TEST 3 — GRADLE LAUNCHER VERSION',
      result: gradleResult,
    );

    onProgress('Testing packaged Java shim', 0.86);

    final javaShimPath = await _processService.getBundledJavaShimPath();

    final javaShimResult = await _processService.run(
      executable: javaShimPath,
      arguments: const <String>['-version'],
      workingDirectory: diagnosticDirectory.path,
      environment: <String, String>{
        ...environment,
        'DROIDFORGE_REAL_JAVA': javaExecutable.path,
      },
      timeout: const Duration(seconds: 45),
    );

    _appendDiagnosticResult(
      report: report,
      title: 'TEST 4 — PACKAGED JAVA SHIM',
      result: javaShimResult,
    );

    onProgress('Diagnostic complete', 1);

    report
      ..writeln('DIAGNOSTIC SUMMARY')
      ..writeln('================================')
      ..writeln('java -version: ${_diagnosticStatus(javaResult)}')
      ..writeln('javac -version: ${_diagnosticStatus(javacResult)}')
      ..writeln('Gradle launcher: ${_diagnosticStatus(gradleResult)}')
      ..writeln('Packaged Java shim: ${_diagnosticStatus(javaShimResult)}');

    return report.toString().trim();
  }

  void _appendDiagnosticResult({
    required StringBuffer report,
    required String title,
    required ProcessExecutionResult result,
  }) {
    report
      ..writeln(title)
      ..writeln('--------------------------------')
      ..writeln('Command:')
      ..writeln(result.command.join(' '))
      ..writeln()
      ..writeln('Exit code: ${result.exitCode}')
      ..writeln('Timed out: ${result.timedOut}')
      ..writeln('Duration: ${result.durationMs} ms')
      ..writeln()
      ..writeln('STDOUT:')
      ..writeln(result.stdout.trim().isEmpty ? '<empty>' : result.stdout.trim())
      ..writeln()
      ..writeln('STDERR:')
      ..writeln(result.stderr.trim().isEmpty ? '<empty>' : result.stderr.trim())
      ..writeln()
      ..writeln();
  }

  String _diagnosticStatus(ProcessExecutionResult result) {
    if (result.timedOut) {
      return 'TIMEOUT';
    }

    if (result.succeeded) {
      return 'PASSED';
    }

    return 'FAILED — exit code ${result.exitCode}';
  }

  Future<void> _ensureProjectRepositories(Directory projectDirectory) async {
    final settingsFile = File('${projectDirectory.path}/settings.gradle.kts');

    var settingsText = await settingsFile.readAsString();

    const repositoryConfiguration = '''
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()
        mavenCentral()
    }
}

''';

    final hasPluginManagement = settingsText.contains('pluginManagement');

    final hasGoogleRepository = settingsText.contains('google()');

    if (hasPluginManagement && hasGoogleRepository) {
      return;
    }

    settingsText = repositoryConfiguration + settingsText;

    await settingsFile.writeAsString(settingsText);
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

  Future<String> _prepareSyntheticJdkHome({
    required Directory supportDirectory,
    required String realJdkPath,
    required String javaShimPath,
  }) async {
    final syntheticHome = Directory(
      '${supportDirectory.path}/DroidForge/runtime-jdk/jdk-17',
    );

    if (await syntheticHome.exists()) {
      await syntheticHome.delete(recursive: true);
    }

    final syntheticBin = Directory('${syntheticHome.path}/bin');
    await syntheticBin.create(recursive: true);

    await Link('${syntheticBin.path}/java').create(javaShimPath);

    const linkedEntries = <String>[
      'conf',
      'include',
      'jmods',
      'legal',
      'lib',
      'release',
    ];

    for (final entryName in linkedEntries) {
      final realPath = '$realJdkPath/$entryName';
      final entityType = await FileSystemEntity.type(
        realPath,
        followLinks: false,
      );

      if (entityType == FileSystemEntityType.notFound) {
        continue;
      }

      await Link('${syntheticHome.path}/$entryName').create(realPath);
    }

    final syntheticJava = Link('${syntheticBin.path}/java');

    if (!await syntheticJava.exists()) {
      throw StateError(
        'Synthetic Java launcher was not created: ${syntheticJava.path}',
      );
    }

    return syntheticHome.path;
  }

  Future<void> _writeAndroidGradleProperties(Directory projectDirectory) async {
    final file = File('${projectDirectory.path}/gradle.properties');

    final existing = await file.exists()
        ? await file.readAsLines()
        : <String>[];

    const managedKeys = <String>{
      'org.gradle.jvmargs',
      'org.gradle.daemon',
      'org.gradle.native',
      'org.gradle.vfs.watch',
      'org.gradle.workers.max',
    };

    final preserved = existing.where((line) {
      final trimmed = line.trim();

      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        return true;
      }

      final separator = trimmed.indexOf('=');

      if (separator < 0) {
        return true;
      }

      final key = trimmed.substring(0, separator).trim();
      return !managedKeys.contains(key);
    }).toList();

    while (preserved.isNotEmpty && preserved.last.trim().isEmpty) {
      preserved.removeLast();
    }

    preserved.addAll(<String>[
      '',
      '# DroidForge Android runtime settings',
      'org.gradle.daemon=false',
      'org.gradle.native=false',
      'org.gradle.vfs.watch=false',
      'org.gradle.workers.max=1',
    ]);

    await file.writeAsString('${preserved.join('\n')}\n', flush: true);
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
}
