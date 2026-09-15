import "dart:io";
import "package:path_provider/path_provider.dart";
import "../models/file_node.dart";

class WorkspaceRepository {
  Future<Directory> get workspaceDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory("${docs.path}/workspace");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<FileNode>> loadFileTree() async {
    final root = await workspaceDir;
    return _scanDirectory(root);
  }

  List<FileNode> _scanDirectory(Directory dir) {
    if (!dir.existsSync()) return [];
    final List<FileSystemEntity> entities = dir.listSync();
    entities.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    return entities.map((entity) {
      final name = entity.uri.pathSegments.where((e) => e.isNotEmpty).last;
      if (entity is Directory) {
        return FileNode(
          entity: entity,
          name: name,
          isDirectory: true,
          children: _scanDirectory(entity),
        );
      }
      return FileNode(
        entity: entity,
        name: name,
        isDirectory: false,
      );
    }).toList();
  }

  Future<void> initDefaultProject() async {
    final root = await workspaceDir;
    final libDir = Directory("${root.path}/demo_app/lib");
    if (!await libDir.exists()) {
      await libDir.create(recursive: true);
      final mainDart = File("${libDir.path}/main.dart");
      await mainDart.writeAsString(r"""import package:flutter/material.dart;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(Built