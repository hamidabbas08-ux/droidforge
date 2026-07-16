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
  bool srcOpen = false;
  bool mainOpen = false;
  bool javaOpen = false;
  bool comOpen = false;
  bool hamidOpen = false;
  bool myAppOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectName)),
      body: ListView(
        children: [

          ListTile(
            leading: Icon(appOpen ? Icons.folder_open : Icons.folder),
            title: const Text("app"),
            trailing: Icon(appOpen
                ? Icons.expand_less
                : Icons.expand_more),
            onTap: () {
              setState(() {
                appOpen = !appOpen;
              });
            },
          ),

          if (appOpen) ...[

            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: ListTile(
                leading: Icon(srcOpen ? Icons.folder_open : Icons.folder),
                title: const Text("src"),
                trailing: Icon(srcOpen
                    ? Icons.expand_less
                    : Icons.expand_more),
                onTap: () {
                  setState(() {
                    srcOpen = !srcOpen;
                  });
                },
              ),
            ),

            if (srcOpen) ...[

              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: ListTile(
                  leading: Icon(mainOpen ? Icons.folder_open : Icons.folder),
                  title: const Text("main"),
                  trailing: Icon(mainOpen
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onTap: () {
                    setState(() {
                      mainOpen = !mainOpen;
                    });
                  },
                ),
              ),

              if (mainOpen) ...[

                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: ListTile(
                    leading: Icon(javaOpen
                        ? Icons.folder_open
                        : Icons.folder),
                    title: const Text("java"),
                    trailing: Icon(javaOpen
                        ? Icons.expand_less
                        : Icons.expand_more),
                    onTap: () {
                      setState(() {
                        javaOpen = !javaOpen;
                      });
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: const ListTile(
                    leading: Icon(Icons.folder),
                    title: Text("res"),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 72),
                  child: const ListTile(
                    leading: Icon(Icons.insert_drive_file),
                    title: Text("AndroidManifest.xml"),
                  ),
                ),

              ],

            ],

            const Padding(
              padding: EdgeInsets.only(left: 24),
              child: ListTile(
                leading: Icon(Icons.insert_drive_file),
                title: Text("build.gradle.kts"),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 24),
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
