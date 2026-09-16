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
import 'presentation/dialogs/ide_dialogs.dart';
import 'presentation/controllers/pipeline_controller.dart';

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
        colorScheme: const ColorScheme.dark(primary: Color(0xFF61AFEF), surface: Color(0xFF21252B)),
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
  final Set<String> _unpushedFiles = {};

  // 0: None, 1: Explorer, 2: Git, 3: Search, 4: Console, 5: SSH
  int _activePanel = 0;
  bool _isPreviewMode = false;
  String _savedPat = '';
  String _targetRepo = ''; // Default is now empty
  bool _isGitBusy = false;

  final List<String> _consoleLogs = ['DashIDE workspace ready.'];

  int _cursorLine = 1;
  int _cursorCol = 1;
  String _buildStatus = 'Idle';
  double _fontSize = 13.0;
  String _theme = 'Atom One Dark';

  @override
  void initState() {
    super.initState();
    _editorController = CodeController(text: '', language: dart);
    _editorController.addListener(_handleEditorChange);
    _bootstrap();
  }

  @override
  void dispose() {
    _editorController.removeListener(_handleEditorChange);
    _editorController.dispose();
    super.dispose();
  }

  void _handleEditorChange() {
    final dirty = _editorController.text != _savedFileSnapshot;
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
    final sel = _editorController.selection;
    if (sel.baseOffset >= 0) {
      final textBefore = _editorController.text.substring(0, sel.baseOffset);
      final lines = textBefore.split('\n');
      setState(() {
        _cursorLine = lines.length;
        _cursorCol = lines.last.length + 1;
      });
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPat = prefs.getString('github_pat_token') ?? '';
      _targetRepo = prefs.getString('target_repo') ?? '';
      _fontSize = prefs.getDouble('editor_font_size') ?? 13.0;
      _theme = prefs.getString('editor_theme') ?? 'Atom One Dark';
    });

    await _repo.initDefaultProject();
    final tree = await _repo.loadFileTree();
    setState(() => _files = tree);
    final mainDart = _findFile(tree, 'main.dart');
    if (mainDart != null && _activeFile == null) await _openFile(mainDart);
  }

  File? _findFile(List<FileNode> nodes, String name) {
    for (final n in nodes) {
      if (!n.isDirectory && n.name == name) return n.entity as File;
      final match = _findFile(n.children, name);
      if (match != null) return match;
    }
    return null;
  }

  void _log(String msg) {
    setState(() => _consoleLogs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg'));
  }

  GitHubBuildService _createService(String token) {
    final parts = _targetRepo.split('/');
    final owner = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'owner';
    final repo = parts.length > 1 ? parts[1] : 'repo';
    return GitHubBuildService(owner: owner, repo: repo, token: token);
  }

  Future<void> _commitAndPush(String message) async {
    if (_targetRepo.isEmpty || !_targetRepo.contains('/')) {
      _log('Error: Target repository not set. Tap the ⇄ icon in the Source Control panel.');
      return;
    }
    if (_savedPat.isEmpty) {
      _log('Error: Personal Access Token required. Open settings or build dialog.');
      return;
    }

    setState(() => _isGitBusy = true);
    try {
      if (_activeFile != null) await _saveFile();
      final root = await _repo.workspaceDir;
      final projectDir = Directory('${root.path}/demo_app');
      final service = _createService(_savedPat);

      _log('Starting Git commit & push: "$message"...');
      await service.syncWorkspaceFiles(
        localDir: projectDir,
        onProgress: _log,
      );
      
      setState(() => _unpushedFiles.clear());
      _log('Commit & push completed.');
    } catch (e) {
      _log('Git push failed: $e');
    } finally {
      setState(() => _isGitBusy = false);
    }
  }

  Future<void> _switchTargetRepo() async {
    final chosen = await IdeDialogs.showRepoSelectorDialog(context, _targetRepo);
    if (chosen != null && chosen.contains('/')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('target_repo', chosen);
      setState(() => _targetRepo = chosen);
      _log('Switched target repository to: $chosen');
    }
  }

  Future<void> _openFile(File file) async {
    if (_activeFile?.path == file.path) return;
    if (_activeFile != null && _isDirty) await _saveFile();
    if (!_openTabs.any((f) => f.path == file.path)) _openTabs.add(file);

    final text = await file.readAsString();
    _savedFileSnapshot = text;
    setState(() {
      _activeFile = file;
      _editorController.text = text;
      _isDirty = false;
    });
    _log('Opened: ${file.path.split("/").last}');
  }

  Future<void> _closeTab(File file) async {
    final idx = _openTabs.indexWhere((f) => f.path == file.path);
    if (idx == -1) return;
    if (_activeFile?.path == file.path && _isDirty) await file.writeAsString(_editorController.text);

    setState(() {
      _openTabs.removeAt(idx);
      if (_activeFile?.path == file.path) {
        if (_openTabs.isNotEmpty) {
          final next = idx >= _openTabs.length ? _openTabs.length - 1 : idx;
          _openFile(_openTabs[next]);
        } else {
          _activeFile = null;
          _editorController.text = '';
          _savedFileSnapshot = '';
          _isDirty = false;
        }
      }
    });
  }

  Future<void> _saveFile() async {
    if (_activeFile == null) return;
    await _activeFile!.writeAsString(_editorController.text);
    _savedFileSnapshot = _editorController.text;
    setState(() {
      _isDirty = false;
      _unpushedFiles.add(_activeFile!.path);
    });
    _log('Saved: ${_activeFile!.path.split("/").last}');
  }

  Future<void> _deleteEntity(FileSystemEntity entity, bool isDir) async {
    final name = entity.path.split('/').last;
    final confirmed = await IdeDialogs.showDeleteDialog(context, name, isDir);
    if (confirmed == true) {
      if (!isDir && entity is File) await _closeTab(entity);
      await entity.delete(recursive: true);
      _log('Deleted: $name');
      final tree = await _repo.loadFileTree();
      setState(() => _files = tree);
    }
  }

  Future<void> _newEntity({required bool isDirectory}) async {
    final name = await IdeDialogs.showNewEntityDialog(context, isDirectory: isDirectory);
    if (name != null && name.isNotEmpty) {
      final root = await _repo.workspaceDir;
      final path = '${root.path}/demo_app/lib/$name';
      if (isDirectory) {
        await Directory(path).create(recursive: true);
      } else {
        final f = File(path);
        await f.create(recursive: true);
        await _openFile(f);
      }
      final tree = await _repo.loadFileTree();
      setState(() => _files = tree);
    }
  }

  Future<void> _triggerPipeline() async {
    final result = await IdeDialogs.showBuildDialog(context, _savedPat, _targetRepo);
    if (result == null) return;

    final token = result['token'] ?? '';
    final repo = result['repo'] ?? _targetRepo;
    final target = result['target'] ?? 'android-arm64';
    
    if (token.isEmpty && target != 'local') return;
    if ((repo.isEmpty || !repo.contains('/')) && target != 'local') {
      _log('Error: A valid owner/repo destination is required for cloud builds.');
      setState(() => _activePanel = 4);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_pat_token', token);
    await prefs.setString('target_repo', repo);
    setState(() {
      _savedPat = token;
      _targetRepo = repo;
      _activePanel = 4;
    });

    if (_activeFile != null) await _saveFile();
    final root = await _repo.workspaceDir;
    final projectDir = Directory('${root.path}/demo_app');
    
    final service = _createService(token);
    final runner = PipelineController(
      service: service,
      target: target,
      onLog: _log,
      onStatusChanged: (status) => setState(() => _buildStatus = status),
    );

    if (target == 'local') {
      runner.runLocalBuild(projectDir);
    } else {
      runner.runPipeline(projectDir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            IdeAppBar(
              isPreviewMode: _isPreviewMode,
              hasActiveFile: _activeFile != null,
              onTogglePreview: () {
                if (_activeFile != null) _saveFile();
                setState(() => _isPreviewMode = !_isPreviewMode);
              },
              onBuildAndInstall: _triggerPipeline,
              onSave: _saveFile,
            ),
            Expanded(
              child: Row(
                children: [
                  IdeActivityRail(
                    activePanel: _activePanel,
                    onPanelSelected: (p) => setState(() => _activePanel = p),
                    onOpenPalette: () => IdeCommandPalette.show(
                      context,
                      IdeCommandPalette(
                        files: _files,
                        onSave: _saveFile,
                        onFormat: () => _editorController.value = TextEditingValue(
                          text: EditorUtils.formatDartCode(_editorController.text),
                          selection: const TextSelection.collapsed(offset: 0),
                        ),
                        onBuild: _triggerPipeline,
                        onNewFile: () => _newEntity(isDirectory: false),
                        onOpenFile: _openFile,
                      ),
                    ),
                    onOpenSettings: () => IdeDialogs.showSettingsDialog(
                      context: context,
                      initialFontSize: _fontSize,
                      initialTheme: _theme,
                      onSave: (fs, th) async {
                        final p = await SharedPreferences.getInstance();
                        await p.setDouble('editor_font_size', fs);
                        await p.setString('editor_theme', th);
                        setState(() {
                          _fontSize = fs;
                          _theme = th;
                        });
                      },
                    ),
                  ),
                  Visibility(
                    visible: _activePanel != 0,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: false,
                    child: Container(
                      width: isCompact ? 220 : 260,
                      decoration: const BoxDecoration(
                        color: Color(0xFF21252B),
                        border: Border(right: BorderSide(color: Color(0xFF282C34))),
                      ),
                      child: IndexedStack(
                        index: _activePanel > 0 ? _activePanel - 1 : 0,
                        children: [
                          IdeExplorerPanel(
                            files: _files,
                            activeFile: _activeFile,
                            unpushedFiles: _unpushedFiles,
                            onFileSelected: _openFile,
                            onDeleteEntity: _deleteEntity,
                            onNewFile: () => _newEntity(isDirectory: false),
                            onNewFolder: () => _newEntity(isDirectory: true),
                          ),
                          IdeGitPanel(
                            activeRepo: _targetRepo.isEmpty ? 'Tap ⇄ to configure repo' : _targetRepo,
                            isBusy: _isGitBusy,
                            unpushedFiles: _unpushedFiles,
                            onCommitAndPush: _commitAndPush,
                            onChangeRepo: _switchTargetRepo,
                          ),
                          IdeSearchPanel(files: _files, onOpenFile: _openFile),
                          IdeConsolePanel(logs: _consoleLogs, onClear: () => setState(() => _consoleLogs.clear())),
                          const IdeSshPanel(),
                        ],
                      ),
                    ),
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
                                  ? const Center(child: Text('DashIDE Workspace', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF5C6370))))
                                  : CodeEditorView(
                                      controller: _editorController,
                                      fontSize: _fontSize,
                                      themeName: _theme,
                                      onCursorMoved: _handleEditorChange,
                                    )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IdeStatusBar(
              branch: _targetRepo.isEmpty ? 'no-repo' : _targetRepo.split('/').last,
              buildStatus: _buildStatus,
              line: _cursorLine,
              col: _cursorCol,
            ),
          ],
        ),
      ),
    );
  }
}
