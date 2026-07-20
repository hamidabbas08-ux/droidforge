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
        return 'Verifying packages';
      case AndroidSdkInstallState.extracting:
        return 'Installing packages';
      case AndroidSdkInstallState.installed:
        return 'Installed';
      case AndroidSdkInstallState.active:
        return 'Installed and active';
      case AndroidSdkInstallState.failed:
        return installation.error ?? 'Android SDK operation failed';
    }
  }

  IconData _icon(AndroidSdkInstallation installation) {
    if (installation.isActive) {
      return Icons.check_circle;
    }

    if (installation.state == AndroidSdkInstallState.failed) {
      return Icons.error_outline;
    }

    return Icons.download;
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
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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
                child: ListTile(
                  leading: Icon(_icon(installation)),
                  title: const Text('Android SDK 35'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_status(installation)),
                      const SizedBox(height: 4),
                      const Text(
                        'Platform 35, Build Tools 35.0.0 and Platform Tools',
                      ),
                      if (installation.progress > 0 &&
                          installation.progress < 1) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: installation.progress),
                      ],
                      if (installation.installPath != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          installation.installPath!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  trailing: installation.isInstalled
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'remove') {
                              _removeSdk();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove'),
                            ),
                          ],
                        )
                      : const Text('Installer next'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
