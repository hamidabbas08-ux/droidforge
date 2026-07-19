class JdkVersion {
  final int major;
  final String label;
  final bool available;
  final String availabilityLabel;

  const JdkVersion(
    this.major,
    this.label, {
    required this.available,
    required this.availabilityLabel,
  });

  String get id => 'jdk-$major';

  static const supported = <JdkVersion>[
    JdkVersion(
      17,
      'JDK 17',
      available: true,
      availabilityLabel: 'Android ARM64 runtime required',
    ),
    JdkVersion(
      21,
      'JDK 21',
      available: false,
      availabilityLabel: 'Coming Soon',
    ),
    JdkVersion(
      24,
      'JDK 24',
      available: false,
      availabilityLabel: 'Coming Soon',
    ),
  ];
}
