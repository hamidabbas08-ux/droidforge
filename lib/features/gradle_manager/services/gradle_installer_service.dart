import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../../../core/process/native_process_service.dart';
import '../models/gradle_release.dart';
import 'gradle_storage_service.dart';

typedef GradleInstallProgress = void Function(String stage, double progress);

class GradleInstallerService {
  GradleInstallerService({
    GradleStorageService? storage,
    NativeProcessService processService = const NativeProcessService(),
  }) : _storage = storage ?? GradleStorageService(),
       _processService = processService;

  final GradleStorageService _storage;
  final NativeProcessService _processService;

  Future<String> install(
    GradleRelease release, {
    required GradleInstallProgress onProgress,
  }) async {
    final root = await _storage.getRootDirectory();
    final finalDirectory = await _storage.getVersionDirectory(release.version);

    final workDirectory = Directory(
      '${root.path}/.install-gradle-${release.version}',
    );

    final archiveFile = File('${root.path}/.part-${release.assetName}');

    await _deleteDirectoryIfExists(workDirectory);
    await _deleteFileIfExists(archiveFile);

    try {
      onProgress('Downloading', 0);

      await _download(
        release,
        archiveFile,
        onProgress: (progress) {
          onProgress('Downloading', progress * 0.70);
        },
      );

      onProgress('Verifying size', 0.72);
      await _verifySize(release, archiveFile);

      onProgress('Verifying SHA-256', 0.76);
      await _verifySha256(release, archiveFile);

      onProgress('Extracting', 0.80);
      await workDirectory.create(recursive: true);

      await _extractArchiveInBackground(archiveFile.path, workDirectory.path);

      final extractedDirectory = Directory(
        '${workDirectory.path}/gradle-${release.version}',
      );

      onProgress('Validating Gradle', 0.94);
      await _validateInstallation(release, extractedDirectory);

      onProgress('Finalizing', 0.97);

      if (await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }

      await extractedDirectory.rename(finalDirectory.path);

      await _deleteDirectoryIfExists(workDirectory);
      await _makeGradleExecutable(finalDirectory);
      await _deleteFileIfExists(archiveFile);

      await _storage.setActiveVersion(release.version);

      onProgress('Installed and active', 1);

      return finalDirectory.path;
    } catch (_) {
      await _deleteDirectoryIfExists(workDirectory);
      await _deleteFileIfExists(archiveFile);
      rethrow;
    }
  }

  Future<void> _download(
    GradleRelease release,
    File outputFile, {
    required void Function(double progress) onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);

    IOSink? sink;

    try {
      final request = await client.getUrl(Uri.parse(release.downloadUrl));

      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'DroidForge-Gradle-Manager/1.0',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Gradle download failed with HTTP '
          '${response.statusCode}.',
          uri: Uri.parse(release.downloadUrl),
        );
      }

      sink = outputFile.openWrite();
      var received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;

        final progress = received / release.sizeBytes;

        onProgress(progress.clamp(0.0, 1.0).toDouble());
      }

      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      if (sink != null) {
        await sink.flush();
        await sink.close();
      }

      client.close(force: true);
    }
  }

  Future<void> _verifySize(GradleRelease release, File archiveFile) async {
    final actualSize = await archiveFile.length();

    if (actualSize != release.sizeBytes) {
      throw StateError(
        'Gradle archive size mismatch. '
        'Expected ${release.sizeBytes}, '
        'received $actualSize.',
      );
    }
  }

  Future<void> _verifySha256(GradleRelease release, File archiveFile) async {
    final actual = await _calculateSha256InBackground(archiveFile.path);

    final expected = release.sha256.toLowerCase();

    if (actual != expected) {
      throw StateError(
        'Gradle package verification failed. '
        'Expected SHA-256: $expected, '
        'actual: $actual.',
      );
    }
  }

  Future<void> _validateInstallation(
    GradleRelease release,
    Directory directory,
  ) async {
    if (!await directory.exists()) {
      throw StateError(
        'Extracted Gradle directory is missing: '
        '${directory.path}',
      );
    }

    final gradleFile = File('${directory.path}/bin/gradle');

    final gradleBatFile = File('${directory.path}/bin/gradle.bat');

    final launcherFile = File(
      '${directory.path}/lib/'
      'gradle-launcher-${release.version}.jar',
    );

    final missing = <String>[];

    if (!await gradleFile.exists()) {
      missing.add('bin/gradle');
    }

    if (!await gradleBatFile.exists()) {
      missing.add('bin/gradle.bat');
    }

    if (!await launcherFile.exists()) {
      missing.add('lib/gradle-launcher-${release.version}.jar');
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Extracted Gradle installation is incomplete. '
        'Missing: ${missing.join(', ')}.',
      );
    }
  }

  Future<void> _makeGradleExecutable(Directory directory) async {
    final gradleFile = File('${directory.path}/bin/gradle');

    final result = await _processService.run(
      executable: '/system/bin/chmod',
      arguments: <String>['700', gradleFile.path],
      timeout: const Duration(seconds: 15),
    );

    if (!result.succeeded) {
      throw StateError(
        'Failed to make Gradle executable. '
        '${result.combinedOutput}',
      );
    }
  }

  Future<void> _deleteDirectoryIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Future<String> _calculateSha256InBackground(String archivePath) async {
  final result = await _runGradleWorker(_gradleSha256Worker, <String, String>{
    'archivePath': archivePath,
  });

  final digest = result['digest'];

  if (digest is! String || digest.isEmpty) {
    throw StateError('Gradle SHA-256 worker returned no digest.');
  }

  return digest.toLowerCase();
}

