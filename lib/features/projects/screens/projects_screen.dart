
import 'package:flutter/material.dart';
import '../../jdk_manager/screens/jdk_manager_screen.dart';
import '../../sdk_manager/screens/sdk_manager_screen.dart';
import '../../execution/screens/execution_settings_screen.dart';
import 'new_project_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Projects")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.add),
              title: const Text("New Project"),
              subtitle: const Text("Create a new Android project"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewProjectScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text("Execution Environment"),
              subtitle: const Text("Android only"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExecutionSettingsScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("JDK Manager"),
              subtitle: const Text("Choose the JDK used by Gradle builds"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JdkManagerScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.android),
              title: const Text("Android SDK Manager"),
              subtitle: const Text("Install SDK tools used by Gradle builds"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SdkManagerScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text("Open Project"),
              subtitle: const Text("Coming Soon"),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.archive),
              title: const Text("Import ZIP"),
              subtitle: const Text("Coming Soon"),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text("Clone Git Repository"),
              subtitle: const Text("Coming Soon"),
            ),
          ),
        ],
      ),
    );
  }
}
