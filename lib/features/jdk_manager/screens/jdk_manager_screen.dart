import 'package:flutter/material.dart';

import '../../../core/process/native_process_service.dart';

import '../controllers/jdk_manager_controller.dart';
import '../models/jdk_installation.dart';

class JdkManagerScreen extends StatefulWidget {
  const JdkManagerScreen({super.key});

  @override
  State<JdkManagerScreen> createState() => _JdkManagerScreenState();
}

class _JdkManagerScreenState extends State<JdkManagerScreen> {
  late final JdkManagerController controller;

  @override
  void initState() {
    super.initState();
    controller = JdkManagerController()..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _runNativeTest() async {
    try {
      final result = await const NativeProcessService().runBundledNativeTest();

      if (!mounted) return;

      final output = result.combinedOutput.isEmpty
          ? 'Exit code: ${result.exitCode}'
          : result.combinedOutput;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            result.succeeded ? 'Native Test Passed' : 'Native Test Failed',
          ),
          content: SelectableText(output),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Native Test Error'),
          content: SelectableText(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _install(JdkInstallation installation) async {
    try {
      await controller.install(installation.version);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${installation.displayName} installed and selected.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _reinstall(JdkInstallation installation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reinstall ${installation.displayName}?'),
        content: const Text(
          'DroidForge will download and verify the new JDK first. '
          'If replacement fails, the existing JDK will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reinstall'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await controller.install(installation.version);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${installation.displayName} replaced and selected.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Replacement failed. Existing JDK was preserved.\n$error',
          ),
        ),
      );
    }
  }

  Future<void> _activate(JdkInstallation installation) async {
    try {
      await controller.activate(installation.version);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _remove(JdkInstallation installation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${installation.displayName}?'),
        content: const Text(
          'The installed JDK files will be deleted from DroidForge.',
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

    if (confirmed != true) return;

    await controller.remove(installation.version);
  }

  String _status(JdkInstallation installation) {
    switch (installation.state) {
      case JdkInstallState.notInstalled:
        return 'Not installed';
      case JdkInstallState.downloading:
        return 'Downloading';
      case JdkInstallState.verifying:
        return 'Verifying package';
      case JdkInstallState.extracting:
        return 'Installing';
      case JdkInstallState.installed:
        return 'Installed';
      case JdkInstallState.active:
        return 'Installed and active';
      case JdkInstallState.failed:
        return installation.error ?? 'Installation failed';
    }
  }

  IconData _icon(JdkInstallation installation) {
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
      appBar: AppBar(
        title: const Text('JDK Manager'),
        actions: [
          IconButton(
            tooltip: 'Run native test',
            onPressed: _runNativeTest,
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.installations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final installation = controller.installations[index];

              return Card(
                child: ListTile(
                  leading: Icon(_icon(installation)),
                  title: Text(installation.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_status(installation)),
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
                          tooltip: installation.isActive
                              ? 'Selected JDK options'
                              : 'JDK options',
                          onSelected: (value) {
                            if (value == 'activate') {
                              _activate(installation);
                            } else if (value == 'reinstall') {
                              _reinstall(installation);
                            } else if (value == 'remove') {
                              _remove(installation);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!installation.isActive)
                              const PopupMenuItem(
                                value: 'activate',
                                child: Text('Use for builds'),
                              ),
                            const PopupMenuItem(
                              value: 'reinstall',
                              child: Text('Reinstall / Replace'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove'),
                            ),
                          ],
                          child: installation.isActive
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Selected'),
                                    SizedBox(width: 4),
                                    Icon(Icons.more_vert),
                                  ],
                                )
                              : const Icon(Icons.more_vert),
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
