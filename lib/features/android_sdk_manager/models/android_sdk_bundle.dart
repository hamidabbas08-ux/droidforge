class AndroidSdkBundle {
  const AndroidSdkBundle({
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    required this.releaseTag,
  });

  final String assetName;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
  final String releaseTag;
}

class AndroidSdkBundleCatalog {
  static const AndroidSdkBundle sdk35Arm64 = AndroidSdkBundle(
    assetName: 'droidforge-android-sdk-35-arm64.tar.xz',
    downloadUrl:
        'https://github.com/hamidabbas08-ux/droidforge/releases/'
        'download/android-sdk-35-v1/'
        'droidforge-android-sdk-35-arm64.tar.xz',
    sizeBytes: 94957124,
    sha256: 'e92f778e5cb4a96d00c93d732e4b8389799b89248b77bc4c09f0391e3b98716c',
    releaseTag: 'android-sdk-35-v1',
  );
}
