import 'package:flutter/material.dart';
import '../services/project_service.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final projectController = TextEditingController();
  final packageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Project")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: projectController,
            decoration: const InputDecoration(
              labelText: "Project Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: packageController,
            decoration: const InputDecoration(
              labelText: "Package Name",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          const ListTile(
            leading: Icon(Icons.android),
            title: Text("Language"),
            subtitle: Text("Kotlin"),
          ),

          const ListTile(
            leading: Icon(Icons.settings),
            title: Text("Minimum SDK"),
            subtitle: Text("Android 7.0 (API 24)"),
          ),

          const ListTile(
            leading: Icon(Icons.settings_applications),
            title: Text("Target SDK"),
            subtitle: Text("Android 16 (API 36)"),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () async {
              await ProjectService.createProject(
                projectName: projectController.text.trim(),
                packageName: packageController.text.trim(),
              );

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Project Created Successfully"),
                ),
              );
            },
            child: const Text("Create Project"),
          ),
        ],
      ),
    );
  }
}
