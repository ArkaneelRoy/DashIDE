import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import '../../core/editor_utils.dart';

class CodeEditorView extends StatefulWidget {
  final CodeController controller;
  final double fontSize;
  final String themeName;
  final VoidCallback? onCursorMoved;

  const CodeEditorView({
    super.key,
    required this.controller,
    this.fontSize = 13.0,
    this.themeName = 'Atom One Dark',
    this.onCursorMoved,
  });

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends State<CodeEditorView> {
  bool _showFindBar = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  Map<String, TextStyle> get _activeTheme {
    switch (widget.themeName) {
      case 'Dracula':
        return draculaTheme;
      case 'Monokai':
        return monokaiSublimeTheme;
      case 'GitHub Light':
        return githubTheme;
      case 'Atom One Dark':
      default:
        return atomOneDarkTheme;
    }
  }

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

  void _formatCode() {
    final formatted = EditorUtils.formatDartCode(widget.controller.text);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _showSnippetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF21252B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'INSERT SNIPPET',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFABB2BF),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF282C34)),
            ...EditorUtils.snippets.entries.map(
              (entry) => ListTile(
                dense: true,
                leading: const Icon(Icons.code_outlined, color: Color(0xFF61AFEF), size: 18),
                title: Text(entry.key, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertText(entry.value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _findAndHighlight() {
    final query = _findController.text;
    if (query.isEmpty) return;

    final text = widget.controller.text;
    final currentOffset = widget.controller.selection.end;
    var nextIndex = text.indexOf(query, currentOffset >= 0 ? currentOffset : 0);

    if (nextIndex == -1) nextIndex = text.indexOf(query, 0);

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

    widget.controller.text = widget.controller.text.replaceAll(query, replacement);
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
            child: Row(
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
          ),

        // Scrollable editor area bounded strictly by Expanded
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: CodeTheme(
                    data: CodeThemeData(styles: _activeTheme),
                    child: CodeField(
                      controller: widget.controller,
                      textStyle: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: widget.fontSize,
                        height: 1.45,
                      ),
                      gutterStyle: const GutterStyle(
                        showLineNumbers: true,
                        margin: 16.0,
                        textStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF5C6370),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Accessory Bar
        Container(
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFF1E2227),
            border: Border(top: BorderSide(color: Color(0xFF282C34))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.auto_fix_high_outlined, size: 16, color: Color(0xFF61AFEF)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
                tooltip: 'Format Code',
                onPressed: _formatCode,
              ),
              IconButton(
                icon: const Icon(Icons.data_object_outlined, size: 16, color: Color(0xFFE5C07B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
                tooltip: 'Snippets',
                onPressed: _showSnippetPicker,
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  size: 16,
                  color: _showFindBar ? const Color(0xFF61AFEF) : const Color(0xFF5C6370),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
                onPressed: () => setState(() => _showFindBar = !_showFindBar),
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
