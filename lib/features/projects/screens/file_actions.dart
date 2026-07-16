import 'package:flutter/material.dart';

class FileActions extends StatelessWidget {
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;

  const FileActions({
    super.key,
    required this.onNewFile,
    required this.onNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 1,
          child: Text("New File"),
        ),
        PopupMenuItem(
          value: 2,
          child: Text("New Folder"),
        ),
      ],
      onSelected: (value) {
        if (value == 1) {
          onNewFile();
        } else if (value == 2) {
          onNewFolder();
        }
      },
    );
  }
}
