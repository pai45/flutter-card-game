import 'cards.dart';

const int kFootballBingoGridSize = 3;
const int kFootballBingoStartingLifelines = 5;
const int kFootballBingoLifelineCost = 25;
const Duration kFootballBingoCooldown = Duration(hours: 24);

DateTime footballBingoDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String footballBingoDayKey(DateTime value) {
  final day = footballBingoDateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

DateTime? parseFootballBingoDayKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

int footballBingoDayIndex(String firstUnlockDayKey, String dayKey) {
  final first = parseFootballBingoDayKey(firstUnlockDayKey);
  final day = parseFootballBingoDayKey(dayKey);
  if (first == null || day == null) return 0;
  return day.difference(first).inDays.clamp(0, 100000);
}

List<String> footballBingoUnlockedDayKeys(
  String firstUnlockDayKey,
  DateTime now,
) {
  final first = parseFootballBingoDayKey(firstUnlockDayKey);
  if (first == null) return [footballBingoDayKey(now)];
  final today = footballBingoDateOnly(now);
  final count = today.difference(first).inDays.clamp(0, 100000);
  return [
    for (var offset = 0; offset <= count; offset++)
      footballBingoDayKey(first.add(Duration(days: offset))),
  ];
}

class FootballBingoAxis {
  const FootballBingoAxis({
    required this.id,
    required this.label,
    required this.shortLabel,
  });

  final String id;
  final String label;
  final String shortLabel;
}

class FootballBingoCell {
  const FootballBingoCell({
    required this.id,
    required this.rowId,
    required this.columnId,
    required this.playerId,
  });

  final String id;
  final String rowId;
  final String columnId;
  final String playerId;
}

class FootballBingoPuzzle {
  const FootballBingoPuzzle({
    required this.id,
    required this.title,
    required this.columns,
    required this.rows,
    required this.cells,
  });

  final String id;
  final String title;
  final List<FootballBingoAxis> columns;
  final List<FootballBingoAxis> rows;
  final List<FootballBingoCell> cells;

  FootballBingoCell cellAt(int row, int column) {
    final rowId = rows[row].id;
    final columnId = columns[column].id;
    return cells.firstWhere(
      (cell) => cell.rowId == rowId && cell.columnId == columnId,
    );
  }

  FootballBingoCell? cellForPlayer(String playerId) {
    for (final cell in cells) {
      if (cell.playerId == playerId) return cell;
    }
    return null;
  }
}

class FootballBingoProgress {
  const FootballBingoProgress({
    required this.puzzleId,
    required this.startedAt,
    required this.solvedCellIds,
    required this.currentIndex,
    required this.lifelines,
    required this.completed,
    required this.cellOrderIds,
  });

  factory FootballBingoProgress.initial(String puzzleId, DateTime now) =>
      FootballBingoProgress(
        puzzleId: puzzleId,
        startedAt: now,
        solvedCellIds: const [],
        currentIndex: 0,
        lifelines: kFootballBingoStartingLifelines,
        completed: false,
        cellOrderIds: const [],
      );

  factory FootballBingoProgress.fromJson(Map<String, dynamic> json) =>
      FootballBingoProgress(
        puzzleId: json['puzzleId'] as String? ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          json['startedAt'] as int? ?? 0,
        ),
        solvedCellIds: List<String>.from(
          json['solvedCellIds'] as List? ?? const [],
        ),
        currentIndex: json['currentIndex'] as int? ?? 0,
        lifelines: json['lifelines'] as int? ?? kFootballBingoStartingLifelines,
        completed: json['completed'] as bool? ?? false,
        cellOrderIds: List<String>.from(
          json['cellOrderIds'] as List? ?? const [],
        ),
      );

  final String puzzleId;
  final DateTime startedAt;
  final List<String> solvedCellIds;
  final int currentIndex;
  final int lifelines;
  final bool completed;
  final List<String> cellOrderIds;

  Map<String, dynamic> toJson() => {
    'puzzleId': puzzleId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'solvedCellIds': solvedCellIds,
    'currentIndex': currentIndex,
    'lifelines': lifelines,
    'completed': completed,
    'cellOrderIds': cellOrderIds,
  };

  FootballBingoProgress copyWith({
    String? puzzleId,
    DateTime? startedAt,
    List<String>? solvedCellIds,
    int? currentIndex,
    int? lifelines,
    bool? completed,
    List<String>? cellOrderIds,
  }) => FootballBingoProgress(
    puzzleId: puzzleId ?? this.puzzleId,
    startedAt: startedAt ?? this.startedAt,
    solvedCellIds: solvedCellIds ?? this.solvedCellIds,
    currentIndex: currentIndex ?? this.currentIndex,
    lifelines: lifelines ?? this.lifelines,
    completed: completed ?? this.completed,
    cellOrderIds: cellOrderIds ?? this.cellOrderIds,
  );
}

