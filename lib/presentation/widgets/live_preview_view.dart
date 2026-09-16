import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';

class LivePreviewView extends StatelessWidget {
  final String dartCode;

  const LivePreviewView({
    super.key,
    required this.dartCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Standard app background for the preview
      child: Stack(
        children: [
          // The actual interpreted Flutter UI
          Positioned.fill(
            child: _buildEvaluator(),
          ),
          
          // A tiny overlay badge so you know you are in Preview mode
          Positioned(
            top: 16,
            right: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.yellow),
                    SizedBox(width: 4),
                    Text(
                      'LIVE EVAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluator() {
    if (dartCode.trim().isEmpty) {
      return _buildErrorState('Editor is empty.');
    }

    try {
      return EvalWidget(
        packages: {
          'demo_app': {
            'main.dart': dartCode,
          }
        },
        library: 'package:demo_app/main.dart',
        // Look for the default root widget
        function: 'MyApp',
      );
    } catch (e) {
      return _buildErrorState(e.toString());
    }
  }

  Widget _buildErrorState(String error) {
    return Container(
      color: const Color(0xFF1E1E24), // Match IDE dark theme on error
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE06C75), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Evaluation Error',
              style: TextStyle(
                color: Color(0xFFE06C75),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFABB2BF),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Note: Live Eval requires your root widget to be named `MyApp` and does not support external packages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5C6370),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          ],
        ),
      ),
    );
  }
}
