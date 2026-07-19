import 'package:flutter/material.dart';
import 'create_dialog.dart';

class ProjectPopupMenu extends StatelessWidget {
  final Future<void> Function(String name) onCreateFile;
  final Future<void> Function(String name) onCreateFolder;

  const ProjectPopupMenu({
    super.key,
    required this.onCreateFile,
    required this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == "file") {
          final name = await CreateDialog.show(context, "New File");

          if (name != null && name.isNotEmpty) {
            await onCreateFile(name);
          }
        }

        if (value == "folder") {
          final name = await CreateDialog.show(context, "New Folder");

          if (name != null && name.isNotEmpty) {
            await onCreateFolder(name);
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "file", child: Text("New File")),
        PopupMenuItem(value: "folder", child: Text("New Folder")),
      ],
    );
  }
}
