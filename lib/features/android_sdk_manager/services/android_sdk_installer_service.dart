import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../../../core/process/native_process_service.dart';
import '../models/android_sdk_bundle.dart';
import '../models/android_sdk_package.dart';
import 'android_sdk_storage_service.dart';

typedef AndroidSdkInstallProgress =
    void Function(String stage, double progress);

class AndroidSdkInstallerService {
  AndroidSdkInstallerService({
    AndroidSdkStorageService? storage,
    NativeProcessService processService = const NativeProcessService(),
  }) : _storage = storage ?? AndroidSdkStorageService(),
       _processService = processService;

  final AndroidSdkStorageService _storage;
  final NativeProcessService _processService;

  Future<String> install(
    AndroidSdkBundle bundle, {
    required AndroidSdkInstallProgress onProgress,
  }) async {
    final sdkRoot = await _storage.getSdkRootDirectory();
    final parentDirectory = sdkRoot.parent;

    final workDirectory = Directory(
      '${parentDirectory.path}/.android-sdk-install-work',
    );

    final archiveFile = File(
      '${parentDirectory.path}/.part-${bundle.assetName}',
    );

    final backupDirectory = Directory(
      '${parentDirectory.path}/.android-sdk-backup',
    );

    await _deleteDirectoryIfExists(workDirectory);
    await _deleteDirectoryIfExists(backupDirectory);
    await _deleteFileIfExists(archiveFile);

    try {
      onProgress('Downloading', 0);

      await _download(
        bundle,
        archiveFile,
        onProgress: (progress) {
          onProgress('Downloading', progress * 0.70);
        },
      );

      onProgress('Verifying size', 0.72);
      await _verifySize(bundle, archiveFile);

      onProgress('Verifying SHA-256', 0.76);
      await _verifySha256(bundle, archiveFile);

      onProgress('Extracting', 0.80);

      await workDirectory.create(recursive: true);

      await _extractArchiveInBackground(archiveFile.path, workDirectory.path);

      onProgress('Locating SDK root', 0.90);

      final extractedSdkRoot = await _locateExtractedSdkRoot(workDirectory);

      onProgress('Validating SDK packages', 0.93);

      await _validateInstallation(extractedSdkRoot);

      onProgress('Setting executable permissions', 0.96);

      await _makeSdkExecutablesRunnable(extractedSdkRoot);

      onProgress('Finalizing installation', 0.98);

      if (await sdkRoot.exists()) {
        await sdkRoot.rename(backupDirectory.path);
      }

      try {
        await extractedSdkRoot.rename(sdkRoot.path);
      } catch (_) {
        if (await backupDirectory.exists() && !await sdkRoot.exists()) {
          await backupDirectory.rename(sdkRoot.path);
        }

        rethrow;
      }

      await _deleteDirectoryIfExists(backupDirectory);
      await _deleteDirectoryIfExists(workDirectory);
      await _deleteFileIfExists(archiveFile);

      await _storage.setInstalled(true);

      onProgress('Installed and active', 1);

      return sdkRoot.path;
    } catch (_) {
      await _deleteDirectoryIfExists(workDirectory);
      await _deleteFileIfExists(archiveFile);

      if (await backupDirectory.exists()) {
        final sdkRoot = await _storage.getSdkRootDirectory();

        if (await sdkRoot.exists()) {
          await sdkRoot.delete(recursive: true);
        }

        await backupDirectory.rename(sdkRoot.path);
      }

      rethrow;
    }
  }

  Future<void> _download(
    AndroidSdkBundle bundle,
    File outputFile, {
    required void Function(double progress) onProgress,
  }) async {
    if (bundle.downloadUrl.trim().isEmpty) {
      throw StateError('Android SDK download URL is empty.');
    }

    if (bundle.sizeBytes <= 0) {
      throw StateError('Android SDK bundle size is invalid.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);

    IOSink? sink;

    try {
      final uri = Uri.parse(bundle.downloadUrl);
      final request = await client.getUrl(uri);

      request.followRedirects = true;
      request.maxRedirects = 10;

      request.headers.set(
        HttpHeaders.userAgentHeader,
        'DroidForge-Android-SDK-Manager/1.0',
      );

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Android SDK download failed with HTTP '
          '${response.statusCode}.',
          uri: uri,
        );
      }

      sink = outputFile.openWrite();

      var receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final progress = receivedBytes / bundle.sizeBytes;

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

  Future<void> _verifySize(AndroidSdkBundle bundle, File archiveFile) async {
    final actualSize = await archiveFile.length();

    if (actualSize != bundle.sizeBytes) {
      throw StateError(
        'Android SDK bundle size mismatch. '
        'Expected ${bundle.sizeBytes}, '
        'received $actualSize.',
      );
    }
  }

  Future<void> _verifySha256(AndroidSdkBundle bundle, File archiveFile) async {
    final expected = bundle.sha256.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expected)) {
      throw StateError('Android SDK bundle SHA-256 value is invalid.');
    }

    final actual = await _calculateSha256InBackground(archiveFile.path);

    if (actual != expected) {
      throw StateError(
        'Android SDK bundle verification failed. '
        'Expected SHA-256: $expected, '
        'actual: $actual.',
      );
    }
  }

