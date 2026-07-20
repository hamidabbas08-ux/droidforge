import 'package:flutter/material.dart';

class ProjectPopupMenu extends StatelessWidget {
  const ProjectPopupMenu({
    super.key,
    required this.onCreateFile,
    required this.onCreateFolder,
  });

  final Future<void> Function(String name) onCreateFile;
  final Future<void> Function(String name) onCreateFolder;

  Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final name = value.trim();

                if (name.isNotEmpty) {
                  Navigator.of(dialogContext).pop(name);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();

                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _handleSelection(BuildContext context, String action) async {
    final creatingFile = action == 'file';

    final name = await _showNameDialog(
      context,
      title: creatingFile ? 'New File' : 'New Folder',
      hint: creatingFile ? 'File name' : 'Folder name',
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    if (creatingFile) {
      await onCreateFile(name.trim());
    } else {
      await onCreateFolder(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Project options',
      onSelected: (action) {
        _handleSelection(context, action);
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'file',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.note_add_outlined),
            title: Text('New File'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'folder',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.create_new_folder_outlined),
            title: Text('New Folder'),
          ),
        ),
      ],
    );
  }
}
