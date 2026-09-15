import "dart:io";
import "package:flutter/material.dart";
import "package:re_editor/re_editor.dart";
import "data/models/file_node.dart";
import "data/repositories/workspace_repository.dart";
import "presentation/widgets/code_editor_view.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashIDEApp());
}

class DashIDEApp extends StatelessWidget {
  const DashIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "DashIDE",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
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
  final CodeEditorController _editorController = CodeEditorController();
  List<FileNode> _files = [];
  File? _activeFile;

  @override
  void initState() {
    super.initState();
    _initWorkspace();
  }

  Future<void> _initWorkspace() async {
    await _repo.initDefaultProject();
    final tree = await _repo.loadFileTree();
    setState(() {
      _files = tree;
    });

    // Automatically open the first main.dart found
    final mainDart = _findMainDart(tree);
    if (mainDart != null) {
      await _openFile(mainDart);
    }
  }

  File? _findMainDart(List<FileNode> nodes) {
    for (final node in nodes) {
      if (!node.isDirectory && node.name == "main.dart") {
        return node.entity as File;
      }
      final nested = _findMainDart(node.children);
      if (nested != null) return nested;
    }
    return null;
  }

  Future<void> _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      _activeFile = file;
      _editorController.text = content;
    });
  }

  Future<void> _saveCurrentFile() async {
    if (_activeFile != null) {
      await _activeFile!.writeAsString(_editorController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved ${_activeFile!.path.split("/").last}"),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activeFile?.path.split("/").last ?? "DashIDE"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _activeFile == null ? null : _saveCurrentFile,
            tooltip: "Save File",
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Center(
                child: Text(
                  "DashIDE Explorer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: _buildFileTreeTiles(_files),
              ),
            ),
          ],
        ),
      ),
      body: _activeFile == null
          ? const Center(child: Text("Select a file from the explorer"))
          : CodeEditorView(controller: _editorController),
    );
  }

  List<Widget> _buildFileTreeTiles(List<FileNode> nodes) {
    return nodes.map((node) {
      if (node.isDirectory) {
        return ExpansionTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(node.name),
          children: _buildFileTreeTiles(node.children),
        );
      }
      return ListTile(
        leading: const Icon(Icons.code, color: Colors.lightBlue),
        title: Text(node.name),
        onTap: () {
          Navigator.pop(context);
          _openFile(node.entity as File);
        },
      );
    }).toList();
  }
}
