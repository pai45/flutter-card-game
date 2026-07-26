import 'sport_match.dart';

enum GuessPlayerDifficulty { easy, medium, hard }

enum GuessPlayerClueKind {
  career,
  debut,
  role,
  position,
  nation,
  team,
  trait,
  rating,
}

/// Optional player-profile scans that sit outside the career route.
///
/// These are persisted by name so a purchased scan is restored when a player
/// returns to the same daily mystery.
enum GuessPlayerHintType { position, affiliation }

enum GuessPlayerResultStatus { inProgress, won, lost, gaveUp, expired, legacy }

enum GuessPlayerViewMode { home, play, logs, review }

enum GuessPlayerLoadStatus { loading, ready, submitting, completed, error }

enum GuessPlayerSubmissionFeedback { none, wrong, correct, duplicate }

class GuessPlayerClue {
  const GuessPlayerClue({
    required this.kind,
    required this.label,
    required this.value,
    this.year,
    this.endYear,
  });

  final GuessPlayerClueKind kind;
  final String label;
  final String value;
  final int? year;
  final int? endYear;
}

class GuessPlayerPuzzle {
  const GuessPlayerPuzzle({
    required this.id,
    required this.sport,
    required this.playerId,
    required this.difficulty,
    required this.clues,
  });

  final String id;
  final Sport sport;
  final String playerId;
  final GuessPlayerDifficulty difficulty;
  final List<GuessPlayerClue> clues;
}

class GuessPlayerDayRecord {
  const GuessPlayerDayRecord({
    required this.dayKey,
    required this.puzzleId,
    required this.playerId,
    required this.status,
    required this.guessedPlayerIds,
    required this.revealedClueCount,
    required this.attemptsRemaining,
    required this.score,
    required this.xpEarned,
    required this.elapsedMs,
    required this.startedAtEpochMs,
    required this.completedAtEpochMs,
    this.targetPlayerName = '',
    this.revealedHintTypes = const [],
    this.legacy = false,
  });

  static const int schemaVersion = 2;

  final String dayKey;
  final String puzzleId;
  final String playerId;
  final String targetPlayerName;
  final GuessPlayerResultStatus status;
  final List<String> guessedPlayerIds;
  final int revealedClueCount;
  final int attemptsRemaining;
  final int score;
  final int xpEarned;
  final int elapsedMs;
  final int startedAtEpochMs;
  final int completedAtEpochMs;
  final List<String> revealedHintTypes;

  final bool legacy;

  bool get won => status == GuessPlayerResultStatus.won;
  bool get gaveUp => status == GuessPlayerResultStatus.gaveUp;
  bool get expired => status == GuessPlayerResultStatus.expired;
  bool get completed =>
      status != GuessPlayerResultStatus.inProgress &&
      status != GuessPlayerResultStatus.expired;
  bool get canReview => status != GuessPlayerResultStatus.inProgress || legacy;

  bool hasHint(GuessPlayerHintType type) =>
      revealedHintTypes.contains(type.name);

  // Compatibility with the v1 result contract.
  int get heartsRemaining => attemptsRemaining;

  GuessPlayerDayRecord copyWith({
    String? dayKey,
    String? puzzleId,
    String? playerId,
    String? targetPlayerName,
    GuessPlayerResultStatus? status,
    List<String>? guessedPlayerIds,
    int? revealedClueCount,
    int? attemptsRemaining,
    int? score,
    int? xpEarned,
    int? elapsedMs,
    int? startedAtEpochMs,
    int? completedAtEpochMs,
    List<String>? revealedHintTypes,
    bool? legacy,
  }) {
    return GuessPlayerDayRecord(
      dayKey: dayKey ?? this.dayKey,
      puzzleId: puzzleId ?? this.puzzleId,
      playerId: playerId ?? this.playerId,
      targetPlayerName: targetPlayerName ?? this.targetPlayerName,
      status: status ?? this.status,
      guessedPlayerIds: guessedPlayerIds ?? this.guessedPlayerIds,
      revealedClueCount: revealedClueCount ?? this.revealedClueCount,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      score: score ?? this.score,
      xpEarned: xpEarned ?? this.xpEarned,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      startedAtEpochMs: startedAtEpochMs ?? this.startedAtEpochMs,
      completedAtEpochMs: completedAtEpochMs ?? this.completedAtEpochMs,
      revealedHintTypes: revealedHintTypes ?? this.revealedHintTypes,
      legacy: legacy ?? this.legacy,
    );
  }

