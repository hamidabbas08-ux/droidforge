import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../models/jdk_release.dart';
import 'jdk_storage_service.dart';

typedef JdkInstallProgress = void Function(String stage, double progress);

class JdkInstallerService {
  JdkInstallerService({JdkStorageService? storage})
    : _storage = storage ?? JdkStorageService();

  final JdkStorageService _storage;

  Future<String> install(
    JdkRelease release, {
    required JdkInstallProgress onProgress,
  }) async {
    final root = await _storage.getRootDirectory();

    final finalDirectory = await _storage.getVersionDirectory(release.version);

    final workDirectory = Directory(
      '${root.path}/.install-jdk-${release.version}',
    );

    final archiveFile = File('${root.path}/.${release.assetName}.part.tar.xz');

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

      onProgress('Verifying SHA-256', 0.75);
      await _verifySha256(release, archiveFile);

      onProgress('Extracting', 0.80);

      await workDirectory.create(recursive: true);

      await _extractArchiveInBackground(archiveFile.path, workDirectory.path);

      onProgress('Validating JDK', 0.94);
      await _validateInstallation(release, workDirectory);

      onProgress('Finalizing', 0.97);

      if (await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }

      await workDirectory.rename(finalDirectory.path);

      await _makeExecutablesRunnable(finalDirectory);

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
    JdkRelease release,
    File outputFile, {
    required void Function(double progress) onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);

    IOSink? sink;

    try {
      final request = await client.getUrl(Uri.parse(release.downloadUrl));

      request.followRedirects = true;
      request.maxRedirects = 10;

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'DroidForge-JDK-Manager/1.0',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download failed with HTTP '
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

  Future<void> _verifySize(JdkRelease release, File archiveFile) async {
    final size = await archiveFile.length();

    if (size != release.sizeBytes) {
      throw StateError(
        'JDK archive size mismatch. '
        'Expected ${release.sizeBytes}, '
        'received $size.',
      );
    }
  }

  Future<void> _verifySha256(JdkRelease release, File archiveFile) async {
    final actual = await _calculateSha256InBackground(archiveFile.path);

    final expected = release.sha256.toLowerCase();

    if (actual != expected) {
      throw StateError(
        'JDK package verification failed. '
        'Expected SHA-256: $expected, '
        'actual: $actual',
      );
    }
  }

  Future<void> _validateInstallation(
    JdkRelease release,
    Directory directory,
  ) async {
    final releaseFile = File('${directory.path}/release');

    final javaFile = File('${directory.path}/bin/java');

    final javacFile = File('${directory.path}/bin/javac');

    final modulesFile = File('${directory.path}/lib/modules');

    final missing = <String>[];

    if (!await releaseFile.exists()) {
      missing.add('release');
    }

    if (!await javaFile.exists()) {
      missing.add('bin/java');
    }

    if (!await javacFile.exists()) {
      missing.add('bin/javac');
    }

    if (!await modulesFile.exists()) {
      missing.add('lib/modules');
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Extracted JDK is incomplete. '
        'Missing: ${missing.join(', ')}.',
      );
    }

    final releaseText = await releaseFile.readAsString();

    final version = release.version.toString();

    final validVersion =
        releaseText.contains('JAVA_VERSION="$version') ||
        releaseText.contains("JAVA_VERSION='$version") ||
        releaseText.contains('JAVA_VERSION=$version');

    if (!validVersion) {
      throw StateError(
        'Extracted runtime does not identify '
        'itself as JDK $version.',
      );
    }
  }

  Future<void> _makeExecutablesRunnable(Directory directory) async {
    if (!Platform.isAndroid && !Platform.isLinux) {
      return;
    }

    final binDirectory = Directory('${directory.path}/bin');

    if (!await binDirectory.exists()) {
      return;
    }

    await for (final entity in binDirectory.list()) {
      if (entity is! File) {
        continue;
      }

      final result = await Process.run('chmod', <String>['700', entity.path]);

      if (result.exitCode != 0) {
        throw ProcessException(
          'chmod',
          <String>['700', entity.path],
          result.stderr.toString(),
          result.exitCode,
        );
      }
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
  final result = await _runWorker(_sha256Worker, <String, String>{
    'archivePath': archivePath,
  });

  final digest = result['digest'];

  if (digest is! String || digest.isEmpty) {
    throw StateError('SHA-256 worker returned no digest.');
  }

  return digest.toLowerCase();
}

Future<void> _extractArchiveInBackground(
  String archivePath,
  String extractionPath,
) async {
  await _runWorker(_extractionWorker, <String, String>{
    'archivePath': archivePath,
    'extractionPath': extractionPath,
  });
}

Future<Map<Object?, Object?>> _runWorker(
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
      debugName: 'DroidForgeJdkWorker',
    );

    final resultCompleter = Completer<Map<Object?, Object?>>();

    late final StreamSubscription<Object?> resultSubscription;

    late final StreamSubscription<Object?> errorSubscription;

    late final StreamSubscription<Object?> exitSubscription;

    resultSubscription = resultPort.listen((message) {
      if (resultCompleter.isCompleted) {
        return;
      }

      if (message is! Map) {
        resultCompleter.completeError(
          StateError(
            'Background worker returned '
            'an invalid response.',
          ),
        );
        return;
      }

      final response = Map<Object?, Object?>.from(message);

      if (response['ok'] == true) {
        resultCompleter.complete(response);
        return;
      }

      resultCompleter.completeError(
        StateError(
          response['error']?.toString() ?? 'Unknown background worker error.',
        ),
      );
    });

    errorSubscription = errorPort.listen((message) {
      if (resultCompleter.isCompleted) {
        return;
      }

      if (message is List && message.isNotEmpty) {
        final error = message[0];
        final stack = message.length > 1 ? message[1] : '';

        resultCompleter.completeError(
          StateError(
            'Background isolate failed: '
            '$error\n$stack',
          ),
        );
        return;
      }

      resultCompleter.completeError(
        StateError(
          'Background isolate failed: '
          '$message',
        ),
      );
    });

    exitSubscription = exitPort.listen((_) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.completeError(
          StateError(
            'Background isolate exited '
            'without returning a result.',
          ),
        );
      }
    });

    try {
      return await resultCompleter.future;
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

void _sha256Worker(List<Object?> message) async {
  final sendPort = message[0] as SendPort;

  final arguments = Map<Object?, Object?>.from(message[1] as Map);

  try {
    final archivePath = arguments['archivePath'] as String;

    final digest = await sha256.bind(File(archivePath).openRead()).first;

    sendPort.send(<String, Object?>{
      'ok': true,
      'digest': digest.toString().toLowerCase(),
    });
  } catch (error, stackTrace) {
    sendPort.send(<String, Object?>{
      'ok': false,
      'error': '$error\n$stackTrace',
    });
  }
}

void _extractionWorker(List<Object?> message) async {
  final sendPort = message[0] as SendPort;

  final arguments = Map<Object?, Object?>.from(message[1] as Map);

  try {
    final archivePath = arguments['archivePath'] as String;

    final extractionPath = arguments['extractionPath'] as String;

    await extractFileToDisk(archivePath, extractionPath, callback: (_) {});

    sendPort.send(<String, Object?>{'ok': true});
  } catch (error, stackTrace) {
    sendPort.send(<String, Object?>{
      'ok': false,
      'error': '$error\n$stackTrace',
    });
  }
}
