import 'package:flutter/material.dart';

class LivePreviewView extends StatelessWidget {
  final String dartCode;

  const LivePreviewView({super.key, required this.dartCode});

  @override
  Widget build(BuildContext context) {
    if (dartCode.trim().isEmpty) {
      return const Center(
        child: Text(
          'No code open to preview',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF282C34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3B4048)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_outlined, color: Colors.cyanAccent, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ready for Remote Execution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Source code is synced and verified. Tap "Sync & Build APK" in the toolbar to compile on GitHub Actions and install directly to this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFFABB2BF), height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF21252B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${dartCode.split("\n").length} lines loaded',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
