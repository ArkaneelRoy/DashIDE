import "package:flutter/material.dart";
import "package:flutter_code_editor/flutter_code_editor.dart";
import "package:flutter_highlight/themes/monokai-sublime.dart";

class CodeEditorView extends StatelessWidget {
  final CodeController controller;

  const CodeEditorView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CodeTheme(
      data: CodeThemeData(styles: monokaiSublimeTheme),
      child: SingleChildScrollView(
        child: CodeField(
          controller: controller,
          textStyle: const TextStyle(
            fontFamily: "monospace",
            fontSize: 14,
          ),
          gutterStyle: const GutterStyle(
            showLineNumbers: true,
            width: 50,
          ),
        ),
      ),
    );
  }
}
