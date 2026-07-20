class JdkRelease {
  const JdkRelease({
    required this.version,
    required this.architecture,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    required this.releaseTag,
  });

  final int version;
  final String architecture;
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
  final String releaseTag;
}

class JdkReleaseCatalog {
  static const JdkRelease jdk17 = JdkRelease(
    version: 17,
    architecture: 'arm64-v8a',
    assetName: 'jdk17-arm64.tar.xz',
    downloadUrl:
        'https://github.com/itsaky/openjdk-17-android/'
        'releases/download/01-01-2022/jdk17-arm64.tar.xz',
    sizeBytes: 157457188,
    sha256: '1bfde21d5b5d6ed4632c4c36245f2a61532b8c641531c5f468148024223a2b63',
    releaseTag: '01-01-2022',
  );

  static JdkRelease? forVersion(int version) {
    return switch (version) {
      17 => jdk17,
      _ => null,
    };
  }
}
