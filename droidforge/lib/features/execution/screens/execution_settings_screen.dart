import 'package:flutter/material.dart';

class ExecutionSettingsScreen extends StatelessWidget {
  const ExecutionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execution Environment')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.android),
              title: Text('Android'),
              subtitle: Text('Android local execution is permanently selected.'),
              trailing: Icon(Icons.check_circle),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This build is Android-only. Linux, Ubuntu, Termux and PRoot modes are disabled.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
