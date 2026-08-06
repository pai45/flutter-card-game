import 'dart:io';

void main() {
  final content = File(
    'lib/services/prediction_repository.dart',
  ).readAsStringSync();
  final regex = RegExp(
    r"id:\s*'([^']+)',\s*name:\s*'([^']+)',\s*shortName:\s*'([^']+)',\s*color:\s*Color\((0x[0-9a-fA-F]+)\)",
  );
  final matches = regex.allMatches(content);

  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln();
  buffer.writeln("const Map<String, Color> kTeamColors = {");

  final seen = <String>{};
  for (final match in matches) {
    final shortName = match.group(3)!;
    if (!seen.contains(shortName)) {
      final name = match.group(2)!;
      final color = match.group(4)!;
      buffer.writeln("  '$shortName': Color($color), // $name");
      seen.add(shortName);
    }
  }

  buffer.writeln("};");
  File('lib/data/team_colors.dart').writeAsStringSync(buffer.toString());
}
