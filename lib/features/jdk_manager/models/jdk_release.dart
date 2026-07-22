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
    assetName: 'jdk17-android-arm64.tar.xz',
    downloadUrl:
        'https://github.com/hamidabbas08-ux/droidforge/'
        'releases/download/jdk17-android-17.0.20/'
        'jdk17-android-arm64.tar.xz',
    sizeBytes: 97266332,
    sha256: '7347aaaabf117c512d8b2c62816f6bdc3860bbf2ba7dc259e5f6c3e80d5ed90c',
    releaseTag: 'jdk17-android-17.0.20',
  );

  static JdkRelease? forVersion(int version) {
    return switch (version) {
      17 => jdk17,
      _ => null,
    };
  }
}
