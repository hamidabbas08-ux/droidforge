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
              title: Text('Android only'),
              subtitle: Text('Local Android execution is permanently active.'),
              trailing: Icon(Icons.check_circle),
            ),
          ),
        ],
      ),
    );
  }
}
