import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

class CodeEditorView extends StatelessWidget {
  final CodeController controller;

  const CodeEditorView({super.key, required this.controller});

  void _insertText(String symbol) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, symbol);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    const symbols = <String>[
      '{',
      '}',
      '(',
      ')',
      ';',
      '"',
      "'",
      '=',
      '=>',
      'Tab',
      '//',
      '<',
      '>',
      '.',
    ];

    return Column(
      children: [
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: atomOneDarkTheme),
            child: SingleChildScrollView(
              child: CodeField(
                controller: controller,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                gutterStyle: const GutterStyle(
                  showLineNumbers: true,
                  width: 52,
                ),
              ),
            ),
          ),
        ),
        Container(
          color: const Color(0xFF21252B),
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: symbols.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = symbols[index];
              return InkWell(
                onTap: () {
                  if (item == 'Tab') {
                    _insertText('  ');
                  } else {
                    _insertText(item);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282C34),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF3B4048)),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFABB2BF),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
