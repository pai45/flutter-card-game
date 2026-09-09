/// Championship data from ESPN's racing standings document. No roster joins,
/// scoring rules, or synthetic race results are needed to interpret this feed.
class F1LeagueData {
  const F1LeagueData({
    required this.season,
    required this.fetchedAt,
    required this.drivers,
    required this.constructors,
    required this.rounds,
  });

  final int season;
  final DateTime fetchedAt;
  final List<F1Standing> drivers;
  final List<F1Standing> constructors;
  final List<F1LeagueRound> rounds;

  List<F1LeagueRound> get recordedRounds =>
      rounds.where((r) => r.played).toList();

  factory F1LeagueData.fromEspn(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
  }) {
    final drivers = <F1Standing>[];
    final constructors = <F1Standing>[];
    final rounds = <String, F1LeagueRound>{};
    int? season;
    for (final child in _maps(json['children'])) {
      final table = _map(child['standings']);
      final year = int.tryParse('${table['season']}');
      if (year == null || (season != null && year != season)) {
        throw const FormatException('Missing or inconsistent F1 season');
      }
      season = year;
      for (final entry in _maps(table['entries'])) {
        final isConstructor = entry['team'] is Map;
        final identity = _map(entry[isConstructor ? 'team' : 'athlete']);
        final id = identity['id']?.toString();
        final name = identity['displayName'] ?? identity['name'];
        if (id == null || name is! String || name.isEmpty) continue;
        final stats = {
          for (final stat in _maps(entry['stats']))
            stat['name']?.toString(): stat,
        };
        final byRace = <String, num>{};
        for (final stat in stats.values) {
          // Real race fields carry an event id and played flag. Do not guess
          // races from a stat name: ESPN can introduce other aggregate stats.
          if (stat['id'] == null || stat['played'] is! bool) continue;
          final code = stat['name'].toString();
          final played = stat['played'] == true;
          final old = rounds[code];
          rounds[code] = F1LeagueRound(
            id: stat['id'].toString(),
            code: code,
            name: (stat['shortName'] ?? stat['displayName'] ?? code).toString(),
            played: played || (old?.played ?? false),
          );
          final display = stat['displayValue']?.toString().trim() ?? '';
          if (!played || display.isEmpty) continue;
          final points = display == '-' ? 0 : _number(stat);
          if (points != null) byRace[code] = points;
        }
        final row = F1Standing(
          id: id,
          name: name,
          abbreviation: isConstructor
              ? null
              : identity['abbreviation'] as String?,
          flag: _map(identity['flag'])['href'] as String?,
          rank: _number(stats['rank'])?.toInt(),
          points: _number(stats[isConstructor ? 'points' : 'championshipPts']),
          byRace: Map.unmodifiable(byRace),
        );
        (isConstructor ? constructors : drivers).add(row);
      }
    }
    if (season == null || (drivers.isEmpty && constructors.isEmpty)) {
      throw const FormatException('ESPN returned no F1 standings');
    }
    int compare(F1Standing a, F1Standing b) =>
        (a.rank ?? 9999).compareTo(b.rank ?? 9999);
    drivers.sort(compare);
    constructors.sort(compare);
    return F1LeagueData(
      season: season,
      fetchedAt: fetchedAt,
      drivers: List.unmodifiable(drivers),
      constructors: List.unmodifiable(constructors),
      rounds: List.unmodifiable(rounds.values),
    );
  }
}

class F1Standing {
  const F1Standing({
    required this.id,
    required this.name,
    required this.rank,
    required this.points,
    required this.byRace,
    this.abbreviation,
    this.flag,
  });
  final String id;
  final String name;
  final String? abbreviation;
  final String? flag;
  final int? rank;
  final num? points;
  final Map<String, num> byRace;
  int get scoringRounds => byRace.values.where((p) => p > 0).length;
  num? get bestWeekend =>
      byRace.isEmpty ? null : byRace.values.reduce((a, b) => a > b ? a : b);
}

class F1LeagueRound {
  const F1LeagueRound({
    required this.id,
    required this.code,
    required this.name,
    required this.played,
  });
  final String id;
  final String code;
  final String name;
  final bool played;
}

String f1Number(num? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
Iterable<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v))
    : const [];
num? _number(Map<String, dynamic>? stat) => stat == null
    ? null
    : num.tryParse('${stat['displayValue']}'.trim()) ??
          (stat['value'] is num ? stat['value'] as num : null);
