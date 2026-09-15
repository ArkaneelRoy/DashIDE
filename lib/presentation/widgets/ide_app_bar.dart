import 'package:flutter/material.dart';

class IdeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isPreviewMode;
  final bool hasActiveFile;
  final VoidCallback onTogglePreview;
  final VoidCallback onBuildAndInstall;
  final VoidCallback onSave;

  const IdeAppBar({
    super.key,
    required this.isPreviewMode,
    required this.hasActiveFile,
    required this.onTogglePreview,
    required this.onBuildAndInstall,
    required this.onSave,
  });

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2227),
        border: Border(bottom: BorderSide(color: Color(0xFF282C34))),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Color(0xFF61AFEF), size: 18),
          const SizedBox(width: 8),
          const Text(
            'DashIDE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
              color: Color(0xFFABB2BF),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              isPreviewMode ? Icons.code : Icons.play_arrow_outlined,
              size: 18,
              color: isPreviewMode ? const Color(0xFFE5C07B) : const Color(0xFF98C379),
            ),
            tooltip: isPreviewMode ? 'Code Editor' : 'Live Preview',
            onPressed: onTogglePreview,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF61AFEF)),
            tooltip: 'Build & Install APK',
            onPressed: onBuildAndInstall,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 18, color: Color(0xFFABB2BF)),
            tooltip: 'Save',
            onPressed: hasActiveFile ? onSave : null,
          ),
        ],
      ),
    );
  }
}
