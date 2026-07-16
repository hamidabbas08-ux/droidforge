import 'package:flutter/material.dart';
import '../../../core/services/file_service.dart';

class CodeEditorScreen extends StatefulWidget {
  final String fileName;

  const CodeEditorScreen({
    super.key,
    required this.fileName,
  });

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> {
  final TextEditingController controller = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    final text = await FileService.readFile(widget.fileName);

    if (!mounted) return;

    setState(() {
      controller.text = text;
      loading = false;
    });
  }

  Future<void> _saveFile() async {
    await FileService.saveFile(
      widget.fileName,
      controller.text,
    );    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${widget.fileName} saved successfully"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveFile,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),                cursorColor: Colors.blue,
              ),
            ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