  Future<Directory> _locateExtractedSdkRoot(Directory workDirectory) async {
    if (await _containsRequiredSdkFiles(workDirectory)) {
      return workDirectory;
    }

    final childDirectories = <Directory>[];

    await for (final entity in workDirectory.list()) {
      if (entity is Directory) {
        childDirectories.add(entity);
      }
    }

    for (final directory in childDirectories) {
      if (await _containsRequiredSdkFiles(directory)) {
        return directory;
      }
    }

    throw StateError(
      'Extracted archive does not contain a valid '
      'Android SDK root directory.',
    );
  }

  Future<bool> _containsRequiredSdkFiles(Directory directory) async {
    for (final package in AndroidSdkPackageCatalog.requiredPackages) {
      final packageDirectory = Directory(
        '${directory.path}/${package.relativePath}',
      );

      if (!await packageDirectory.exists()) {
        return false;
      }

      for (final relativeFile in package.requiredFiles) {
        final file = File('${packageDirectory.path}/$relativeFile');

        if (!await file.exists()) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _validateInstallation(Directory sdkRoot) async {
    final missing = <String>[];

    for (final package in AndroidSdkPackageCatalog.requiredPackages) {
      final packageDirectory = Directory(
        '${sdkRoot.path}/${package.relativePath}',
      );

      if (!await packageDirectory.exists()) {
        missing.add(package.relativePath);
        continue;
      }

      for (final requiredFile in package.requiredFiles) {
        final relativePath = '${package.relativePath}/$requiredFile';

        if (!await File('${sdkRoot.path}/$relativePath').exists()) {
          missing.add(relativePath);
        }
      }
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Extracted Android SDK is incomplete. '
        'Missing: ${missing.join(', ')}.',
      );
    }

    final d8Jar = File('${sdkRoot.path}/build-tools/35.0.0/lib/d8.jar');

    final apkSignerJar = File(
      '${sdkRoot.path}/build-tools/35.0.0/lib/apksigner.jar',
    );

    if (!await d8Jar.exists()) {
      throw StateError(
        'Android SDK D8 library is missing: '
        'build-tools/35.0.0/lib/d8.jar',
      );
    }

    if (!await apkSignerJar.exists()) {
      throw StateError(
        'Android SDK APK Signer library is missing: '
        'build-tools/35.0.0/lib/apksigner.jar',
      );
    }
  }

  Future<void> _makeSdkExecutablesRunnable(Directory sdkRoot) async {
    final executablePaths = <String>[
      'build-tools/35.0.0/aapt2',
      'build-tools/35.0.0/zipalign',
      'build-tools/35.0.0/d8',
      'build-tools/35.0.0/apksigner',
      'platform-tools/adb',
    ];

    for (final relativePath in executablePaths) {
      final file = File('${sdkRoot.path}/$relativePath');

      if (!await file.exists()) {
        throw StateError(
          'Required SDK executable is missing: '
          '$relativePath',
        );
      }

      await _makeExecutable(file);
    }
  }

  Future<void> _makeExecutable(File file) async {
    if (!Platform.isAndroid && !Platform.isLinux) {
      return;
    }

    final result = await _processService.run(
      executable: '/system/bin/chmod',
      arguments: <String>['700', file.path],
      timeout: const Duration(seconds: 30),
    );

    if (!result.succeeded) {
      throw StateError(
        'Failed to make executable: ${file.path}. '
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
  final result = await _runAndroidSdkWorker(
    _androidSdkSha256Worker,
    <String, String>{'archivePath': archivePath},
  );

  final digest = result['digest'];

  if (digest is! String || digest.isEmpty) {
    throw StateError('Android SDK SHA-256 worker returned no digest.');
  }

  return digest.toLowerCase();
}

Future<void> _extractArchiveInBackground(
  String archivePath,
  String extractionPath,
) async {
  await _runAndroidSdkWorker(_androidSdkExtractionWorker, <String, String>{
    'archivePath': archivePath,
    'extractionPath': extractionPath,
  });
}

Future<Map<Object?, Object?>> _runAndroidSdkWorker(
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
      debugName: 'DroidForgeAndroidSdkWorker',
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
          StateError(
            'Android SDK background worker returned '
            'an invalid response.',
          ),
        );
        return;
      }

      final response = Map<Object?, Object?>.from(message);

      if (response['ok'] == true) {
        completer.complete(response);
        return;
      }

      completer.completeError(
        StateError(
          response['error']?.toString() ?? 'Unknown Android SDK worker error.',
        ),
      );
    });

    errorSubscription = errorPort.listen((message) {
      if (completer.isCompleted) {
        return;
      }

      if (message is List && message.isNotEmpty) {
        final error = message[0];
        final stack = message.length > 1 ? message[1] : '';

        completer.completeError(
          StateError(
            'Android SDK background isolate failed: '
            '$error\n$stack',
          ),
        );
        return;
      }

      completer.completeError(
        StateError(
          'Android SDK background isolate failed: '
          '$message',
        ),
      );
    });

    exitSubscription = exitPort.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Android SDK background isolate exited '
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

void _androidSdkSha256Worker(List<Object?> message) async {
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

void _androidSdkExtractionWorker(List<Object?> message) async {
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
