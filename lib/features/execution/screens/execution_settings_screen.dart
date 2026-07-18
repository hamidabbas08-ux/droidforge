import 'package:flutter/material.dart';

import '../../../core/execution/execution_engine.dart';
import '../../../core/execution/execution_mode.dart';
import '../../../core/execution/execution_settings.dart';

class ExecutionSettingsScreen extends StatefulWidget {
  const ExecutionSettingsScreen({super.key});

  @override
  State<ExecutionSettingsScreen> createState() => _ExecutionSettingsScreenState();
}

class _ExecutionSettingsScreenState extends State<ExecutionSettingsScreen> {
  ExecutionMode _mode = ExecutionMode.automatic;
  String _status = 'Loading...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await ExecutionSettings.load();
    final status = await ExecutionEngine.supportMessage();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _status = status;
    });
  }

  Future<void> _select(ExecutionMode? mode) async {
    if (mode == null) return;
    await ExecutionSettings.save(mode);
    final status = await ExecutionEngine.supportMessage();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execution Environment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_status),
            ),
          ),
          const SizedBox(height: 12),
          ...ExecutionMode.values.map(
            (mode) => RadioListTile<ExecutionMode>(
              value: mode,
              groupValue: _mode,
              title: Text(mode.label),
              subtitle: Text(mode.description),
              onChanged: _select,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Important: Android, Termux, and Ubuntu PRoot use different app sandboxes. '
                'Selecting Android does not make Linux SDK binaries executable. The next bridge module will connect DroidForge to Termux/Ubuntu safely.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
