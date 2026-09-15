import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';
import 'data/models/file_node.dart';
import 'data/repositories/workspace_repository.dart';
import 'data/repositories/github_build_service.dart';
import 'presentation/widgets/code_editor_view.dart';
import 'presentation/widgets/live_preview_view.dart';

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

  final List<String> _consoleLogs = ['DashIDE workspace initialized.'];
  bool _showConsole = false;
  bool _isPreviewMode = false;

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

  void _log(String message) {
    setState(() {
      _consoleLogs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
    });
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
    _log('Opened: ${file.path.split("/").last}');
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
      _log('Saved: ${_activeFile!.path.split("/").last}');
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

  Future<void> _showBuildAndInstallDialog() async {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_outlined, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('Sync & Build APK'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Commits local files to GitHub\n2. Dispatches CI build\n3. Downloads & installs APK automatically.',
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

              setState(() => _showConsole = true);

              try {
                if (_activeFile != null) await _saveCurrentFile();

                final root = await _repo.workspaceDir;
                final projectDir = Directory('${root.path}/demo_app');

                _log('Starting source sync to GitHub...');
                await service.syncWorkspaceFiles(
                  localDir: projectDir,
                  onProgress: (msg) => _log(msg),
                );
                _log('Source sync complete!');

                _log('Dispatching GitHub Actions compilation workflow...');
                final triggered = await service.triggerWorkflow();
                if (!triggered) {
                  _log('Error: Trigger failed. Check token permissions.');
                  return;
                }

                _log('Workflow triggered. Polling status...');
                _pollWorkflowAndInstall(service);
              } catch (e) {
                _log('Error during sync/build: $e');
              }
            },
            child: const Text('Start Pipeline'),
          ),
        ],
      ),
    );
  }

  void _pollWorkflowAndInstall(GitHubBuildService service) {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempts++;
      final run = await service.getLatestRun();
      if (run != null) {
        final status = run['status'];
        final conclusion = run['conclusion'];
        _log('Build state: $status (conclusion: $conclusion)');

        if (status == 'completed') {
          timer.cancel();
          if (conclusion == 'success') {
            final runId = run['id'] as int;
            _log('Fetching build artifacts...');
            final artifacts = await service.getRunArtifacts(runId);

            if (artifacts.isNotEmpty) {
              final apkArtifact = artifacts.first;
              final archiveUrl = apkArtifact['archive_download_url'] as String;
              _log('Found artifact: ${apkArtifact["name"]}. Starting download...');
              await service.downloadAndInstallArtifact(
                artifactDownloadUrl: archiveUrl,
                onStatus: (msg) => _log(msg),
              );
            } else {
              _log('Error: No artifacts published in run.');
            }
          } else {
            _log('Cloud build completed with failure.');
          }
        }
      }

      if (attempts >= 45) {
        timer.cancel();
        _log('Polling timed out after 4.5 minutes.');
      }
    });
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
            icon: Icon(
              _isPreviewMode ? Icons.code : Icons.visibility_outlined,
              color: _isPreviewMode ? Colors.amberAccent : Colors.cyanAccent,
            ),
            tooltip: _isPreviewMode ? 'Editor' : 'Live Preview',
            onPressed: () {
              if (_activeFile != null) _saveCurrentFile();
              setState(() => _isPreviewMode = !_isPreviewMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, color: Colors.greenAccent),
            tooltip: 'Sync & Build APK',
            onPressed: _showBuildAndInstallDialog,
          ),
          IconButton(
            icon: Icon(
              _showConsole ? Icons.terminal : Icons.terminal_outlined,
              color: _showConsole ? Colors.cyanAccent : Colors.white,
            ),
            tooltip: 'Console',
            onPressed: () => setState(() => _showConsole = !_showConsole),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _activeFile == null ? null : _saveCurrentFile,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF21252B),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 48, bottom: 12, left: 16, right: 16),
              child: const Row(
                children: [
                  Icon(Icons.folder_copy_outlined, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text('Explorer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          if (_openTabs.isNotEmpty && !_isPreviewMode)
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
          Expanded(
            child: _isPreviewMode
                ? LivePreviewView(dartCode: _editorController.text)
                : (_activeFile == null
                    ? const Center(child: Text('Open a file to start editing'))
                    : CodeEditorView(controller: _editorController)),
          ),
          if (_showConsole)
            Container(
              height: 150,
              color: const Color(0xFF181A1F),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF21252B),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OUTPUT CONSOLE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 16),
                          onPressed: () => setState(() => _consoleLogs.clear()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _consoleLogs.length,
                      itemBuilder: (context, idx) => Text(
                        _consoleLogs[idx],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF98C379),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
      );
    }).toList();
  }
}
