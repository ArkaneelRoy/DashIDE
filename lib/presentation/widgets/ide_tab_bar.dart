import 'dart:io';
import 'package:flutter/material.dart';

class IdeTabBar extends StatelessWidget {
  final List<File> openTabs;
  final File? activeFile;
  final bool isDirty;
  final Function(File) onSelectTab;
  final Function(File) onCloseTab;

  const IdeTabBar({
    super.key,
    required this.openTabs,
    required this.activeFile,
    this.isDirty = false,
    required this.onSelectTab,
    required this.onCloseTab,
  });

  @override
  Widget build(BuildContext context) {
    if (openTabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 34,
      color: const Color(0xFF1E2227),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: openTabs.length,
        itemBuilder: (context, index) {
          final file = openTabs[index];
          final isSelected = activeFile?.path == file.path;
          return InkWell(
            onTap: () => onSelectTab(file),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF282C34) : const Color(0xFF1E2227),
                border: Border(
                  right: const BorderSide(color: Color(0xFF181A1F)),
                  top: BorderSide(
                    color: isSelected ? const Color(0xFF61AFEF) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 13, color: Color(0xFF61AFEF)),
                  const SizedBox(width: 6),
                  Text(
                    file.path.split('/').last,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFF5C6370),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected && isDirty)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5C07B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  GestureDetector(
                    onTap: () => onCloseTab(file),
                    child: const Icon(Icons.close, size: 12, color: Color(0xFF5C6370)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
