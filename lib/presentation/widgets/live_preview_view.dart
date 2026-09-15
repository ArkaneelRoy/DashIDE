import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';

class LivePreviewView extends StatelessWidget {
  final String dartCode;

  const LivePreviewView({super.key, required this.dartCode});

  @override
  Widget build(BuildContext context) {
    if (dartCode.trim().isEmpty) {
      return const Center(
        child: Text('No code to preview.', style: TextStyle(color: Colors.grey)),
      );
    }

    try {
      return Container(
        color: Colors.white,
        child: EvalWidget(
          packages: const {
            'demo_app': {
              'main.dart': '''
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('DashIDE Running!')),
      ),
    );
  }
}
'''
            }
          },
          assetPath: null,
          library: 'package:demo_app/main.dart',
          function: 'MyApp.',
          args: const [],
        ),
      );
    } catch (e) {
      return Container(
        color: const Color(0xFF1E1E2E),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Live Preview Evaluation Error',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
  }
}
