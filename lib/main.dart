import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';
import 'data/models/file_node.dart';
import 'data/repositories/workspace_repository.dart';
import 'data/repositories/github_build_service.dart';
import 'presentation/widgets/code_editor_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashIDEApp());
}

class DashIDEApp extends StatelessWidget {
  const DashIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashIDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF21252B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2227),
          elevation: 0,
        ),
      ),
      home: const WorkspacePage(),
    );
  }
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final WorkspaceRepository _repo = WorkspaceRepository();
  late final CodeController _editorController;

  List<FileNode> _files = [];
  final List<File> _openTabs = [];
  File? _activeFile;

  @override
  void initState() {
    super.initState();
    _editorController = CodeController(
      text: '',
      language: dart,
    );
    _initWorkspace();
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _initWorkspace() async {
    await _repo.initDefaultProject();
    await _refreshFileTree();

    final mainDart = _findMainDart(_files);
    if (mainDart != null && _activeFile == null) {
      await _openFile(mainDart);
    }
  }

  Future<void> _refreshFileTree() async {
    final tree = await _repo.loadFileTree();
    setState(() {
      _files = tree;
    });
  }

  File? _findMainDart(List<FileNode> nodes) {
    for (final node in nodes) {
      if (!node.isDirectory && node.name == 'main.dart') {
        return node.entity as File;
      }
      final nested = _findMainDart(node.children);
      if (nested != null) return nested;
    }
    return null;
  }

  Future<void> _openFile(File file) async {
    if (_activeFile != null && _activeFile!.path == file.path) return;

    if (_activeFile != null) {
      await _activeFile!.writeAsString(_editorController.text);
    }

    if (!_openTabs.any((f) => f.path == file.path)) {
      _openTabs.add(file);
    }

    final content = await file.readAsString();
    setState(() {
      _activeFile = file;
      _editorController.text = content;
    });
  }

  Future<void> _closeTab(File file) async {
    final index = _openTabs.indexWhere((f) => f.path == file.path);
    if (index == -1) return;

    if (_activeFile?.path == file.path) {
      await file.writeAsString(_editorController.text);
    }

    setState(() {
      _openTabs.removeAt(index);
      if (_activeFile?.path == file.path) {
        if (_openTabs.isNotEmpty) {
          final nextIndex = index >= _openTabs.length ? _openTabs.length - 1 : index;
          _openFile(_openTabs[nextIndex]);
        } else {
          _activeFile = null;
          _editorController.text = '';
        }
      }
    });
  }

  Future<void> _saveCurrentFile() async {
    if (_activeFile != null) {
      await _activeFile!.writeAsString(_editorController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${_activeFile!.path.split("/").last}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _createNewFilePrompt() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New File'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'widget_view.dart'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final root = await _repo.workspaceDir;
      final newFile = File('${root.path}/demo_app/lib/$name');
      await newFile.create(recursive: true);
      await _refreshFileTree();
      await _openFile(newFile);
    }
  }

  Future<void> _showFileActionDialog(File file) async {
    final fileName = file.path.split('/').last;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF282C34),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'delete') {
      await _closeTab(file);
      await file.delete();
      await _refreshFileTree();
    } else if (action == 'rename') {
      final textController = TextEditingController(text: fileName);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename File'),
          content: TextField(controller: textController, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, textController.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        ),
      );

      if (newName != null && newName.isNotEmpty && newName != fileName) {
        final newPath = file.parent.path + '/' + newName;
        await file.rename(newPath);
        await _refreshFileTree();
        if (_activeFile?.path == file.path) {
          await _openFile(File(newPath));
        }
      }
    }
  }

  Future<void> _showBuildDialog() async {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Cloud APK Build'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Triggers GitHub Actions to compile this project into an ARM64 APK artifact.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'GitHub PAT Token',
                hintText: 'ghp_...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final token = tokenController.text.trim();
              if (token.isEmpty) return;
              Navigator.pop(ctx);

              final service = GitHubBuildService(
                owner: 'ArkaneelRoy',
                repo: 'DashIDE',
                token: token,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dispatching GitHub Actions build...')),
              );

              final success = await service.triggerWorkflow();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Build triggered! Check GitHub Actions tab.'
                          : 'Build trigger failed. Check token permissions.',
                    ),
                    backgroundColor: success ? Colors.green[800] : Colors.red[800],
                  ),
                );
              }
            },
            child: const Text('Trigger Build'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DashIDE',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
            tooltip: 'Cloud Build APK',
            onPressed: _showBuildDialog,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'New File',
            onPressed: _createNewFilePrompt,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Current File',
            onPressed: _activeFile == null ? null : _saveCurrentFile,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF21252B),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.terminal, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text(
                    'DashIDE Explorer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF3B4048), height: 1),
            Expanded(
              child: ListView(
                children: _buildFileTreeTiles(_files),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Open tabs bar
          if (_openTabs.isNotEmpty)
            Container(
              height: 38,
              color: const Color(0xFF1E2227),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _openTabs.length,
                itemBuilder: (context, index) {
                  final file = _openTabs[index];
                  final isSelected = _activeFile?.path == file.path;
                  return InkWell(
                    onTap: () => _openFile(file),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF282C34) : const Color(0xFF1E2227),
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.cyanAccent : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            file.path.split('/').last,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _closeTab(file),
                            child: const Icon(Icons.close, size: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Code editor view
          Expanded(
            child: _activeFile == null
                ? const Center(child: Text('Select or open a file to start editing'))
                : CodeEditorView(controller: _editorController),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFileTreeTiles(List<FileNode> nodes) {
    return nodes.map((node) {
      if (node.isDirectory) {
        return ExpansionTile(
          leading: const Icon(Icons.folder_outlined, color: Colors.amberAccent),
          title: Text(node.name, style: const TextStyle(fontSize: 14)),
          children: _buildFileTreeTiles(node.children),
        );
      }
      return ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.lightBlueAccent, size: 20),
        title: Text(node.name, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        onTap: () {
          Navigator.pop(context);
          _openFile(node.entity as File);
        },
        onLongPress: () => _showFileActionDialog(node.entity as File),
      );
    }).toList();
  }
}
