import "dart:convert";
import "dart:typed_data";
import "package:dartssh2/dartssh2.dart";
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/file_node.dart';

class IdeExplorerPanel extends StatelessWidget {
  final List<FileNode> files;
  final File? activeFile;
  final Set<String> unpushedFiles;
  final Function(File) onFileSelected;
  final Function(FileSystemEntity, bool) onDeleteEntity;
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;

  const IdeExplorerPanel({
    super.key,
    required this.files,
    required this.activeFile,
    required this.unpushedFiles,
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
      final isModified = unpushedFiles.contains(node.entity.path);
      
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 20, right: 4),
        tileColor: isSelected ? const Color(0xFF2C313A) : null,
        leading: const Icon(Icons.description_outlined, size: 15, color: Color(0xFF61AFEF)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isModified ? const Color(0xFFE5C07B) : (isSelected ? Colors.white : const Color(0xFFABB2BF)),
                ),
              ),
            ),
            if (isModified)
              const Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE5C07B))),
          ],
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
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF282C34)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXPLORER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF)),
              ),
              Row(
                children: [
                  InkWell(onTap: onNewFile, child: const Icon(Icons.note_add_outlined, size: 16, color: Color(0xFFABB2BF))),
                  const SizedBox(width: 8),
                  InkWell(onTap: onNewFolder, child: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFFABB2BF))),
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

class IdeGitPanel extends StatefulWidget {
  final String activeRepo;
  final bool isBusy;
  final Set<String> unpushedFiles;
  final Function(String message) onCommitAndPush;
  final VoidCallback onChangeRepo;

  const IdeGitPanel({
    super.key,
    required this.activeRepo,
    required this.isBusy,
    required this.unpushedFiles,
    required this.onCommitAndPush,
    required this.onChangeRepo,
  });

  @override
  State<IdeGitPanel> createState() => _IdeGitPanelState();
}

class _IdeGitPanelState extends State<IdeGitPanel> {
  final TextEditingController _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF282C34)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SOURCE CONTROL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF)),
              ),
              InkWell(onTap: widget.onChangeRepo, child: const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF61AFEF))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 13, color: Color(0xFFE5C07B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.activeRepo,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFABB2BF)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgController,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Commit message...',
                  hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF1E2227),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF61AFEF),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: widget.isBusy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.black),
                  label: Text(
                    widget.isBusy ? 'Pushing...' : 'Commit & Push',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: widget.isBusy
                      ? null
                      : () {
                          final msg = _msgController.text.trim();
                          widget.onCommitAndPush(msg.isEmpty ? 'Update from DashIDE' : msg);
                          _msgController.clear();
                        },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF282C34)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('CHANGES (${widget.unpushedFiles.length})', style: const TextStyle(fontSize: 10, color: Color(0xFFABB2BF))),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.unpushedFiles.length,
            itemBuilder: (context, index) {
              final path = widget.unpushedFiles.elementAt(index);
              final name = path.split('/').last;
              return ListTile(
                dense: true,
                leading: const Text('M', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE5C07B), fontWeight: FontWeight.bold)),
                title: Text(name, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFE5C07B))),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Search and Console panels remain exactly the same below...
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

  void _performSearch(String query) {
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
              if (lines[i].contains(q)) results.add(SearchResult(file: file, lineNumber: i + 1, lineText: lines[i].trim()));
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
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF282C34)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WORKSPACE SEARCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF))),
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: TextField(
                  controller: _queryController,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search text...',
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
        if (_searching) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF61AFEF)),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              return ListTile(
                dense: true,
                title: Text('${item.file.path.split("/").last}:${item.lineNumber}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF61AFEF))),
                subtitle: Text(item.lineText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFFABB2BF))),
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
  const IdeConsolePanel({super.key, required this.logs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF282C34)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('OUTPUT LOGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF))),
              InkWell(onTap: onClear, child: const Icon(Icons.clear_all, size: 16, color: Color(0xFF5C6370))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, idx) => Text(logs[idx], style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, height: 1.3, color: Color(0xFF98C379))),
          ),
        ),
      ],
    );
  }
}

class IdeSshPanel extends StatefulWidget {
  const IdeSshPanel({super.key});

  @override
  State<IdeSshPanel> createState() => _IdeSshPanelState();
}

class _IdeSshPanelState extends State<IdeSshPanel> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'root');
  final _passCtrl = TextEditingController();
  final _cmdCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SSHClient? _client;
  SSHSession? _session;
  bool _isConnecting = false;
  final List<String> _output = [];

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _output.clear();
    });
    try {
      final socket = await SSHSocket.connect(_hostCtrl.text.trim(), 22, timeout: const Duration(seconds: 5));
      _client = SSHClient(
        socket,
        username: _userCtrl.text.trim(),
        onPasswordRequest: () => _passCtrl.text,
      );
      _session = await _client!.shell();
      setState(() {
        _isConnecting = false;
        _output.add('Connected to ${_hostCtrl.text}\n');
      });

      _session!.stdout.listen((data) => _appendOutput(utf8.decode(data)));
      _session!.stderr.listen((data) => _appendOutput(utf8.decode(data)));
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _output.add('Connection failed: $e');
      });
    }
  }

  void _appendOutput(String text) {
    if (!mounted) return;
    setState(() => _output.add(text));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendCommand() {
    if (_session == null || _cmdCtrl.text.isEmpty) return;
    final cmd = _cmdCtrl.text;
    _cmdCtrl.clear();
    _session!.write(Uint8List.fromList(utf8.encode('$cmd\n')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF282C34)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SSH TERMINAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFFABB2BF))),
              if (_client != null)
                InkWell(
                  onTap: () {
                    _client?.close();
                    setState(() { _client = null; _session = null; });
                  },
                  child: const Icon(Icons.power_settings_new, size: 14, color: Color(0xFFE06C75)),
                ),
            ],
          ),
        ),
        if (_client == null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Host / IP', style: TextStyle(fontSize: 11, color: Color(0xFFABB2BF))),
                  const SizedBox(height: 4),
                  TextField(controller: _hostCtrl, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  const Text('Username', style: TextStyle(fontSize: 11, color: Color(0xFFABB2BF))),
                  const SizedBox(height: 4),
                  TextField(controller: _userCtrl, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  const Text('Password', style: TextStyle(fontSize: 11, color: Color(0xFFABB2BF))),
                  const SizedBox(height: 4),
                  TextField(controller: _passCtrl, obscureText: true, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF61AFEF)),
                      onPressed: _isConnecting ? null : _connect,
                      child: Text(_isConnecting ? 'Connecting...' : 'Connect', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _output.length,
              itemBuilder: (context, idx) => Text(_output[idx], style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFABB2BF))),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1E2227),
            child: Row(
              children: [
                const Text('\$ ', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF98C379), fontWeight: FontWeight.bold)),
                Expanded(
                  child: TextField(
                    controller: _cmdCtrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Enter command...'),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