Future<void> _extractArchiveInBackground(
  String archivePath,
  String extractionPath,
) async {
  await _runGradleWorker(_gradleExtractionWorker, <String, String>{
    'archivePath': archivePath,
    'extractionPath': extractionPath,
  });
}

Future<Map<Object?, Object?>> _runGradleWorker(
  void Function(List<Object?>) worker,
  Map<String, String> arguments,
) async {
  final resultPort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();

  Isolate? isolate;

  try {
    isolate = await Isolate.spawn<List<Object?>>(
      worker,
      <Object?>[resultPort.sendPort, arguments],
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
      errorsAreFatal: true,
      debugName: 'DroidForgeGradleWorker',
    );

    final completer = Completer<Map<Object?, Object?>>();

    late final StreamSubscription<Object?> resultSubscription;

    late final StreamSubscription<Object?> errorSubscription;

    late final StreamSubscription<Object?> exitSubscription;

    resultSubscription = resultPort.listen((message) {
      if (completer.isCompleted) {
        return;
      }

      if (message is! Map) {
        completer.completeError(
          StateError('Gradle worker returned an invalid response.'),
        );
        return;
      }

      final response = Map<Object?, Object?>.from(message);

      if (response['ok'] == true) {
        completer.complete(response);
      } else {
        completer.completeError(
          StateError(
            response['error']?.toString() ?? 'Unknown Gradle worker error.',
          ),
        );
      }
    });

    errorSubscription = errorPort.listen((message) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Gradle background worker failed: '
            '$message',
          ),
        );
      }
    });

    exitSubscription = exitPort.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Gradle background worker exited '
            'without returning a result.',
          ),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      await resultSubscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
    }
  } finally {
    isolate?.kill(priority: Isolate.immediate);

    resultPort.close();
    errorPort.close();
    exitPort.close();
  }
}

void _gradleSha256Worker(List<Object?> message) async {
  final sendPort = message[0] as SendPort;
  final arguments = Map<String, String>.from(message[1] as Map);

  try {
    final archivePath = arguments['archivePath']!;

    final digest = await sha256.bind(File(archivePath).openRead()).first;

    sendPort.send(<String, Object?>{'ok': true, 'digest': digest.toString()});
  } catch (error, stackTrace) {
    sendPort.send(<String, Object?>{
      'ok': false,
      'error': '$error\n$stackTrace',
    });
  }
}

void _gradleExtractionWorker(List<Object?> message) async {
  final sendPort = message[0] as SendPort;
  final arguments = Map<String, String>.from(message[1] as Map);

  try {
    final archivePath = arguments['archivePath']!;
    final extractionPath = arguments['extractionPath']!;

    await extractFileToDisk(archivePath, extractionPath, callback: (_) {});

    sendPort.send(<String, Object?>{'ok': true});
  } catch (error, stackTrace) {
    sendPort.send(<String, Object?>{
      'ok': false,
      'error': '$error\n$stackTrace',
    });
  }
}
