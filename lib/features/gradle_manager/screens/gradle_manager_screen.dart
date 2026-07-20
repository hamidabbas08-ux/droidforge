import 'package:flutter/material.dart';

import '../controllers/gradle_manager_controller.dart';
import '../models/gradle_installation.dart';

class GradleManagerScreen extends StatefulWidget {
  const GradleManagerScreen({super.key});

  @override
  State<GradleManagerScreen> createState() => _GradleManagerScreenState();
}

class _GradleManagerScreenState extends State<GradleManagerScreen> {
  late final GradleManagerController controller;

  @override
  void initState() {
    super.initState();
    controller = GradleManagerController()..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _install(GradleInstallation installation) async {
    try {
      await controller.install(installation.version);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${installation.displayName} installed and selected.'),
        ),
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

  Future<void> _activate(GradleInstallation installation) async {
    try {
      await controller.activate(installation.version);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${installation.displayName} selected for builds.'),
        ),
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

  Future<void> _remove(GradleInstallation installation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${installation.displayName}?'),
        content: const Text(
          'The installed Gradle files will be deleted from DroidForge.',
        ),
        actions: <Widget>[
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
      await controller.remove(installation.version);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${installation.displayName} removed.')),
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

  String _status(GradleInstallation installation) {
    switch (installation.state) {
      case GradleInstallState.notInstalled:
        return 'Not installed';

      case GradleInstallState.downloading:
        return 'Downloading';

      case GradleInstallState.verifying:
        return 'Verifying package';

      case GradleInstallState.extracting:
        return 'Installing';

      case GradleInstallState.testing:
        return 'Testing Gradle';

      case GradleInstallState.installed:
        return 'Installed';

      case GradleInstallState.active:
        return 'Installed and active';

      case GradleInstallState.failed:
        return installation.error ?? 'Installation failed';
    }
  }

  IconData _icon(GradleInstallation installation) {
    if (installation.isActive) {
      return Icons.check_circle;
    }

    if (installation.isInstalled) {
      return Icons.download_done;
    }

    return Icons.download;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gradle Manager')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.installations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final installation = controller.installations[index];

              return Card(
                child: ListTile(
                  leading: Icon(_icon(installation)),
                  title: Text(installation.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_status(installation)),
                      if (installation.progress > 0 &&
                          installation.progress < 1) ...<Widget>[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: installation.progress),
                      ],
                      if (installation.installPath != null) ...<Widget>[
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
                  trailing: installation.isActive
                      ? const Text('Selected')
                      : installation.isInstalled
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'activate') {
                              _activate(installation);
                            } else if (value == 'remove') {
                              _remove(installation);
                            }
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'activate',
                              child: Text('Use for builds'),
                            ),
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Text('Remove'),
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: !controller.busy || installation.progress > 0,
                  onTap: controller.busy
                      ? null
                      : installation.isInstalled
                      ? () => _activate(installation)
                      : () => _install(installation),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
