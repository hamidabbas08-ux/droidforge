import 'dart:io';

import 'package:flutter/material.dart';

class CodeEditorScreen extends StatefulWidget {
  final String fileName;

  const CodeEditorScreen({
    super.key,
    required this.fileName,
  });

  @override
  State<CodeEditorScreen> createState() =>
      _CodeEditorScreenState();
}

class _CodeEditorScreenState
    extends State<CodeEditorScreen> {

  final TextEditingController controller =
      TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.fileName);

      if (await file.exists()) {
        controller.text =
            await file.readAsString();
      } else {
        controller.text = "";
      }
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        controller.text = "// Error reading file\n$e";
        loading = false;
      });
    }
  }

  Future<void> _saveFile() async {
    try {
      final file = File(widget.fileName);

      await file.parent.create(recursive: true);
      await file.writeAsString(controller.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${widget.fileName} saved successfully",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving file:\n$e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName.split('/').last),
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
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                cursorColor: Colors.blue,
              ),
            ),
    );
  }  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
