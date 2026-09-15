import 'package:flutter/material.dart';

class IdeActivityRail extends StatelessWidget {
  final int activePanel;
  final Function(int) onPanelSelected;

  const IdeActivityRail({
    super.key,
    required this.activePanel,
    required this.onPanelSelected,
  });

  Widget _buildRailIcon({
    required IconData icon,
    required int index,
    required String tooltip,
  }) {
    final isSelected = activePanel == index;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onPanelSelected(activePanel == index ? 0 : index),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? const Color(0xFF61AFEF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? const Color(0xFF61AFEF) : const Color(0xFF5C6370),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      color: const Color(0xFF181A1F),
      child: Column(
        children: [
          _buildRailIcon(
            icon: Icons.folder_outlined,
            index: 1,
            tooltip: 'Explorer',
          ),
          _buildRailIcon(
            icon: Icons.terminal_outlined,
            index: 2,
            tooltip: 'Console Logs',
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF5C6370)),
            onPressed: () {},
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
