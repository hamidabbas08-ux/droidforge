import 'package:flutter/material.dart';

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
  final TextEditingController controller = TextEditingController(
    text: """// Start Coding Here

fun main() {
    println("Hello DroidForge")
}
""",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: Padding(
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
          ),
        ),
      ),
    );
  }
}
