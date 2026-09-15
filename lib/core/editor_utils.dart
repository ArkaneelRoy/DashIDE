class EditorUtils {
  static const Map<String, String> snippets = {
    'stless': '''class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}''',
    'stful': '''class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key});

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}''',
    'setState': '''setState(() {

});''',
    'column': '''Column(
  children: const [

  ],
)''',
    'row': '''Row(
  children: const [

  ],
)''',
    'center': '''Center(
  child: 
)''',
  };

  /// Simple rule-based indentation for offline formatting
  static String formatDartCode(String input) {
    final lines = input.split('\n');
    final formatted = <String>[];
    int indentLevel = 0;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        formatted.add('');
        continue;
      }

      // Decrease indent if line starts with closing bracket
      if (line.startsWith('}') || line.startsWith(')') || line.startsWith(']')) {
        indentLevel = (indentLevel - 1).clamp(0, 50);
      }

      formatted.add('${"  " * indentLevel}$line');

      // Adjust indent for subsequent lines based on bracket count
      final opens = '{'.allMatches(line).length +
          '('.allMatches(line).length +
          '['.allMatches(line).length;
      final closes = '}'.allMatches(line).length +
          ')'.allMatches(line).length +
          ']'.allMatches(line).length;

      indentLevel += (opens - closes);
      if (indentLevel < 0) indentLevel = 0;
    }

    return formatted.join('\n');
  }
}
