import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/file_node.dart';

enum CommandType { file, action }

class CommandItem {
  final String label;
  final String? subtitle;
  final IconData icon;
  final CommandType type;
  final VoidCallback onSelect;

  CommandItem({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.type,
    required this.onSelect,
  });
}

class IdeCommandPalette extends StatefulWidget {
  final List<FileNode> files;
  final VoidCallback onSave;
  final VoidCallback onFormat;
  final VoidCallback onBuild;
  final VoidCallback onNewFile;
  final Function(File) onOpenFile;

  const IdeCommandPalette({
    super.key,
    required this.files,
    required this.onSave,
    required this.onFormat,
    required this.onBuild,
    required this.onNewFile,
    required this.onOpenFile,
  });

  static Future<void> show(BuildContext context, IdeCommandPalette palette) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => palette,
    );
  }

  @override
  State<IdeCommandPalette> createState() => _IdeCommandPaletteState();
}

class _IdeCommandPaletteState extends State<IdeCommandPalette> {
  final TextEditingController _queryController = TextEditingController();
  List<CommandItem> _allItems = [];
  List<CommandItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _buildItems();
    _filteredItems = List.from(_allItems);
  }

  void _buildItems() {
    _allItems = [
      CommandItem(
        label: 'Save Current File',
        subtitle: 'Write active buffer to disk',
        icon: Icons.save_outlined,
        type: CommandType.action,
        onSelect: widget.onSave,
      ),
      CommandItem(
        label: 'Format Dart Code',
        subtitle: 'Auto-indent bracket structure',
        icon: Icons.auto_fix_high_outlined,
        type: CommandType.action,
        onSelect: widget.onFormat,
      ),
      CommandItem(
        label: 'Remote Build & Install APK',
        subtitle: 'Sync source and dispatch GitHub Actions workflow',
        icon: Icons.cloud_sync_outlined,
        type: CommandType.action,
        onSelect: widget.onBuild,
      ),
      CommandItem(
        label: 'New Dart File',
        subtitle: 'Create file in workspace',
        icon: Icons.note_add_outlined,
        type: CommandType.action,
        onSelect: widget.onNewFile,
      ),
    ];

    _collectFiles(widget.files);
  }

  void _collectFiles(List<FileNode> nodes) {
    for (final node in nodes) {
      if (!node.isDirectory) {
        final file = node.entity as File;
        _allItems.add(
          CommandItem(
            label: node.name,
            subtitle: file.path,
            icon: Icons.description_outlined,
            type: CommandType.file,
            onSelect: () => widget.onOpenFile(file),
          ),
        );
      } else {
        _collectFiles(node.children);
      }
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(_allItems);
      } else {
        _filteredItems = _allItems.where((item) {
          return item.label.toLowerCase().contains(q) ||
              (item.subtitle?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF21252B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      alignment: Alignment.topCenter,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF3B4048)),
      ),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF61AFEF)),
                  hintText: 'Type command or filename...',
                  hintStyle: const TextStyle(color: Color(0xFF5C6370), fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF1E2227),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _filter,
              ),
            ),
            const Divider(height: 1, color: Color(0xFF282C34)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      item.icon,
                      size: 16,
                      color: item.type == CommandType.action ? const Color(0xFFE5C07B) : const Color(0xFF61AFEF),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: Color(0xFFABB2BF)),
                    ),
                    subtitle: item.subtitle != null
                        ? Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF5C6370)),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      item.onSelect();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
