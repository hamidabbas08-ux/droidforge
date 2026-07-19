import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

class RuntimeArchiveInstaller {
  static const int _maxDownloadAttempts = 4;
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _idleTimeout = Duration(seconds: 45);

  /// Downloads to a `.part` file first, retries interrupted transfers, and only
  /// renames to [destination] after the complete response has been received.
  static Future<File> download({
    required Uri uri,
    required File destination,
    required void Function(double progress, String status)? onProgress,
  }) async {
    await destination.parent.create(recursive: true);
    final part = File('${destination.path}.part');

    Object? lastError;
    for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
      HttpClient? client;
      IOSink? sink;
      try {
        final existing = await part.exists() ? await part.length() : 0;
        onProgress?.call(
          0,
          existing > 0
              ? 'Resuming download (attempt $attempt/$_maxDownloadAttempts)...'
              : 'Connecting (attempt $attempt/$_maxDownloadAttempts)...',
        );

        client = HttpClient()
          ..connectionTimeout = _connectTimeout
          ..idleTimeout = _idleTimeout
          ..maxConnectionsPerHost = 2;

        final request = await client.getUrl(uri);
        request.followRedirects = true;
        request.maxRedirects = 8;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(HttpHeaders.userAgentHeader, 'DroidForge/11.2 Android');
        if (existing > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
        }

        final response = await request.close().timeout(_idleTimeout);
        final resumed = existing > 0 && response.statusCode == HttpStatus.partialContent;
        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          await response.drain<void>();
          throw HttpException(
            'Download server returned HTTP ${response.statusCode}.',
            uri: _safeUri(uri),
          );
        }

        if (existing > 0 && !resumed) {
          await part.writeAsBytes(const [], flush: true);
        }
        final base = resumed ? existing : 0;
        final responseLength = response.contentLength;
        final expectedTotal = responseLength >= 0 ? base + responseLength : -1;

        sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
        var received = base;
        var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

        await for (final chunk in response.timeout(_idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastUpdate).inMilliseconds >= 250) {
            lastUpdate = now;
            final progress = expectedTotal > 0 ? received / expectedTotal : 0.0;
            onProgress?.call(
              progress.clamp(0.0, 0.99),
              expectedTotal > 0
                  ? 'Downloading ${_fileName(destination)} '
                      '${_formatBytes(received)} / ${_formatBytes(expectedTotal)}'
                  : 'Downloading ${_fileName(destination)} '
                      '${_formatBytes(received)}',
            );
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        final actualLength = await part.length();
        if (expectedTotal > 0 && actualLength != expectedTotal) {
          throw const HttpException('The download ended before all data arrived.');
        }
        if (actualLength < 1024) {
          throw const HttpException('The downloaded archive is unexpectedly small.');
        }

        if (await destination.exists()) await destination.delete();
        await part.rename(destination.path);
        onProgress?.call(1, 'Download complete');
        return destination;
      } catch (error) {
        lastError = error;
        try {
          await sink?.close();
        } catch (_) {}
        client?.close(force: true);

        if (attempt < _maxDownloadAttempts) {
          final delay = Duration(seconds: attempt * 2);
          onProgress?.call(
            0,
            'Connection interrupted. Retrying in ${delay.inSeconds}s...',
          );
          await Future<void>.delayed(delay);
          continue;
        }
      } finally {
        client?.close(force: true);
      }
    }

    throw HttpException(
      'JDK download failed after $_maxDownloadAttempts attempts: '
      '${_safeError(lastError)}',
      uri: _safeUri(uri),
    );
  }

  /// CPU-heavy XZ and TAR decoding runs in a background isolate so the Android
  /// UI thread remains responsive and does not trigger an ANR dialog.
  static Future<void> extractTarXz({
    required File archiveFile,
    required Directory destination,
    required void Function(double progress, String status)? onProgress,
  }) async {
    if (!await archiveFile.exists() || await archiveFile.length() < 1024) {
      throw const FormatException('The downloaded JDK archive is incomplete.');
    }

    await destination.create(recursive: true);
    onProgress?.call(0.02, 'Checking and extracting archive in background...');

    try {
      final extractedCount = await Isolate.run<int>(() {
        return _extractTarXzWorker(archiveFile.path, destination.path);
      });
      if (extractedCount == 0) {
        throw const FormatException('The JDK archive contained no files.');
      }
      onProgress?.call(1, 'Extracted $extractedCount archive entries');
    } catch (error) {
      // Never leave a partly extracted runtime marked as usable.
      if (await destination.exists()) {
        await destination.delete(recursive: true);
        await destination.create(recursive: true);
      }
      throw FormatException('JDK archive extraction failed: ${_safeError(error)}');
    }
  }

  static String _safeJoin(String root, String relative) {
    final normalized = relative.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.split('/').contains('..')) {
      throw FormatException('Unsafe archive path: $relative');
    }
    return '$root/$normalized';
  }

  static Future<void> makeExecutableTree(Directory root) async {
    if (!await root.exists()) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.contains('/bin/') ||
          path.endsWith('/java') ||
          path.endsWith('/javac') ||
          path.endsWith('/aapt2') ||
          path.endsWith('/aapt') ||
          path.endsWith('/adb') ||
          path.endsWith('/apksigner') ||
          path.endsWith('/d8') ||
          path.endsWith('/sdkmanager')) {
        final result = await Process.run('/system/bin/chmod', ['700', path]);
        if (result.exitCode != 0) {
          throw FileSystemException('Could not make runtime file executable.', path);
        }
      }
    }
  }

  static Uri _safeUri(Uri uri) => Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      );

  static String _fileName(File file) => file.uri.pathSegments.last;

  static String _safeError(Object? error) {
    if (error == null) return 'unknown network error';
    var text = error.toString();
    // GitHub release redirects contain temporary signed query parameters.
    text = text.replaceAll(RegExp(r'https?://[^\\s,]+'), '<download URL>');
    return text.length > 240 ? '${text.substring(0, 240)}…' : text;
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

int _extractTarXzWorker(String archivePath, String destinationPath) {
  final compressed = File(archivePath).readAsBytesSync();
  final xz = XZDecoder().decodeBytes(compressed);
  final tar = TarDecoder().decodeBytes(xz, verify: true);

  var count = 0;
  for (final entry in tar) {
    final safePath = RuntimeArchiveInstaller._safeJoin(destinationPath, entry.name);
    if (entry.isFile) {
      final out = File(safePath);
      out.parent.createSync(recursive: true);
      final content = entry.content;
      if (content is List<int>) {
        out.writeAsBytesSync(content, flush: false);
      } else {
        throw FormatException('Unsupported archive entry: ${entry.name}');
      }
      count++;
    } else if (entry.isDirectory) {
      Directory(safePath).createSync(recursive: true);
      count++;
    }
  }
  return count;
}
