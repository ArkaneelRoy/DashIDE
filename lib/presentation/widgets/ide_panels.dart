import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/file_node.dart';

class IdeExplorerPanel extends StatelessWidget {
  final List<FileNode> files;
  final File? activeFile;
  final Function(File) onFileSelected;
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;

  const IdeExplorerPanel({
    super.key,
    required this.files,
    required this.activeFile,
    required this.onFileSelected,
    required this.onNewFile,
    required this.onNewFolder,
  });

  List<Widget> _buildTree(BuildContext context, List<FileNode> nodes) {
    return nodes.map((node) {
      if (node.isDirectory) {
        return ExpansionTile(initiallyExpanded: true,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.folder_outlined, size: 16, color: Color(0xFFE5C07B)),
          title: Text(node.name, style: const TextStyle(fontSize: 12, color: Color(0xFFABB2BF))),
          children: _buildTree(context, node.children),
        );
      }
      final isSelected = activeFile?.path == node.entity.path;
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 20, right: 8),
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
