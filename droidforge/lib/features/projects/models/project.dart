class Project {
  final String name;
  final String packageName;
  final String language;
  final int minSdk;
  final int targetSdk;

  const Project({
    required this.name,
    required this.packageName,
    required this.language,
    required this.minSdk,
    required this.targetSdk,
  });
}
