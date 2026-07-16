import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  Widget item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Projects"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          item(
            context,
            Icons.add_circle,
            "New Project",
            "Create a new Android project",
          ),
          item(
            context,
            Icons.folder_open,
            "Open Project",
            "Open an existing project",
          ),
          item(
            context,
            Icons.archive,
            "Import ZIP",
            "Import a ZIP project",
          ),
          item(
            context,
            Icons.download,
            "Clone Git Repository",
            "Clone from GitHub",
          ),
        ],
      ),
    );
  }
}
