import 'package:flutter/material.dart';

import '../models/file_tree_node.dart';
import '../services/project_service.dart';
import '../widgets/file_tree_widget.dart';
import 'project_build_screen.dart';
import 'project_popup_menu.dart';

class ProjectExplorerScreen extends StatefulWidget {
  const ProjectExplorerScreen({super.key, required this.projectName});

  final String projectName;

  @override
  State<ProjectExplorerScreen> createState() => _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends State<ProjectExplorerScreen> {
  FileTreeNode? tree;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _reloadTree();
  }

  Future<void> _reloadTree() async {
    setState(() => loading = true);

    try {
      final result = await ProjectService.loadProjectTree(widget.projectName);

      if (!mounted) {
        return;
      }

      setState(() {
        tree = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _newFile(String name) async {
    if (tree == null) {
      return;
    }

    await ProjectService.createFile(tree!.path, name);
    await _reloadTree();
  }

  Future<void> _newFolder(String name) async {
    if (tree == null) {
      return;
    }

    await ProjectService.createFolder(tree!.path, name);
    await _reloadTree();
  }

  void _openBuildScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ProjectBuildScreen(projectName: widget.projectName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            tooltip: 'Build Project',
            onPressed: _openBuildScreen,
            icon: const Icon(Icons.build),
          ),
          ProjectPopupMenu(
            onCreateFile: _newFile,
            onCreateFolder: _newFolder,
            onBuildProject: _openBuildScreen,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tree == null) {
            return const Center(child: Text('Project not found'));
          }

          return RefreshIndicator(
            onRefresh: _reloadTree,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [FileTreeWidget(node: tree!, onRefresh: _reloadTree)],
            ),
          );
        },
      ),
    );
  }
}
