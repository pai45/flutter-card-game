import 'dart:io';

void main() {
  final file = File('lib/services/espn_score_service.dart');
  String content = file.readAsStringSync();

  // Add _getAthleteName
  final toAdd = '''
  String _getAthleteName(dynamic athlete) {
    if (athlete == null) return 'Unknown';
    String shortName = athlete['shortName']?.toString().trim() ?? '';
    if (shortName.isNotEmpty) return shortName;
    String displayName = athlete['displayName']?.toString().trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    String fullName = athlete['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    return 'Unknown';
  }
''';

  if (!content.contains('_getAthleteName')) {
    content = content.replaceFirst(
      'class EspnScoreService {',
      'class EspnScoreService {\n$toAdd',
    );
  }

  // Replacements
  content = content.replaceAll(
    "athletes[0]['shortName'] ?? athletes[0]['displayName']",
    "_getAthleteName(athletes[0])",
  );

  content = content.replaceAll(
    "fow['athlete']?['shortName']?.toString() ?? 'Unknown'",
    "_getAthleteName(fow['athlete'])",
  );

  content = content.replaceAll(
    "player['athlete']?['shortName']?.toString() ?? 'Unknown'",
    "_getAthleteName(player['athlete'])",
  );

  content = content.replaceAll(
    "athlete['shortName'] ?? athlete['displayName'] ?? 'Unknown'",
    "_getAthleteName(athlete)",
  );

  content = content.replaceAll(
    "participants[0]['athlete']?['shortName'] ?? participants[0]['athlete']?['displayName'] ?? 'Unknown'",
    "_getAthleteName(participants[0]['athlete'])",
  );

  content = content.replaceAll(
    "participants[1]['athlete']?['shortName'] ?? participants[1]['athlete']?['displayName']",
    "_getAthleteName(participants[1]['athlete'])",
  );

  file.writeAsStringSync(content);
  print('Done applying replacements.');
}
