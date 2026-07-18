class F1RaceCard {
  const F1RaceCard({
    required this.year,
    required this.trackName,
    required this.driverName,
    required this.teamName,
    required this.country,
  });

  final String year;
  final String trackName;
  final String driverName;
  final String teamName;
  final String country;

  String get id => '$year-$trackName-$driverName';
}

class GuessDriverArchive {
  const GuessDriverArchive({this.resultsByDay = const {}});

  final Map<String, GuessDriverDailyResult> resultsByDay;

  factory GuessDriverArchive.fromJson(Map<String, dynamic> json) {
    final results = <String, GuessDriverDailyResult>{};
    if (json['resultsByDay'] is Map) {
      final map = json['resultsByDay'] as Map;
      for (final key in map.keys) {
        if (map[key] is Map<String, dynamic>) {
          results[key.toString()] = GuessDriverDailyResult.fromJson(
            map[key] as Map<String, dynamic>,
          );
        }
      }
    }
    return GuessDriverArchive(resultsByDay: results);
  }

  Map<String, dynamic> toJson() => {
    'resultsByDay': resultsByDay.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class GuessDriverDailyResult {
  const GuessDriverDailyResult({
    required this.won,
    required this.heartsRemaining,
    required this.targetDriverName,
  });

  final bool won;
  final int heartsRemaining;
  final String targetDriverName;

  factory GuessDriverDailyResult.fromJson(Map<String, dynamic> json) {
    return GuessDriverDailyResult(
      won: json['won'] as bool? ?? false,
      heartsRemaining: json['heartsRemaining'] as int? ?? 0,
      targetDriverName: json['targetDriverName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'won': won,
    'heartsRemaining': heartsRemaining,
    'targetDriverName': targetDriverName,
  };
}
