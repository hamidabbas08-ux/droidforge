class JdkVersion {
  final int major;
  final String label;

  const JdkVersion(this.major, this.label);

  String get id => 'jdk-$major';

  // DroidForge v7 is Android-only. JDK 17 is the first supported runtime.
  // JDK 21/24 will be added only after Android-native runtime packages are
  // bundled and verified on-device.
  static const supported = <JdkVersion>[
    JdkVersion(17, 'JDK 17'),
  ];
}
