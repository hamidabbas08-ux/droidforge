class AndroidSdkPackage {
  const AndroidSdkPackage({
    required this.id,
    required this.displayName,
    required this.relativePath,
    required this.requiredFiles,
  });

  final String id;
  final String displayName;
  final String relativePath;
  final List<String> requiredFiles;
}

class AndroidSdkPackageCatalog {
  static const AndroidSdkPackage platform35 = AndroidSdkPackage(
    id: 'platforms;android-35',
    displayName: 'Android Platform 35',
    relativePath: 'platforms/android-35',
    requiredFiles: <String>['android.jar', 'framework.aidl'],
  );

  static const AndroidSdkPackage buildTools = AndroidSdkPackage(
    id: 'build-tools;35.0.0',
    displayName: 'Android Build Tools 35.0.0',
    relativePath: 'build-tools/35.0.0',
    requiredFiles: <String>['aapt2', 'd8', 'zipalign', 'apksigner'],
  );

  static const AndroidSdkPackage platformTools = AndroidSdkPackage(
    id: 'platform-tools',
    displayName: 'Android Platform Tools',
    relativePath: 'platform-tools',
    requiredFiles: <String>['adb'],
  );

  static const List<AndroidSdkPackage> requiredPackages = <AndroidSdkPackage>[
    platform35,
    buildTools,
    platformTools,
  ];
}
