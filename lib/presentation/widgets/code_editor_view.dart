import "package:flutter/material.dart";
import "package:re_editor/re_editor.dart";
import "package:re_highlight/languages/dart.dart";
import "package:re_highlight/styles/monokai-sublime.dart";

class CodeEditorView extends StatelessWidget {
  final CodeEditorController controller;

  const CodeEditorView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CodeEditor(
      controller: controller,
      style: CodeEditorStyle(
        fontSize: 14,
        fontFamily: "monospace",
        codeTheme: CodeHighlightTheme(
          languages: {"dart": CodeHighlightThemeMode(mode: langDart)},
          theme: monokaiSublimeTheme,
        ),
      ),
      indicatorBuilder: (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            DefaultCodeChunkIndicator(
              width: 16,
              controller: chunkController,
              notifier: notifier,
            )
          ],
        );
      },
    );
  }
}
