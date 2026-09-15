import "dart:io";

class FileNode {
  final FileSystemEntity entity;
  final String name;
  final bool isDirectory;
  final List<FileNode> children;

  FileNode({
    required this.entity,
    required this.name,
    required this.isDirectory,
    this.children = const [],
  });
}
