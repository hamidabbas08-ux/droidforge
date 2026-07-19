
import 'package:flutter/material.dart';

import '../models/jdk_version.dart';
import '../services/jdk_service.dart';

class JdkManagerScreen extends StatefulWidget {
  const JdkManagerScreen({super.key});

  @override
  State<JdkManagerScreen> createState() => _JdkManagerScreenState();
}

class _JdkManagerScreenState extends State<JdkManagerScreen> {
  JdkVersion? active;
  final installed = <int>{};
  int? busyMajor;
  double progress = 0;
  String status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selected = await JdkService.activeVersion();
    final found = <int>{};
    for (final version in JdkVersion.supported) {
      if (await JdkService.isInstalled(version)) found.add(version.major);
    }
    if (!mounted) return;
    setState(() {
      active = selected;
      installed
        ..clear()
        ..addAll(found);
    });
  }

  Future<void> _tap(JdkVersion version) async {
    if (busyMajor != null) return;

    if (!version.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${version.label} is Coming Soon.')),
      );
      return;
    }

    if (installed.contains(version.major)) {
      await JdkService.select(version);
      if (mounted) setState(() => active = version);
      return;
    }

    setState(() {
      busyMajor = version.major;
      progress = 0;
      status = 'Starting...';
    });

    try {
      await JdkService.install(
        version,
        onProgress: (value, text) {
          if (!mounted) return;
          setState(() {
            progress = value;
            status = text;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        installed.add(version.major);
        active = version;
        busyMajor = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => busyMajor = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JDK Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Test the APK-bundled Android ARM64 JVM foundation. Gradle execution is a later milestone.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          for (final version in JdkVersion.supported)
            Card(
              child: ListTile(
                leading: const Icon(Icons.coffee),
                title: Text(version.label),
                subtitle: busyMajor == version.major
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress == 0 ? null : progress),
                          const SizedBox(height: 4),
                          Text(status),
                        ],
                      )
                    : Text(
                        installed.contains(version.major)
                            ? (active?.major == version.major ? 'Embedded JVM foundation ready' : 'Installed')
                            : version.availabilityLabel,
                      ),
                trailing: active?.major == version.major
                    ? const Icon(Icons.check_circle)
                    : version.available
                        ? const Icon(Icons.chevron_right)
                        : const Chip(label: Text('Coming Soon')),
                onTap: () => _tap(version),
              ),
            ),
        ],
      ),
    );
  }
}
