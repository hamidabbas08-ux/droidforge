import 'dart:io';

class FileTreeNode {
  final String name;
  final String path;
  final bool isDirectory;
  final List<FileTreeNode> children;

  const FileTreeNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
  });

  FileTreeNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<FileTreeNode>? children,
  }) {
    return FileTreeNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
    );
  }

  static Future<FileTreeNode> fromDirectory(Directory directory) async {
    final entities = await directory.list().toList();

    entities.sort((a, b) {
      if (a is Directory && b is File) return -1;
      if (a is File && b is Directory) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    final children = <FileTreeNode>[];

    for (final entity in entities) {
      if (entity is Directory) {
        children.add(await fromDirectory(entity));
      } else if (entity is File) {
        children.add(
          FileTreeNode(
            name: entity.uri.pathSegments.last,
            path: entity.path,
            isDirectory: false,
          ),
        );
      }
    }

    return FileTreeNode(
      name: directory.uri.pathSegments.isEmpty
          ? directory.path
          : directory.uri.pathSegments[
              directory.uri.pathSegments.length - 2],
      path: directory.path,
      isDirectory: true,
      children: children,
    );
  }
}
