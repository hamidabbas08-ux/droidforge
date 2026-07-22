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
    sizeBytes: 97261320,
    sha256: '803e8f35efa468a87b72930757c08459700b37f3f903c1f024713162d4f5c47c',
    releaseTag: 'jdk17-android-17.0.20',
  );

  static JdkRelease? forVersion(int version) {
    return switch (version) {
      17 => jdk17,
      _ => null,
    };
  }
}
