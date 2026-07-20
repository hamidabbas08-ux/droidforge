import 'dart:io';

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

    await _deleteIfExists(workDirectory);
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

      await extractFileToDisk(
        archiveFile.path,
        workDirectory.path,
        callback: (_) {
          // Extraction is intentionally disk-based.
        },
      );

      onProgress('Validating JDK', 0.94);
      await _validateInstallation(workDirectory);

      onProgress('Finalizing', 0.97);

      if (await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }

      await workDirectory.rename(finalDirectory.path);
      await archiveFile.delete();

      await _storage.setActiveVersion(release.version);

      onProgress('Installed and active', 1);
      return finalDirectory.path;
    } catch (_) {
      await _deleteIfExists(workDirectory);
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
          'Download failed with HTTP ${response.statusCode}.',
          uri: Uri.parse(release.downloadUrl),
        );
      }

      final sink = outputFile.openWrite();
      var received = 0;

      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;

          final progress = received / release.sizeBytes;

          onProgress(progress.clamp(0.0, 1.0).toDouble());
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _verifySize(JdkRelease release, File archiveFile) async {
    final size = await archiveFile.length();

    if (size != release.sizeBytes) {
      throw StateError(
        'JDK archive size mismatch. '
        'Expected ${release.sizeBytes}, received $size.',
      );
    }
  }

  Future<void> _verifySha256(JdkRelease release, File archiveFile) async {
    final digest = await sha256.bind(archiveFile.openRead()).first;
    final actual = digest.toString().toLowerCase();
    final expected = release.sha256.toLowerCase();

    if (actual != expected) {
      throw StateError(
        'JDK archive SHA-256 mismatch. '
        'Expected $expected, received $actual.',
      );
    }
  }

  Future<void> _validateInstallation(Directory directory) async {
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
        'Extracted JDK is incomplete. Missing: ${missing.join(', ')}.',
      );
    }

    final releaseText = await releaseFile.readAsString();

    if (!releaseText.contains('JAVA_VERSION="17') &&
        !releaseText.contains("JAVA_VERSION='17") &&
        !releaseText.contains('JAVA_VERSION=17')) {
      throw StateError('Extracted runtime does not identify itself as JDK 17.');
    }
  }

  Future<void> _deleteIfExists(Directory directory) async {
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
