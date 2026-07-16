import 'package:flutter/material.dart';

class ProjectExplorerScreen extends StatefulWidget {
  final String projectName;

  const ProjectExplorerScreen({
    super.key,
    required this.projectName,
  });

  @override
  State<ProjectExplorerScreen> createState() =>
      _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends State<ProjectExplorerScreen> {
  bool appOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectName)),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              appOpen ? Icons.folder_open : Icons.folder,
            ),
            title: const Text("app"),
            trailing: Icon(
              appOpen ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                appOpen = !appOpen;
              });
            },
          ),

          if (appOpen) ...[
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("src"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text("build.gradle.kts"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text("proguard-rules.pro"),
              ),
            ),
          ],

          const Divider(),

          const ListTile(
            leading: Icon(Icons.folder),
            title: Text("gradle"),
          ),

          const ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("build.gradle.kts"),
          ),

          const ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("settings.gradle.kts"),
          ),

          const ListTile(
            leading: Icon(Icons.insert_drive_file),
            title: Text("gradle.properties"),
          ),
        ],
      ),
    );
  }
}