  factory GuessPlayerDayRecord.fromJson(
    String dayKey,
    Map<String, dynamic> json,
  ) {
    if (json['status'] == null) {
      return GuessPlayerDayRecord.fromLegacyJson(dayKey, json);
    }
    return GuessPlayerDayRecord(
      dayKey: dayKey,
      puzzleId: json['puzzleId'] as String? ?? '',
      playerId: json['playerId'] as String? ?? '',
      targetPlayerName: json['targetPlayerName'] as String? ?? '',
      status: GuessPlayerResultStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => GuessPlayerResultStatus.legacy,
      ),
      guessedPlayerIds: (json['guessedPlayerIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      revealedClueCount: json['revealedClueCount'] as int? ?? 1,
      attemptsRemaining: json['attemptsRemaining'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      startedAtEpochMs: json['startedAtEpochMs'] as int? ?? 0,
      completedAtEpochMs: json['completedAtEpochMs'] as int? ?? 0,
      revealedHintTypes:
          (json['revealedHintTypes'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .where(
                (value) => GuessPlayerHintType.values.any(
                  (type) => type.name == value,
                ),
              )
              .toList(),
      legacy: json['legacy'] as bool? ?? false,
    );
  }

  factory GuessPlayerDayRecord.fromLegacyJson(
    String dayKey,
    Map<String, dynamic> json,
  ) {
    final won = json['won'] as bool? ?? false;
    return GuessPlayerDayRecord(
      dayKey: dayKey,
      puzzleId: '',
      playerId: won ? 'legacy-won' : 'legacy-lost',
      targetPlayerName: json['targetPlayerName'] as String? ?? '',
      status: GuessPlayerResultStatus.legacy,
      guessedPlayerIds: const [],
      revealedClueCount: 6,
      attemptsRemaining: json['heartsRemaining'] as int? ?? 0,
      score: 0,
      xpEarned: 0,
      elapsedMs: 0,
      startedAtEpochMs: 0,
      completedAtEpochMs: 0,
      legacy: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'puzzleId': puzzleId,
    'playerId': playerId,
    'targetPlayerName': targetPlayerName,
    'status': status.name,
    'guessedPlayerIds': guessedPlayerIds,
    'revealedClueCount': revealedClueCount,
    'attemptsRemaining': attemptsRemaining,
    'score': score,
    'xpEarned': xpEarned,
    'elapsedMs': elapsedMs,
    'startedAtEpochMs': startedAtEpochMs,
    'completedAtEpochMs': completedAtEpochMs,
    'revealedHintTypes': revealedHintTypes,
    'gaveUp': gaveUp,
    'expired': expired,
    'legacy': legacy,
  };

  bool get legacyWon => legacy && playerId == 'legacy-won';
  bool get effectiveWon => won || legacyWon;
}

/// Source-compatible v1 constructor retained for older tests and callers.
class GuessPlayerDailyResult extends GuessPlayerDayRecord {
  const GuessPlayerDailyResult({
    required bool won,
    required int heartsRemaining,
    required super.targetPlayerName,
  }) : super(
         dayKey: '',
         puzzleId: '',
         playerId: won ? 'legacy-won' : 'legacy-lost',
         status: GuessPlayerResultStatus.legacy,
         guessedPlayerIds: const [],
         revealedClueCount: 6,
         attemptsRemaining: heartsRemaining,
         score: 0,
         xpEarned: 0,
         elapsedMs: 0,
         startedAtEpochMs: 0,
         completedAtEpochMs: 0,
         legacy: true,
       );
}

class GuessPlayerArchive {
  const GuessPlayerArchive({this.resultsByDay = const {}});

  final Map<String, GuessPlayerDayRecord> resultsByDay;

  factory GuessPlayerArchive.fromJson(Map<String, dynamic> json) {
    final results = <String, GuessPlayerDayRecord>{};
    final rawResults = json['resultsByDay'];
    if (rawResults is Map) {
      for (final entry in rawResults.entries) {
        final value = entry.value;
        if (value is Map) {
          results[entry.key.toString()] = GuessPlayerDayRecord.fromJson(
            entry.key.toString(),
            Map<String, dynamic>.from(value),
          );
        }
      }
    }
    return GuessPlayerArchive(resultsByDay: results);
  }

  GuessPlayerArchive copyWithRecord(GuessPlayerDayRecord record) {
    return GuessPlayerArchive(
      resultsByDay: {...resultsByDay, record.dayKey: record},
    );
  }

  int get solvedCount =>
      resultsByDay.values.where((record) => record.effectiveWon).length;

  int get completedCount => resultsByDay.values
      .where(
        (record) =>
            record.completed || record.status == GuessPlayerResultStatus.legacy,
      )
      .length;

  double get winRate => completedCount == 0 ? 0 : solvedCount / completedCount;

  double get averageAttempts {
    final scored = resultsByDay.values
        .where((record) => record.won && !record.legacy)
        .toList();
    if (scored.isEmpty) return 0;
    final total = scored.fold<int>(
      0,
      (sum, record) => sum + (7 - record.attemptsRemaining),
    );
    return total / scored.length;
  }

  int solveStreak(String currentDayKey) {
    final parsed = DateTime.tryParse(currentDayKey);
    if (parsed == null) return 0;
    var cursor = parsed;
    final todayRecord = resultsByDay[currentDayKey];
    if (todayRecord == null || !todayRecord.effectiveWon) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (true) {
      final key = guessPlayerDayKey(cursor);
      if (!(resultsByDay[key]?.effectiveWon ?? false)) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': GuessPlayerDayRecord.schemaVersion,
    'resultsByDay': resultsByDay.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };
}

String guessPlayerDayKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
