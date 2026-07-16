import 'package:flutter/material.dart';

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget tile(BuildContext context, IconData icon, String title) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DroidForge IDE"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tile(context, Icons.folder, "Projects"),
          tile(context, Icons.folder_open, "File Manager"),
          tile(context, Icons.code, "Code Editor"),
          tile(context, Icons.build, "Build APK"),
          tile(context, Icons.play_arrow, "Run"),
          tile(context, Icons.android, "SDK Manager"),
          tile(context, Icons.memory, "JDK Manager"),
          tile(context, Icons.extension, "Gradle Manager"),
          tile(context, Icons.verified_user, "Signing"),
          tile(context, Icons.settings, "Settings"),
        ],
      ),
    );
  }
}
