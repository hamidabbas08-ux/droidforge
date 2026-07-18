
class JdkVersion {
  final int major;
  final String label;

  const JdkVersion(this.major, this.label);

  String get id => 'jdk-$major';

  static const supported = <JdkVersion>[
    JdkVersion(17, 'JDK 17'),
    JdkVersion(21, 'JDK 21'),
    JdkVersion(24, 'JDK 24'),
  ];
}
