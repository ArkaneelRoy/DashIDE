import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/file_node.dart';

class IdeExplorerPanel extends StatelessWidget {
  final List<FileNode> files;
  final File? activeFile;
  final Function(File) onFileSelected;
  final Function(FileSystemEntity, bool) onDeleteEntity;
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;

  const IdeExplorerPanel({
    super.key,
    required this.files,
    required this.activeFile,
    required this.onFileSelected,
    required this.onDeleteEntity,
    required this.onNewFile,
    required this.onNewFolder,
  });

  List<Widget> _buildTree(BuildContext context, List<FileNode> nodes) {
    return nodes.map((node) {
      if (node.isDirectory) {
        return ExpansionTile(
          initiallyExpanded: true,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.folder_outlined, size: 16, color: Color(0xFFE5C07B)),
          title: Text(node.name, style: const TextStyle(fontSize: 12, color: Color(0xFFABB2BF))),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE06C75)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => onDeleteEntity(node.entity, true),
          ),
          children: _buildTree(context, node.children),
        );
      }
      final isSelected = activeFile?.path == node.entity.path;
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 20, right: 4),
        tileColor: isSelected ? const Color(0xFF2C313A) : null,
        leading: const Icon(Icons.description_outlined, size: 15, color: Color(0xFF61AFEF)),
        title: Text(
          node.name,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: isSelected ? Colors.white : const Color(0xFFABB2BF),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE06C75)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => onDeleteEntity(node.entity, false),
        ),
        onTap: () => onFileSelected(node.entity as File),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF282C34))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXPLORER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFFABB2BF),
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: onNewFile,
                    child: const Icon(Icons.note_add_outlined, size: 16, color: Color(0xFFABB2BF)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onNewFolder,
                    child: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFFABB2BF)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _buildTree(context, files),
          ),
        ),
      ],
    );
  }
}

class SearchResult {
  final File file;
  final int lineNumber;
  final String lineText;

  SearchResult({required this.file, required this.lineNumber, required this.lineText});
}

class IdeSearchPanel extends StatefulWidget {
  final List<FileNode> files;
  final Function(File) onOpenFile;

  const IdeSearchPanel({super.key, required this.files, required this.onOpenFile});

  @override
  State<IdeSearchPanel> createState() => _IdeSearchPanelState();
}

class _IdeSearchPanelState extends State<IdeSearchPanel> {
  final TextEditingController _queryController = TextEditingController();
  List<SearchResult> _results = [];
  bool _searching = false;

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _searching = true);
    final results = <SearchResult>[];

    void searchNodes(List<FileNode> nodes) {
      for (final node in nodes) {
        if (!node.isDirectory) {
          final file = node.entity as File;
          try {
            final lines = file.readAsLinesSync();
            for (int i = 0; i < lines.length; i++) {
              if (lines[i].contains(q)) {
                results.add(SearchResult(file: file, lineNumber: i + 1, lineText: lines[i].trim()));
              }
            }
          } catch (_) {}
        } else {
          searchNodes(node.children);
        }
      }
    }

    searchNodes(widget.files);
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF282C34))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WORKSPACE SEARCH',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search text in project...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    filled: true,
                    fillColor: const Color(0xFF1E2227),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
            ],
          ),
        ),
        if (_searching)
          const LinearProgressIndicator(minHeight: 2, color: Color(0xFF61AFEF)),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              return ListTile(
                dense: true,
                title: Text(
                  '${item.file.path.split("/").last}:${item.lineNumber}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF61AFEF)),
                ),
                subtitle: Text(
                  item.lineText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFFABB2BF)),
                ),
                onTap: () => widget.onOpenFile(item.file),
              );
            },
          ),
        ),
      ],
    );
  }
}

class IdeConsolePanel extends StatelessWidget {
  final List<String> logs;
  final VoidCallback onClear;

  const IdeConsolePanel({
    super.key,
    required this.logs,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF282C34))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OUTPUT LOGS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF)),
              ),
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.clear_all, size: 16, color: Color(0xFF5C6370)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, idx) => Text(
              logs[idx],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                height: 1.3,
                color: Color(0xFF98C379),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
