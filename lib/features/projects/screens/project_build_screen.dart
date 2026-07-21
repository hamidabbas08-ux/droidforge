import 'package:flutter/material.dart';

import '../models/project_build_result.dart';
import '../services/project_build_service.dart';

class ProjectBuildScreen extends StatefulWidget {
  const ProjectBuildScreen({super.key, required this.projectName});

  final String projectName;

  @override
  State<ProjectBuildScreen> createState() => _ProjectBuildScreenState();
}

class _ProjectBuildScreenState extends State<ProjectBuildScreen> {
  final ProjectBuildService _buildService = ProjectBuildService();

  ProjectBuildType _selectedType = ProjectBuildType.debugApk;

  ProjectBuildResult? _result;

  bool _building = false;
  bool _diagnosing = false;

  double _progress = 0;
  String _stage = 'Ready';
  String _log = '';

  bool get _busy => _building || _diagnosing;

  Future<void> _startBuild() async {
    if (_busy) {
      return;
    }

    setState(() {
      _building = true;
      _progress = 0;
      _stage = 'Preparing build';
      _log = '';
      _result = null;
    });

    try {
      final result = await _buildService.build(
        projectName: widget.projectName,
        type: _selectedType,
        onProgress: _updateProgress,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _stage = '${result.type.displayName} completed';
        _progress = 1;
        _log = result.processResult.combinedOutput.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.type.displayName} '
            'created successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _stage = 'Build failed';
        _log = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kotlin Android build failed.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _building = false;
        });
      }
    }
  }

  Future<void> _startDiagnostic() async {
    if (_busy) {
      return;
    }

    setState(() {
      _diagnosing = true;
      _result = null;
      _progress = 0;
      _stage = 'Preparing runtime diagnostic';
      _log = '';
    });

    try {
      final report = await _buildService.runRuntimeDiagnostic(
        projectName: widget.projectName,
        onProgress: _updateProgress,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stage = 'Runtime diagnostic completed';
        _progress = 1;
        _log = report;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Runtime diagnostic completed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _stage = 'Runtime diagnostic failed';
        _log = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Runtime diagnostic could not complete.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _diagnosing = false;
        });
      }
    }
  }

  void _updateProgress(String stage, double progress) {
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = stage;
      _progress = progress.clamp(0.0, 1.0);
    });
  }

  void _selectType(ProjectBuildType type) {
    if (_busy) {
      return;
    }

    setState(() {
      _selectedType = type;
      _result = null;
      _log = '';
      _stage = 'Ready';
      _progress = 0;
    });
  }

  Widget _buildTypeCard(ProjectBuildType type) {
    final selected = _selectedType == type;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        selected: selected,
        enabled: !_busy,
        onTap: () => _selectType(type),
        leading: Icon(_iconFor(type)),
        title: Text(type.displayName),
        subtitle: Text(_descriptionFor(type)),
        trailing: selected
            ? const Icon(Icons.check_circle)
            : const Icon(Icons.circle_outlined),
      ),
    );
  }

  IconData _iconFor(ProjectBuildType type) {
    return switch (type) {
      ProjectBuildType.debugApk => Icons.bug_report_outlined,
      ProjectBuildType.releaseApk => Icons.android_outlined,
      ProjectBuildType.releaseAab => Icons.inventory_2_outlined,
    };
  }

  String _descriptionFor(ProjectBuildType type) {
    return switch (type) {
      ProjectBuildType.debugApk => 'Installable APK for testing.',
      ProjectBuildType.releaseApk => 'Release APK for Signing Manager.',
      ProjectBuildType.releaseAab => 'Android App Bundle for Play Store.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Build Project')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.projectName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Native Kotlin Android project'),
          const SizedBox(height: 20),
          Text(
            'Select build output',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildTypeCard(ProjectBuildType.debugApk),
          _buildTypeCard(ProjectBuildType.releaseApk),
          _buildTypeCard(ProjectBuildType.releaseAab),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _startBuild,
            icon: _building
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build),
            label: Text(
              _building
                  ? 'Building...'
                  : 'Build '
                        '${_selectedType.displayName}',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _startDiagnostic,
            icon: _diagnosing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.monitor_heart_outlined),
            label: Text(
              _diagnosing ? 'Running diagnostic...' : 'Run Runtime Diagnostic',
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Build and runtime status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _busy || _progress > 0 ? _progress : 0,
                  ),
                  const SizedBox(height: 12),
                  Text(_stage),
                  Text('${(_progress * 100).round()}%'),
                ],
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text('${result.type.displayName} ready'),
                subtitle: SelectableText(result.outputPath),
              ),
            ),
          ],
          if (_log.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.terminal),
                title: const Text('Build / diagnostic log'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _log,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
