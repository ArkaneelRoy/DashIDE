import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

class CodeEditorView extends StatefulWidget {
  final CodeController controller;
  final VoidCallback? onCursorMoved;

  const CodeEditorView({
    super.key,
    required this.controller,
    this.onCursorMoved,
  });

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends State<CodeEditorView> {
  double _fontSize = 13.0;
  bool _showFindBar = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleCursorChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleCursorChange);
    super.dispose();
  }

  void _handleCursorChange() {
    widget.onCursorMoved?.call();
  }

  void _insertText(String symbol) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, symbol);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
  }

  void _findAndHighlight() {
    final query = _findController.text;
    if (query.isEmpty) return;

    final text = widget.controller.text;
    final currentOffset = widget.controller.selection.end;
    var nextIndex = text.indexOf(query, currentOffset >= 0 ? currentOffset : 0);

    if (nextIndex == -1) {
      nextIndex = text.indexOf(query, 0);
    }

    if (nextIndex != -1) {
      widget.controller.selection = TextSelection(
        baseOffset: nextIndex,
        extentOffset: nextIndex + query.length,
      );
    }
  }

  void _replaceMatch() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final selection = widget.controller.selection;
    if (selection.start >= 0 && selection.end > selection.start) {
      final selectedText = widget.controller.text.substring(selection.start, selection.end);
      if (selectedText == query) {
        final newText = widget.controller.text.replaceRange(selection.start, selection.end, replacement);
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + replacement.length),
        );
        _findAndHighlight();
        return;
      }
    }
    _findAndHighlight();
  }

  void _replaceAll() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final newText = widget.controller.text.replaceAll(query, replacement);
    widget.controller.text = newText;
  }

  @override
  Widget build(BuildContext context) {
    const symbols = <String>[
      '{', '}', '(', ')', ';', '"', "'", '=', '=>', 'Tab', '//', '<', '>', '.'
    ];

    return Column(
      children: [
        if (_showFindBar)
          Container(
            color: const Color(0xFF21252B),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _findController,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: const Color(0xFF1E2227),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _findAndHighlight(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Next',
                      onPressed: _findAndHighlight,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => setState(() => _showFindBar = false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _replaceController,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Replace with...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            filled: true,
                            fillColor: const Color(0xFF1E2227),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(50, 26),
                        side: const BorderSide(color: Color(0xFF3B4048)),
                      ),
                      onPressed: _replaceMatch,
                      child: const Text('Replace', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(36, 26),
                        side: const BorderSide(color: Color(0xFF3B4048)),
                      ),
                      onPressed: _replaceAll,
                      child: const Text('All', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Editor Body
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: atomOneDarkTheme),
            child: SingleChildScrollView(
              child: CodeField(
                controller: widget.controller,
                textStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize,
                  height: 1.45,
                ),
                gutterStyle: const GutterStyle(
                  showLineNumbers: true,
                  width: 48,
                  textStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF5C6370),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Code Access Bar (Keyboard Symbol Strip)
        Container(
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFF1E2227),
            border: Border(top: BorderSide(color: Color(0xFF282C34))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.search,
                  size: 16,
                  color: _showFindBar ? const Color(0xFF61AFEF) : const Color(0xFF5C6370),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36),
                onPressed: () => setState(() => _showFindBar = !_showFindBar),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 14, color: Color(0xFF5C6370)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26),
                onPressed: () {
                  if (_fontSize > 9) setState(() => _fontSize -= 0.5);
                },
              ),
              Text(
                '${_fontSize.toInt()}pt',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF5C6370)),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF5C6370)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26),
                onPressed: () {
                  if (_fontSize < 24) setState(() => _fontSize += 0.5);
                },
              ),
              Container(width: 1, height: 18, color: const Color(0xFF282C34), margin: const EdgeInsets.symmetric(horizontal: 4)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: symbols.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final item = symbols[index];
                    return InkWell(
                      onTap: () => item == 'Tab' ? _insertText('  ') : _insertText(item),
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF282C34),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF353B45)),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFFABB2BF),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
