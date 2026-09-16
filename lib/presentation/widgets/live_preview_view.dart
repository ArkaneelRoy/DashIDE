import 'package:flutter/material.dart';

class LivePreviewView extends StatelessWidget {
  final String dartCode;

  const LivePreviewView({
    super.key,
    required this.dartCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E24),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: 360,
          height: 640,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 48,
                color: const Color(0xFF61AFEF),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'DashIDE Live Canvas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_outlined, size: 48, color: Color(0xFF61AFEF)),
                        const SizedBox(height: 12),
                        const Text(
                          'Sandbox Preview Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dartCode.split("\n").length} lines ready for Cloud CI/CD build.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
