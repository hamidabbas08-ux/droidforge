import 'package:flutter/material.dart';

class ProjectExplorerScreen extends StatelessWidget {
  final String projectName;

  const ProjectExplorerScreen({
    super.key,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(projectName),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.folder),
            title: Text("app"),
          ),
          ListTile(
            leading: Icon(Icons.folder),
            title: Text("gradle"),
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("build.gradle.kts"),
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("settings.gradle.kts"),
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("gradle.properties"),
          ),
        ],
      ),
    );
  }
}
