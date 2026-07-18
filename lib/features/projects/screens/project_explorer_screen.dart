
import 'package:flutter/material.dart';

import '../../jdk_manager/services/gradle_build_service.dart';
import '../models/file_tree_node.dart';
import '../services/project_service.dart';
import '../widgets/file_tree_widget.dart';
import 'project_popup_menu.dart';

class ProjectExplorerScreen extends StatefulWidget {
  final String projectName;

  const ProjectExplorerScreen({super.key, required this.projectName});

  @override
  State<ProjectExplorerScreen> createState() => _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends State<ProjectExplorerScreen> {
  FileTreeNode? tree;
  bool loading = true;
  bool building = false;
  String buildLog = '';

  @override
  void initState() {
    super.initState();
    _reloadTree();
  }

  Future<void> _reloadTree() async {
    setState(() => loading = true);
    try {
      final result = await ProjectService.loadProjectTree(widget.projectName);
      if (!mounted) return;
      setState(() {
        tree = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _buildDebug() async {
    if (building || tree == null) return;
    setState(() {
      building = true;
      buildLog = '';
    });

    try {
      final result = await GradleBuildService.assembleDebug(
        projectPath: tree!.path,
        onOutput: (line) {
          if (!mounted) return;
          setState(() => buildLog = '$buildLog$line\n');
        },
      );

      if (!mounted) return;
      setState(() => building = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.success ? 'Build successful' : 'Build failed (exit ${result.exitCode})')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => building = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _newFile(String name) async {
    if (tree == null) return;
    await ProjectService.createFile(tree!.path, name);
    await _reloadTree();
  }

  Future<void> _newFolder(String name) async {
    if (tree == null) return;
    await ProjectService.createFolder(tree!.path, name);
    await _reloadTree();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            tooltip: 'Build Debug',
            onPressed: building ? null : _buildDebug,
            icon: building
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build),
          ),
          ProjectPopupMenu(onCreateFile: _newFile, onCreateFolder: _newFolder),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (loading) return const Center(child: CircularProgressIndicator());
          if (tree == null) return const Center(child: Text("Project not found"));

          return RefreshIndicator(
            onRefresh: _reloadTree,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                FileTreeWidget(node: tree!, onRefresh: _reloadTree),
                if (buildLog.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Build output'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(buildLog),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
