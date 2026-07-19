import 'package:flutter/material.dart';

import '../../../core/runtime/native_runtime_service.dart';

class RuntimeFoundationScreen extends StatefulWidget {
  const RuntimeFoundationScreen({super.key});

  @override
  State<RuntimeFoundationScreen> createState() =>
      _RuntimeFoundationScreenState();
}

class _RuntimeFoundationScreenState extends State<RuntimeFoundationScreen> {
  RuntimeFoundationReport? report;
  Object? error;
  bool running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (running) return;
    setState(() {
      running = true;
      error = null;
    });
    try {
      final value = await NativeRuntimeService.foundationHealthCheck();
      if (!mounted) return;
      setState(() => report = value);
    } catch (exception) {
      if (!mounted) return;
      setState(() => error = exception);
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Execution Foundation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    current?.ready == true
                        ? Icons.verified
                        : running
                            ? Icons.hourglass_top
                            : Icons.build_circle,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current?.ready == true
                              ? 'Foundation Ready'
                              : running
                                  ? 'Running health checks…'
                                  : 'Foundation needs attention',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This is the clean execution base. JDK 17 work starts only after it passes.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (running) const LinearProgressIndicator(),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Health check error: $error'),
              ),
            ),
          if (current != null) ...[
            for (final entry in current.checks.entries)
              Card(
                child: ListTile(
                  leading: Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                  ),
                  title: Text(_title(entry.key)),
                  subtitle: Text(current.details[entry.key] ?? ''),
                ),
              ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Runtime directories'),
              children: [
                for (final entry in current.environment.entries)
                  ListTile(
                    dense: true,
                    title: Text(entry.key),
                    subtitle: SelectableText(entry.value),
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Health-check log'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(current.logs.join('\n')),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: running ? null : _run,
            icon: const Icon(Icons.refresh),
            label: const Text('Run Execution Foundation Test'),
          ),
        ],
      ),
    );
  }

  String _title(String key) {
    const titles = {
      'arm64': 'Android ARM64 device',
      'nativeLibrary': 'APK-packaged native library',
      'backgroundWorker': 'Background worker',
      'directoryLayout': 'Runtime directory layout',
      'fileIo': 'Runtime file I/O',
      'processRunner': 'Android process runner',
    };
    return titles[key] ?? key;
  }
}
