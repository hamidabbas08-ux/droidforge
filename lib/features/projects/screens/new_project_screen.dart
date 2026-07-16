import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'project_explorer_screen.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ProjectService.createProject(
                    projectName: projectController.text.trim(),
                    packageName: packageController.text.trim(),
                  );

                  if (!context.mounted) return;

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectExplorerScreen(
                        projectName: projectController.text.trim(),
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint(e.toString());

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                    ),
                  );
                }
              },
              child: const Text("Create Project"),
            ),
          ],
        ),
      ),
    );
  }
}
