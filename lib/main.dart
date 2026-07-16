import 'package:flutter/material.dart';
import 'features/projects/screens/projects_screen.dart';

void main() {
  runApp(const DroidForgeApp());
}

class DroidForgeApp extends StatelessWidget {
  const DroidForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DroidForge',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const ProjectsScreen(),
    );
  }
}
