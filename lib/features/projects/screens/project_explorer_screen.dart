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
                myAppOpen,
                () => setState(() => myAppOpen = !myAppOpen),
              ),
            ),

          if (myAppOpen)
            const Padding(
              padding: EdgeInsets.only(left: 140),
              child: ListTile(
                leading: Icon(Icons.code),
                title: Text("MainActivity.kt"),
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

          if (mainOpen)
            const Padding(
              padding: EdgeInsets.only(left: 60),
              child: ListTile(
                leading: Icon(Icons.description),
                title: Text("AndroidManifest.xml"),
              ),
            ),

          const Divider(),

          const ListTile(
            leading: Icon(Icons.folder),
            title: Text("gradle"),
          ),

          const ListTile(
            leading: Icon(Icons.description),
            title: Text("build.gradle.kts"),
          ),

          const ListTile(
            leading: Icon(Icons.description),
            title: Text("settings.gradle.kts"),
          ),

          const ListTile(
            leading: Icon(Icons.description),
            title: Text("gradle.properties"),
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
      title: Text(title),
      trailing: Icon(
        open ? Icons.expand_less : Icons.expand_more,
      ),
      onTap: onTap,
    );
  }
}
