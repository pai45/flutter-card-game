class GuessPlayerArchive {
  const GuessPlayerArchive({this.resultsByDay = const {}});

  final Map<String, GuessPlayerDailyResult> resultsByDay;

  factory GuessPlayerArchive.fromJson(Map<String, dynamic> json) {
    final results = <String, GuessPlayerDailyResult>{};
    if (json['resultsByDay'] is Map) {
      final map = json['resultsByDay'] as Map;
      for (final key in map.keys) {
        if (map[key] is Map<String, dynamic>) {
          results[key.toString()] = GuessPlayerDailyResult.fromJson(
            map[key] as Map<String, dynamic>,
          );
        }
      }
    }
    return GuessPlayerArchive(resultsByDay: results);
  }

  Map<String, dynamic> toJson() => {
    'resultsByDay': resultsByDay.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class GuessPlayerDailyResult {
  const GuessPlayerDailyResult({
    required this.won,
    required this.heartsRemaining,
    required this.targetPlayerName,
  });

  final bool won;
  final int heartsRemaining;
  final String targetPlayerName;

  factory GuessPlayerDailyResult.fromJson(Map<String, dynamic> json) {
    return GuessPlayerDailyResult(
      won: json['won'] as bool? ?? false,
      heartsRemaining: json['heartsRemaining'] as int? ?? 0,
      targetPlayerName: json['targetPlayerName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'won': won,
    'heartsRemaining': heartsRemaining,
    'targetPlayerName': targetPlayerName,
  };
}
