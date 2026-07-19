import 'package:flutter/material.dart';

import '../services/android_sdk_service.dart';

class SdkManagerScreen extends StatefulWidget {
  const SdkManagerScreen({super.key});

  @override
  State<SdkManagerScreen> createState() => _SdkManagerScreenState();
}

class _SdkManagerScreenState extends State<SdkManagerScreen> {
  AndroidSdkStatus? sdkStatus;
  bool busy = false;
  double progress = 0;
  String message = '';
  final output = <String>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await AndroidSdkService.status();
    if (mounted) setState(() => sdkStatus = value);
  }

  Future<void> _install() async {
    if (busy) return;
    setState(() {
      busy = true;
      progress = 0;
      message = 'Starting...';
      output.clear();
    });

    try {
      await AndroidSdkService.installRequired(
        onProgress: (value, text) {
          if (!mounted) return;
          setState(() {
            progress = value;
            message = text;
          });
        },
        onOutput: (line) {
          if (!mounted || line.trim().isEmpty) return;
          setState(() {
            output.add(line);
            if (output.length > 80) output.removeAt(0);
          });
        },
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android SDK installed and ready for Gradle.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _packageTile(String title, String subtitle, bool installed) {
    return ListTile(
      leading: Icon(installed ? Icons.check_circle : Icons.download_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(installed ? 'Installed' : 'Required'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = sdkStatus;
    return Scaffold(
      appBar: AppBar(title: const Text('Android SDK Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            value == null ? 'Checking SDK...' : 'SDK path: ${value.sdkPath}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _packageTile(
                  'Command-line Tools',
                  'sdkmanager and Android command-line utilities',
                  value?.commandLineTools ?? false,
                ),
                const Divider(height: 1),
                _packageTile(
                  'Platform Tools',
                  'adb and platform utilities',
                  value?.platformTools ?? false,
                ),
                const Divider(height: 1),
                _packageTile(
                  'Android Platform ${AndroidSdkService.apiLevel}',
                  'android.jar used to compile Android projects',
                  value?.platform ?? false,
                ),
                const Divider(height: 1),
                _packageTile(
                  'Build Tools ${AndroidSdkService.buildToolsVersion}',
                  'aapt2, d8, apksigner and packaging tools',
                  value?.buildTools ?? false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'V9 accepts Android ARM64 packages only. Incompatible desktop/Linux SDK archives are blocked.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy || (value?.ready ?? false) ? null : _install,
            icon: Icon((value?.ready ?? false) ? Icons.check : Icons.download),
            label: Text((value?.ready ?? false) ? 'SDK Ready' : 'Install Required SDK'),
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress <= 0 ? null : progress),
            const SizedBox(height: 8),
            Text(message),
          ],
          if (output.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Installation output'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    output.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'JDK 17 must be verified first. JDK 21 and JDK 24 remain visible as Coming Soon.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
