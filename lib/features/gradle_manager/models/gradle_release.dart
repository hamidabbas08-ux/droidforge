class GradleRelease {
  const GradleRelease({
    required this.version,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
  });

  final String version;
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
}

class GradleReleaseCatalog {
  static const GradleRelease gradle810 = GradleRelease(
    version: '8.10',
    assetName: 'gradle-8.10-bin.zip',
    downloadUrl:
        'https://services.gradle.org/distributions/gradle-8.10-bin.zip',
    sizeBytes: 136713202,
    sha256: '5b9c5eb3f9fc2c94abaea57d90bd78747ca117ddbbf96c859d3741181a12bf2a',
  );

  static const List<GradleRelease> releases = <GradleRelease>[gradle810];

  static GradleRelease? forVersion(String version) {
    for (final release in releases) {
      if (release.version == version) {
        return release;
      }
    }

    return null;
  }
}
