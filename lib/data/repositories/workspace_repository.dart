import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_node.dart';

class WorkspaceRepository {
  Future<Directory> get workspaceDir async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/DashIDE_Workspace');
  }

  Future<void> initDefaultProject() async {
    final root = await workspaceDir;
    final projectDir = Directory('${root.path}/demo_app');
    
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    // 1. Generate default main.dart
    final libDir = Directory('${projectDir.path}/lib');
    if (!await libDir.exists()) {
      await libDir.create(recursive: true);
    }

    final mainFile = File('${libDir.path}/main.dart');
    if (!await mainFile.exists()) {
      await mainFile.writeAsString('''import 'package:flutter/material.dart';

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
''');
    }

    // 2. Generate default workspace pubspec.yaml
    final pubspecFile = File('${projectDir.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      await pubspecFile.writeAsString('''name: demo_app
description: A new Flutter project built in DashIDE.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  # Add your packages here (e.g., provider: ^6.1.2)
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
''');
    }
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
      
      // Hide internal hidden folders or build directories
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
