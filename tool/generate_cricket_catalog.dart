import 'dart:io';

final _csvPath = File('ipl_players.csv');
final _cardsPath = File('lib/models/cards.dart');
final _imageDir = Directory('assets/cricketer_images');

void main() {
  final rows = _readCsv(_csvPath.readAsStringSync());
  final imagesByName = _imageAssetsByName();
  final idCounts = <String, int>{};

  final batting = <String>[];
  final bowling = <String>[];

  for (final row in rows) {
    final name = row['name']!;
    final role = row['role']!;
    final team = row['team']!;
    final teamCode = row['team_code']!;
    final shortName = row['short_name']!;
    final rating = int.parse(row['rating']!);
    final tier = _tier(row['tier']!);
    final isBowler = role == 'Bowler';
    final roleValue = isBowler ? 'PlayerRole.bowler' : 'PlayerRole.batsman';
    final position = switch (role) {
      'Wicket-keeper' => 'WK',
      'All-rounder' => 'AR',
      'Bowler' => 'BOWL',
      _ => 'BAT',
    };
    final baseId = 'cricket-${teamCode.toLowerCase()}-${_slug(name)}';
    final count = idCounts.update(
      baseId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    final id = count == 1 ? baseId : '$baseId-$count';
    final portrait = imagesByName[_normalize(name)];

    final card =
        "  PlayerCard(id: '${_dart(id)}', name: '${_dart(name)}', shortName: '${_dart(shortName)}', country: '${_dart(team)}', countryCode: '${_dart(teamCode)}', position: '$position', role: $roleValue, rating: $rating, trait: '${_dart(role)}', tier: $tier, icon: Icons.sports_cricket${portrait == null ? '' : ", portraitAsset: '${_dart(portrait)}'"}),";

    if (isBowler) {
      bowling.add(card);
    } else {
      batting.add(card);
    }
  }

  final generated =
      '''
const footballPlayerCards = [...attackers, ...defenders, ...goalkeepers];

const cricketBattingCards = [
${batting.join('\n')}
];

const cricketBowlingCards = [
${bowling.join('\n')}
];

const cricketPlayerCards = [...cricketBattingCards, ...cricketBowlingCards];

const batsmen = cricketBattingCards;

const allPlayerCards = [...footballPlayerCards, ...cricketPlayerCards];

''';

  final source = _cardsPath.readAsStringSync();
  final start = source.indexOf('const batsmen = [');
  final end = source.indexOf('/// A base action archetype.');
  if (start == -1 || end == -1 || end <= start) {
    throw StateError(
      'Could not find cricket catalog block in ${_cardsPath.path}.',
    );
  }
  _cardsPath.writeAsStringSync(source.replaceRange(start, end, generated));

  stdout.writeln(
    'Generated ${batting.length + bowling.length} cricket cards '
    '(${batting.length} batting, ${bowling.length} bowling).',
  );
}

List<Map<String, String>> _readCsv(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  final headers = _splitCsvLine(lines.first);
  return [
    for (final line in lines.skip(1))
      {
        for (var i = 0; i < headers.length; i++)
          headers[i]: _splitCsvLine(line)[i],
      },
  ];
}

List<String> _splitCsvLine(String line) {
  final values = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      values.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  values.add(buffer.toString());
  return values;
}

Map<String, String> _imageAssetsByName() {
  if (!_imageDir.existsSync()) return const {};
  return {
    for (final file in _imageDir.listSync().whereType<File>())
      if (_isImage(file.path))
        _normalize(
          file.uri.pathSegments.last
              .replaceFirst(RegExp(r'\.[^.]+$'), '')
              .replaceFirst(RegExp(r'^\d+_'), ''),
        ): file.path.replaceAll(
          r'\',
          '/',
        ),
  };
}

bool _isImage(String path) =>
    RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(path);

String _tier(String raw) => switch (raw) {
  'Platinum' => 'CardTier.platinum',
  'Gold' => 'CardTier.gold',
  'Silver' => 'CardTier.silver',
  _ => 'CardTier.bronze',
};

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'player' : slug;
}

String _dart(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
