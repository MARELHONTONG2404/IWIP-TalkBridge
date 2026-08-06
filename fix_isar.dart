// ignore_for_file: avoid_print

import 'dart:io';
void main() {
  final dir = Directory('lib/core/database/collections');
  if (!dir.existsSync()) return;
  
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.g.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    
    // Pattern to match id: <number>
    final regExp = RegExp(r'id:\s*(-?\d+)');
    content = content.replaceAllMapped(regExp, (match) {
      final numStr = match.group(1)!;
      final num = int.tryParse(numStr);
      if (num != null) {
        if (num > 9007199254740991 || num < -9007199254740991) {
          final isNeg = num < 0;
          var absStr = num.abs().toString();
          if (absStr.length > 15) {
            absStr = absStr.substring(0, 15);
          }
          final newNumStr = (isNeg ? '-' : '') + absStr;
          return 'id: $newNumStr';
        }
      }
      return match.group(0)!;
    });
    
    file.writeAsStringSync(content);
    print('Fixed ${file.path}');
  }
}
