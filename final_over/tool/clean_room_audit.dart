import 'dart:io';

void main() {
  final violations = <String>[];
  final roots = ['lib', 'test', 'assets'];
  final forbidden = [
    'super_over',
    'SuperOver',
    'superOver',
    'FinalStand',
    'FINAL STAND',
  ];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final extension = entity.path.split('.').last.toLowerCase();
      if (!{'dart', 'yaml', 'json', 'md', 'txt'}.contains(extension)) continue;
      final content = entity.readAsStringSync();
      if (content.contains('package:card_game')) {
        violations.add('${entity.path}: imports the host package');
      }
      if (RegExp(
        r'''import\s+['"]\.\./''',
        caseSensitive: false,
      ).hasMatch(content)) {
        violations.add(
          '${entity.path}: imports outside the standalone package',
        );
      }
      for (final token in forbidden) {
        if (content.contains(token)) {
          violations.add(
            '${entity.path}: contains forbidden identifier $token',
          );
        }
      }
    }
  }
  final pubspec = File('pubspec.yaml').readAsStringSync();
  if (pubspec.contains('../')) {
    violations.add('pubspec.yaml: contains a parent path dependency or asset');
  }
  if (violations.isNotEmpty) {
    stderr.writeln(violations.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Clean-room audit passed: Final Over is isolated.');
}
