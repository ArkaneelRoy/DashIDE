import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_node.dart';

class WorkspaceRepository {
  Future<Directory> get workspaceDir async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/DashIDE_Workspace');
  }

  static const String defaultMainDart = '''import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('Built inside DashIDE!'),
        ),
      ),
    );
  }
}
''';

  Future<void> initDefaultProject() async {
    final root = await workspaceDir;
    final projectDir = Directory('${root.path}/demo_app');
    
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    final libDir = Directory('${projectDir.path}/lib');
    if (!await libDir.exists()) {
      await libDir.create(recursive: true);
    }

    // Only create a minimal bootstrap main.dart if lib/ has nothing
    final mainFile = File('${libDir.path}/main.dart');
    if (!await mainFile.exists()) {
      await mainFile.writeAsString(defaultMainDart);
    }
    // No automatic pubspec creation or regeneration:
    // pubspec.yaml persists exactly as written by the user.
  }

  Future<List<FileNode>> loadFileTree() async {
    final root = await workspaceDir;
    final projectDir = Directory('${root.path}/demo_app');
    if (!await projectDir.exists()) return [];
    return _buildTree(projectDir);
  }

  List<FileNode> _buildTree(Directory dir) {
    final nodes = <FileNode>[];
    final entities = dir.listSync()..sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    for (final entity in entities) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.') || name == 'build') continue;

      if (entity is Directory) {
        nodes.add(FileNode(
          name: name,
          entity: entity,
          isDirectory: true,
          children: _buildTree(entity),
        ));
      } else if (entity is File) {
        nodes.add(FileNode(
          name: name,
          entity: entity,
          isDirectory: false,
          children: const [],
        ));
      }
    }
    return nodes;
  }
}
