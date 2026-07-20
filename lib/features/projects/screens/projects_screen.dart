import 'package:flutter/material.dart';

import '../../jdk_manager/screens/jdk_manager_screen.dart';
import 'new_project_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Project'),
              subtitle: const Text('Create a new Android project'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewProjectScreen(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('JDK Manager'),
              subtitle: const Text('Install and select a JDK'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JdkManagerScreen(),
                  ),
                );
              },
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('Open Project'),
              subtitle: Text('Coming Soon'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.archive),
              title: Text('Import ZIP'),
              subtitle: Text('Coming Soon'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_download),
              title: Text('Clone Git Repository'),
              subtitle: Text('Coming Soon'),
            ),
          ),
        ],
      ),
    );
  }
}
