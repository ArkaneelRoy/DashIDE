import 'package:flutter/material.dart';

class IdeStatusBar extends StatelessWidget {
  final String branch;
  final String buildStatus;
  final int line;
  final int col;

  const IdeStatusBar({
    super.key,
    this.branch = 'main',
    required this.buildStatus,
    required this.line,
    required this.col,
  });

  Color get _statusColor {
    switch (buildStatus) {
      case 'Ready':
      case 'Idle':
        return const Color(0xFF98C379); // Green
      case 'Syncing...':
      case 'Compiling...':
      case 'Downloading...':
        return const Color(0xFF61AFEF); // Cyan
      case 'Timeout':
      case 'Dispatching...':
        return const Color(0xFFE5C07B); // Yellow
      case 'Failed':
      case 'Error':
      case 'No Artifact':
      default:
        return const Color(0xFFE06C75); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF181A1F),
        border: Border(top: BorderSide(color: Color(0xFF282C34))),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined, size: 11, color: Color(0xFF61AFEF)),
          const SizedBox(width: 4),
          Text(branch, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF5C6370))),
          const SizedBox(width: 14),
          Icon(Icons.circle, size: 7, color: _statusColor),
          const SizedBox(width: 5),
          Text(buildStatus, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF5C6370))),
          const Spacer(),
          Text(
            'Ln $line, Col $col',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF5C6370)),
          ),
          const SizedBox(width: 14),
          const Text(
            'UTF-8',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF5C6370)),
          ),
        ],
      ),
    );
  }
}
