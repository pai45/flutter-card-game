import 'daily_mystery.dart';

class GrandSlamCard {
  const GrandSlamCard({
    required this.year,
    required this.tournament,
    required this.category,
    required this.winnerName,
  });

  final String year;
  final String tournament;
  final String category;
  final String winnerName;

  String get id => '$year-$tournament-$category-$winnerName';
}

class GuessWinnerArchive {
  const GuessWinnerArchive({this.resultsByDay = const {}});

  final Map<String, GuessWinnerDailyResult> resultsByDay;

  int get wonCount => resultsByDay.values.where((result) => result.won).length;

  int get playedCount => resultsByDay.length;

  double get winRate => playedCount == 0 ? 0 : wonCount / playedCount;

  int get bestHeartsRemaining => resultsByDay.values
      .where((result) => result.won)
      .fold<int>(0, (best, result) {
        return result.heartsRemaining > best ? result.heartsRemaining : best;
      });

  int winStreak(String currentDayKey) => dailyMysteryWinStreak(
    resultsByDay,
    currentDayKey,
    (result) => result.won,
  );

  factory GuessWinnerArchive.fromJson(Map<String, dynamic> json) {
    final results = <String, GuessWinnerDailyResult>{};
    if (json['resultsByDay'] is Map) {
      final map = json['resultsByDay'] as Map;
      for (final key in map.keys) {
        if (map[key] is Map<String, dynamic>) {
          results[key.toString()] = GuessWinnerDailyResult.fromJson(
            map[key] as Map<String, dynamic>,
          );
        }
      }
    }
    return GuessWinnerArchive(resultsByDay: results);
  }

  Map<String, dynamic> toJson() => {
    'resultsByDay': resultsByDay.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class GuessWinnerDailyResult {
  const GuessWinnerDailyResult({
    required this.won,
    required this.heartsRemaining,
    required this.targetWinnerName,
  });

  final bool won;
  final int heartsRemaining;
  final String targetWinnerName;

  factory GuessWinnerDailyResult.fromJson(Map<String, dynamic> json) {
    return GuessWinnerDailyResult(
      won: json['won'] as bool? ?? false,
      heartsRemaining: json['heartsRemaining'] as int? ?? 0,
      targetWinnerName: json['targetWinnerName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'won': won,
    'heartsRemaining': heartsRemaining,
    'targetWinnerName': targetWinnerName,
  };
}
