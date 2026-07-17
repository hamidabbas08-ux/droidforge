import 'package:flutter/material.dart';

import '../models/file_tree_node.dart';
import '../../editor/screens/code_editor_screen.dart';

class FileTreeWidget extends StatefulWidget {
  final FileTreeNode node;
  final VoidCallback? onRefresh;

  const FileTreeWidget({
    super.key,
    required this.node,
    this.onRefresh,
  });

  @override
  State<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends State<FileTreeWidget> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.node.isDirectory) {
      return ListTile(
        dense: true,
        leading: const Icon(
          Icons.description,
          color: Colors.blue,
        ),
        title: Text(
          widget.node.name,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CodeEditorScreen(
                fileName: widget.node.path,
              ),
            ),
          ).then((_) {
            widget.onRefresh?.call();
          });
        },
      );
    }

    return ExpansionTile(
      initiallyExpanded: expanded,
      leading: const Icon(
        Icons.folder,
        color: Colors.amber,
      ),
      title: Text(
        widget.node.name,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (value) {
        setState(() {
          expanded = value;
        });
      },
      children: widget.node.children
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: FileTreeWidget(
                node: child,
                onRefresh: widget.onRefresh,
              ),
            ),
          )
          .toList(),
    );
  }
}
