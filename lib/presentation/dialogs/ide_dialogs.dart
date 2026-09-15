import 'package:flutter/material.dart';

class IdeDialogs {
  static Future<String?> showNewEntityDialog(BuildContext context, {required bool isDirectory}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: Text(isDirectory ? 'New Directory' : 'New Dart File', style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showDeleteDialog(BuildContext context, String entityName, bool isDirectory) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF21252B),
        title: Text('Delete $entityName?', style: const TextStyle(fontSize: 15)),
        content: Text(
          isDirectory ? 'Delete this folder and all internal contents?' : 'Delete this file permanently?',
          style: const TextStyle(fontSize: 13, color: Color(0xFFABB2BF)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE06C75)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static void showSettingsDialog({
    required BuildContext context,
    required double initialFontSize,
    required String initialTheme,
    required Function(double, String) onSave,
  }) {
    double currentFontSize = initialFontSize;
    String currentTheme = initialTheme;
    const themes = ['Atom One Dark', 'Dracula', 'Monokai', 'GitHub Light'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF21252B),
          title: const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF61AFEF), size: 18),
              SizedBox(width: 8),
              Text('IDE Settings', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Font Size', style: TextStyle(fontSize: 12, color: Color(0xFFABB2BF))),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: currentFontSize,
                      min: 10.0,
                      max: 22.0,
                      divisions: 12,
                      activeColor: const Color(0xFF61AFEF),
                      onChanged: (v) => setDialogState(() => currentFontSize = v),
                    ),
                  ),
                  Text('${currentFontSize.toInt()}pt', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Syntax Theme', style: TextStyle(fontSize: 12, color: Color(0xFFABB2BF))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2227),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF353B45)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF21252B),
                    value: currentTheme,
                    items: themes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => currentTheme = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF61AFEF)),
              onPressed: () {
                onSave(currentFontSize, currentTheme);
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showBuildDialog(BuildContext context, String initialToken) {
    final controller = TextEditingController(text: initialToken);
    return showDialog<String>(
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
              'Syncs local edits to GitHub, executes cloud ARM64 build, and installs APK.',
              style: TextStyle(fontSize: 12, color: Color(0xFFABB2BF)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'GitHub PAT', border: OutlineInputBorder(), isDense: true),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF98C379)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Build APK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