class FootballBingoArchive {
  const FootballBingoArchive({
    required this.firstUnlockDayKey,
    required this.progressByDay,
  });

  factory FootballBingoArchive.initial(DateTime now) {
    final dayKey = footballBingoDayKey(now);
    return FootballBingoArchive(
      firstUnlockDayKey: dayKey,
      progressByDay: {
        dayKey: FootballBingoProgress.initial('', footballBingoDateOnly(now)),
      },
    );
  }

  factory FootballBingoArchive.fromJson(Map<String, dynamic> json) {
    final rawProgress = Map<String, dynamic>.from(
      json['progressByDay'] as Map? ?? const {},
    );
    return FootballBingoArchive(
      firstUnlockDayKey: json['firstUnlockDayKey'] as String? ?? '',
      progressByDay: {
        for (final entry in rawProgress.entries)
          entry.key: FootballBingoProgress.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  final String firstUnlockDayKey;
  final Map<String, FootballBingoProgress> progressByDay;

  Map<String, dynamic> toJson() => {
    'firstUnlockDayKey': firstUnlockDayKey,
    'progressByDay': {
      for (final entry in progressByDay.entries)
        entry.key: entry.value.toJson(),
    },
  };

  FootballBingoArchive copyWith({
    String? firstUnlockDayKey,
    Map<String, FootballBingoProgress>? progressByDay,
  }) => FootballBingoArchive(
    firstUnlockDayKey: firstUnlockDayKey ?? this.firstUnlockDayKey,
    progressByDay: progressByDay ?? this.progressByDay,
  );
}

class FootballBingoValidationError {
  const FootballBingoValidationError(this.message);

  final String message;
}

List<FootballBingoValidationError> validateFootballBingoPuzzle(
  FootballBingoPuzzle puzzle,
  List<PlayerCard> players,
) {
  final errors = <FootballBingoValidationError>[];
  final playerIds = players.map((player) => player.id).toSet();
  final columnIds = puzzle.columns.map((axis) => axis.id).toSet();
  final rowIds = puzzle.rows.map((axis) => axis.id).toSet();
  final cellSlots = <String>{};
  final cellIds = <String>{};
  final playerIdsInPuzzle = <String>{};

  if (puzzle.columns.length != kFootballBingoGridSize) {
    errors.add(
      const FootballBingoValidationError('Puzzle must have 3 columns'),
    );
  }
  if (puzzle.rows.length != kFootballBingoGridSize) {
    errors.add(const FootballBingoValidationError('Puzzle must have 3 rows'));
  }
  if (puzzle.cells.length != kFootballBingoGridSize * kFootballBingoGridSize) {
    errors.add(const FootballBingoValidationError('Puzzle must have 9 cells'));
  }

  for (final cell in puzzle.cells) {
    final cellKey = '${cell.rowId}:${cell.columnId}';
    if (!cellSlots.add(cellKey)) {
      errors.add(
        FootballBingoValidationError(
          'Duplicate cell for ${cell.rowId}/${cell.columnId}',
        ),
      );
    }
    if (!cellIds.add(cell.id)) {
      errors.add(FootballBingoValidationError('Duplicate cell id ${cell.id}'));
    }
    if (!playerIdsInPuzzle.add(cell.playerId)) {
      errors.add(
        FootballBingoValidationError('Duplicate player ${cell.playerId}'),
      );
    }
    if (!rowIds.contains(cell.rowId)) {
      errors.add(FootballBingoValidationError('Unknown row ${cell.rowId}'));
    }
    if (!columnIds.contains(cell.columnId)) {
      errors.add(
        FootballBingoValidationError('Unknown column ${cell.columnId}'),
      );
    }
    final player = players
        .where((candidate) => candidate.id == cell.playerId)
        .firstOrNull;
    if (!playerIds.contains(cell.playerId) || player == null) {
      errors.add(
        FootballBingoValidationError('Unknown player ${cell.playerId}'),
      );
    }
  }

  return errors;
}

class FootballBingoStatus {
  const FootballBingoStatus(this.ready, this.remaining);

  final bool ready;
  final Duration remaining;
}

FootballBingoStatus footballBingoStatus(
  FootballBingoProgress progress, [
  DateTime? now,
]) {
  final currentTime = now ?? DateTime.now();
  final tomorrowMidnight = DateTime(
    currentTime.year,
    currentTime.month,
    currentTime.day + 1,
  );
  final remaining = tomorrowMidnight.difference(currentTime);
  if (remaining <= Duration.zero) {
    return const FootballBingoStatus(true, Duration.zero);
  }
  return FootballBingoStatus(false, remaining);
}

String formatFootballBingoCountdown(Duration duration) {
  final totalMinutes =
      duration.inMinutes + (duration.inSeconds % 60 > 0 ? 1 : 0);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours <= 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}
