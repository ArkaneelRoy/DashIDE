import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/editor_utils.dart';
import 'data/models/file_node.dart';
import 'data/repositories/workspace_repository.dart';
import 'data/repositories/github_build_service.dart';
import 'presentation/widgets/code_editor_view.dart';
import 'presentation/widgets/live_preview_view.dart';
import 'presentation/widgets/ide_app_bar.dart';
import 'presentation/widgets/ide_activity_rail.dart';
import 'presentation/widgets/ide_status_bar.dart';
import 'presentation/widgets/ide_tab_bar.dart';
import 'presentation/widgets/ide_panels.dart';
import 'presentation/widgets/ide_command_palette.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF61AFEF),
          surface: Color(0xFF21252B),
        ),
        dividerColor: const Color(0xFF282C34),
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
  String _savedFileSnapshot = '';
  bool _isDirty = false;

  // 0: None, 1: Explorer, 2: Search, 3: Console
  int _activePanel = 0;
  bool _isPreviewMode = false;
  String _savedPatToken = '';
  final List<String> _consoleLogs = ['DashIDE ready.'];

  int _cursorLine = 1;
  int _cursorCol = 1;
  String _buildStatus = 'Idle';

  @override
  void initState() {
    super.initState();
    _editorController = CodeController(text: '', language: dart);
    _editorController.addListener(_checkDirtyState);
    _initWorkspace();
    _loadPreferences();
  }

  @override
  void dispose() {
    _editorController.removeListener(_checkDirtyState);
    _editorController.dispose();
    super.dispose();
  }

  void _checkDirtyState() {
    final dirty = _editorController.text != _savedFileSnapshot;
    if (dirty != _isDirty) {
      setState(() => _isDirty = dirty);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _savedPatToken = prefs.getString('github_pat_token') ?? '');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_pat_token', token);
    setState(() => _savedPatToken = token);
  }

  void _log(String msg) {
    setState(() => _consoleLogs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg'));
  }

  void _updateCursor() {
    final sel = _editorController.selection;
    if (sel.baseOffset < 0) return;
    final textBefore = _editorController.text.substring(0, sel.baseOffset);
    final lines = textBefore.split('\n');
    setState(() {
      _cursorLine = lines.length;
      _cursorCol = lines.last.length + 1;
    });
  }

  Future<void> _initWorkspace() async {
    await _repo.initDefaultProject();
    final tree = await _repo.loadFileTree();
    setState(() => _files = tree);
    final mainDart = _findMainDart(tree);
    if (mainDart != null && _activeFile == null) await _openFile(mainDart);
  }

  File? _findMainDart(List<FileNode> nodes) {
    for (final node in nodes) {
      if (!node.isDirectory && node.name == 'main.dart') return node.entity as File;
      final nested = _findMainDart(node.children);
      if (nested != null) return nested;
    }
    return null;
  }

  Future<void> _openFile(File file) async {
    if (_activeFile?.path == file.path) return;
    if (_activeFile != null && _isDirty) await _saveCurrentFile();
    if (!_openTabs.any((f) => f.path == file.path)) _openTabs.add(file);

    final content = await file.readAsString();
    _savedFileSnapshot = content;
    setState(() {
      _activeFile = file;
      _editorController.text = content;
      _isDirty = false;
    });
    _updateCursor();
    _log('Opened: ${file.path.split("/").last}');
  }

  Future<void> _closeTab(File file) async {
    final index = _openTabs.indexWhere((f) => f.path == file.path);
    if (index == -1) return;
    if (_activeFile?.path == file.path && _isDirty) await file.writeAsString(_editorController.text);

    setState(() {
      _openTabs.removeAt(index);
      if (_activeFile?.path == file.path) {
        if (_openTabs.isNotEmpty) {
          final nextIndex = index >= _openTabs.length ? _openTabs.length - 1 : index;
          _openFile(_openTabs[nextIndex]);
        } else {
          _activeFile = null;
          _editorController.text = '';
          _savedFileSnapshot = '';
          _isDirty = false;
        }
      }
    });
  }

  Future<void> _saveCurrentFile() async {
    if (_activeFile == null) return;
    await _activeFile!.writeAsString(_editorController.text);
    _savedFileSnapshot = _editorController.text;
    setState(() => _isDirty = false);
    _log('Saved: ${_activeFile!.path.split("/").last}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF282C34),
          content: Text('Saved ${_activeFile!.path.split("/").last}', style: const TextStyle(color: Color(0xFF98C379))),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _formatCurrentCode() {
    if (_activeFile == null) return;
    final formatted = EditorUtils.formatDartCode(_editorController.text);
    _editorController.value = TextEditingValue(
      text: formatted,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _log('Formatted active buffer');
  }

  Future<void> _createNewEntityPrompt({required bool isDirectory}) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: Text(isDirectory ? 'New Directory' : 'New Dart File', style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: textController,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: isDirectory ? 'screens' : 'button.dart',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF61AFEF)),
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Create', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final root = await _repo.workspaceDir;
      final targetPath = '${root.path}/demo_app/lib/$name';
      if (isDirectory) {
        await Directory(targetPath).create(recursive: true);
        _log('Created folder: $name');
      } else {
        final file = File(targetPath);
        await file.create(recursive: true);
        _log('Created file: $name');
        await _openFile(file);
      }
      final tree = await _repo.loadFileTree();
      setState(() => _files = tree);
    }
  }

  Future<void> _showBuildAndInstallDialog() async {
    final tokenController = TextEditingController(text: _savedPatToken);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_outlined, color: Color(0xFF61AFEF), size: 20),
            SizedBox(width: 8),
            Text('Remote Build & Install', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Syncs code to GitHub, compiles ARM64 APK, and launches the installer.',
              style: TextStyle(fontSize: 12, color: Color(0xFFABB2BF)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'GitHub PAT Token', border: OutlineInputBorder(), isDense: true),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF98C379)),
            onPressed: () async {
              final token = tokenController.text.trim();
              if (token.isEmpty) return;
              await _saveToken(token);
              Navigator.pop(ctx);

              final service = GitHubBuildService(owner: 'ArkaneelRoy', repo: 'DashIDE', token: token);
              setState(() {
                _activePanel = 3;
                _buildStatus = 'Syncing...';
              });

              try {
                if (_activeFile != null) await _saveCurrentFile();
                final root = await _repo.workspaceDir;
                await service.syncWorkspaceFiles(
                  localDir: Directory('${root.path}/demo_app'),
                  onProgress: (msg) => _log(msg),
                );

                setState(() => _buildStatus = 'Dispatching...');
                final ok = await service.triggerWorkflow();
                if (!ok) {
                  setState(() => _buildStatus = 'Error');
                  return;
                }

                setState(() => _buildStatus = 'Compiling...');
                _pollWorkflow(service);
              } catch (e) {
                setState(() => _buildStatus = 'Failed');
                _log('Error: $e');
              }
            },
            child: const Text('Build APK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _pollWorkflow(GitHubBuildService service) {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 6), (timer) async {
      attempts++;
      final run = await service.getLatestRun();
      if (run != null) {
        final status = run['status'];
        final conclusion = run['conclusion'];
        _log('CI: $status (${conclusion ?? "running"})');

        if (status == 'completed') {
          timer.cancel();
          if (conclusion == 'success') {
            setState(() => _buildStatus = 'Downloading...');
            final runId = run['id'] as int;
            final artifacts = await service.getRunArtifacts(runId);
            if (artifacts.isNotEmpty) {
              await service.downloadAndInstallArtifact(
                artifactDownloadUrl: artifacts.first['archive_download_url'] as String,
                onStatus: (msg) => _log(msg),
              );
              setState(() => _buildStatus = 'Ready');
            } else {
              setState(() => _buildStatus = 'No Artifact');
            }
          } else {
            setState(() => _buildStatus = 'Failed');
          }
        }
      }

      if (attempts >= 45) {
        timer.cancel();
        setState(() => _buildStatus = 'Timeout');
      }
    });
  }

  void _openCommandPalette() {
    IdeCommandPalette.show(
      context,
      IdeCommandPalette(
        files: _files,
        onSave: _saveCurrentFile,
        onFormat: _formatCurrentCode,
        onBuild: _showBuildAndInstallDialog,
        onNewFile: () => _createNewEntityPrompt(isDirectory: false),
        onOpenFile: _openFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            IdeAppBar(
              isPreviewMode: _isPreviewMode,
              hasActiveFile: _activeFile != null,
              onTogglePreview: () {
                if (_activeFile != null) _saveCurrentFile();
                setState(() => _isPreviewMode = !_isPreviewMode);
              },
              onBuildAndInstall: _showBuildAndInstallDialog,
              onSave: _saveCurrentFile,
            ),
            Expanded(
              child: Row(
                children: [
                  IdeActivityRail(
                    activePanel: _activePanel,
                    onPanelSelected: (panel) => setState(() => _activePanel = panel),
                    onOpenPalette: _openCommandPalette,
                  ),
                  if (_activePanel != 0)
                    Container(
                      width: isCompact ? 220 : 260,
                      decoration: const BoxDecoration(
                        color: Color(0xFF21252B),
                        border: Border(right: BorderSide(color: Color(0xFF282C34))),
                      ),
                      child: _buildSelectedPanel(),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!_isPreviewMode)
                          IdeTabBar(
                            openTabs: _openTabs,
                            activeFile: _activeFile,
                            isDirty: _isDirty,
                            onSelectTab: _openFile,
                            onCloseTab: _closeTab,
                          ),
                        Expanded(
                          child: _isPreviewMode
                              ? LivePreviewView(dartCode: _editorController.text)
                              : (_activeFile == null
                                  ? const Center(
                                      child: Text(
                                        'DashIDE Workspace',
                                        style: TextStyle(fontFamily: 'monospace', color: Color(0xFF5C6370)),
                                      ),
                                    )
                                  : CodeEditorView(
                                      controller: _editorController,
                                      onCursorMoved: _updateCursor,
                                    )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IdeStatusBar(
              buildStatus: _buildStatus,
              line: _cursorLine,
              col: _cursorCol,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPanel() {
    switch (_activePanel) {
      case 1:
        return IdeExplorerPanel(
          files: _files,
          activeFile: _activeFile,
          onFileSelected: _openFile,
          onNewFile: () => _createNewEntityPrompt(isDirectory: false),
          onNewFolder: () => _createNewEntityPrompt(isDirectory: true),
        );
      case 2:
        return IdeSearchPanel(
          files: _files,
          onOpenFile: _openFile,
        );
      case 3:
      default:
        return IdeConsolePanel(
          logs: _consoleLogs,
          onClear: () => setState(() => _consoleLogs.clear()),
        );
    }
  }
}
