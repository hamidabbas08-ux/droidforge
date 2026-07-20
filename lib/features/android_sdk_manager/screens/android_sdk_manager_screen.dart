import 'package:flutter/material.dart';

import '../controllers/android_sdk_manager_controller.dart';
import '../models/android_sdk_installation.dart';

class AndroidSdkManagerScreen extends StatefulWidget {
  const AndroidSdkManagerScreen({super.key});

  @override
  State<AndroidSdkManagerScreen> createState() =>
      _AndroidSdkManagerScreenState();
}

class _AndroidSdkManagerScreenState extends State<AndroidSdkManagerScreen> {
  late final AndroidSdkManagerController controller;

  @override
  void initState() {
    super.initState();
    controller = AndroidSdkManagerController()..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _status(AndroidSdkInstallation installation) {
    switch (installation.state) {
      case AndroidSdkInstallState.notInstalled:
        return 'Not installed';

      case AndroidSdkInstallState.downloading:
        return 'Downloading';

      case AndroidSdkInstallState.verifying:
        return 'Verifying package';

      case AndroidSdkInstallState.extracting:
        return 'Installing SDK packages';

      case AndroidSdkInstallState.installed:
        return 'Installed';

      case AndroidSdkInstallState.active:
        return 'Installed and active';

      case AndroidSdkInstallState.failed:
        return installation.error ?? 'Android SDK installation failed';
    }
  }

  IconData _icon(AndroidSdkInstallation installation) {
    if (installation.isActive) {
      return Icons.check_circle;
    }

    if (installation.state == AndroidSdkInstallState.failed) {
      return Icons.error_outline;
    }

    if (controller.busy) {
      return Icons.downloading;
    }

    return Icons.download;
  }

  Future<void> _installSdk() async {
    try {
      await controller.install();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android SDK installed successfully')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _removeSdk() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Android SDK?'),
        content: const Text(
          'All Android SDK files installed by DroidForge will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await controller.remove();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Android SDK removed')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _action(AndroidSdkInstallation installation) {
    if (controller.busy) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }

    if (installation.isInstalled) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'remove') {
            _removeSdk();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(value: 'remove', child: Text('Remove')),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: _installSdk,
      icon: const Icon(Icons.download),
      label: const Text('Install'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android SDK Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.busy ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final installation = controller.installation;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_icon(installation), size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Android SDK 35',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(_status(installation)),
                                const SizedBox(height: 6),
                                const Text(
                                  'Platform 35, Build Tools 35.0.0 '
                                  'and ARM64 Platform Tools',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _action(installation),
                        ],
                      ),
                      if (installation.progress > 0 &&
                          installation.progress < 1) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: installation.progress),
                        const SizedBox(height: 8),
                        Text('${(installation.progress * 100).round()}%'),
                      ],
                      if (installation.installPath != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Installed at:',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          installation.installPath!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (installation.state == AndroidSdkInstallState.failed &&
                          installation.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          installation.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
