import 'package:flutter/material.dart';
import '../../editor/screens/code_editor_screen.dart';

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
  bool myappOpen = false;
  bool resOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
      ),
      body: ListView(
        children: [

          _folder(
            "app",
            appOpen,
            () => setState(() => appOpen = !appOpen),
          ),

          if (appOpen)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _folder(
                "src",
                srcOpen,
                () => setState(() => srcOpen = !srcOpen),
              ),
            ),

          if (srcOpen)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: _folder(
                "main",
                mainOpen,
                () => setState(() => mainOpen = !mainOpen),
              ),
            ),

          if (mainOpen)
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: _folder(
                "java",
                javaOpen,
                () => setState(() => javaOpen = !javaOpen),
              ),
            ),

          if (javaOpen)
            Padding(
              padding: const EdgeInsets.only(left: 80),
              child: _folder(
                "com",
                comOpen,
                () => setState(() => comOpen = !comOpen),
              ),
            ),

          if (comOpen)
            Padding(
              padding: const EdgeInsets.only(left: 100),
              child: _folder(
                "hamid",
                hamidOpen,
                () => setState(() => hamidOpen = !hamidOpen),
              ),
            ),

          if (hamidOpen)
            Padding(
              padding: const EdgeInsets.only(left: 120),
              child: _folder(
                "myapp",
                myappOpen,
                () => setState(() => myappOpen = !myappOpen),
              ),
            ),          if (myappOpen)
            Padding(
              padding: const EdgeInsets.only(left: 140),
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text("MainActivity.kt"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CodeEditorScreen(
                        fileName: "MainActivity.kt",
                      ),
                    ),
                  );
                },
              ),
            ),

          if (mainOpen)
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: _folder(
                "res",
                resOpen,
                () => setState(() => resOpen = !resOpen),
              ),
            ),

          if (resOpen) ...[
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("drawable"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("layout"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("mipmap"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("values"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("menu"),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 80),
              child: ListTile(
                leading: Icon(Icons.folder),
                title: Text("xml"),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: ListTile(
              leading: const Icon(Icons.description),
              title: const Text("AndroidManifest.xml"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CodeEditorScreen(
                      fileName: "AndroidManifest.xml",
                    ),
                  ),
                );
              },
            ),
          ),          const Divider(),

          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("build.gradle.kts"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CodeEditorScreen(
                    fileName: "build.gradle.kts",
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("settings.gradle.kts"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CodeEditorScreen(
                    fileName: "settings.gradle.kts",
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("gradle.properties"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CodeEditorScreen(
                    fileName: "gradle.properties",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _folder(
    String title,
    bool open,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        open ? Icons.folder_open : Icons.folder,
      ),
      trailing: Icon(
        open ? Icons.expand_less : Icons.expand_more,
      ),
      title: Text(title),
      onTap: onTap,
    );
  }
}
