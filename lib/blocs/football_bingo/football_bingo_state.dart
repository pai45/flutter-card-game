import '../../data/football_bingo_puzzles.dart';
import '../../models/cards.dart';
import '../../models/football_bingo.dart';

class FootballBingoState {
  const FootballBingoState({
    this.loading = true,
    required this.archive,
    required this.activeDayKey,
    required this.todayKey,
    required this.puzzle,
    required this.progress,
    this.lastAnswerCorrect,
    this.lastTappedCellId,
  });

  factory FootballBingoState.initial(DateTime now) {
    final todayKey = footballBingoDayKey(now);
    final puzzle = footballBingoPuzzles.first;
    final archive = FootballBingoArchive(
      firstUnlockDayKey: todayKey,
      progressByDay: {todayKey: FootballBingoProgress.initial(puzzle.id, now)},
    );
    return FootballBingoState(
      archive: archive,
      activeDayKey: todayKey,
      todayKey: todayKey,
      puzzle: puzzle,
      progress: archive.progressByDay[todayKey]!,
    );
  }

  final bool loading;
  final FootballBingoArchive archive;
  final String activeDayKey;
  final String todayKey;
  final FootballBingoPuzzle puzzle;
  final FootballBingoProgress progress;
  final bool? lastAnswerCorrect;
  final String? lastTappedCellId;

  bool get isToday => activeDayKey == todayKey;
  bool get readOnly => !isToday;
  bool get completed => progress.completed;
  bool get needsLifeline => isToday && !completed && progress.lifelines <= 0;
  Set<String> get solvedCellIds => progress.solvedCellIds.toSet();
  List<String> get unlockedDayKeys =>
      archive.progressByDay.keys.toList()..sort();
  int get completedCount => archive.progressByDay.values
      .where((progress) => progress.completed)
      .length;

  FootballBingoCell? get currentCell {
    if (completed || readOnly) return null;
    for (final cell in puzzle.cells) {
      if (!solvedCellIds.contains(cell.id)) return cell;
    }
    return null;
  }

  PlayerCard? get currentPlayer {
    final cell = currentCell;
    if (cell == null) return null;
    return allPlayerCards
        .where((player) => player.id == cell.playerId)
        .firstOrNull;
  }

  FootballBingoState copyWith({
    bool? loading,
    FootballBingoArchive? archive,
    String? activeDayKey,
    String? todayKey,
    FootballBingoPuzzle? puzzle,
    FootballBingoProgress? progress,
    Object? lastAnswerCorrect = _sentinel,
    Object? lastTappedCellId = _sentinel,
  }) => FootballBingoState(
    loading: loading ?? this.loading,
    archive: archive ?? this.archive,
    activeDayKey: activeDayKey ?? this.activeDayKey,
    todayKey: todayKey ?? this.todayKey,
    puzzle: puzzle ?? this.puzzle,
    progress: progress ?? this.progress,
    lastAnswerCorrect: lastAnswerCorrect == _sentinel
        ? this.lastAnswerCorrect
        : lastAnswerCorrect as bool?,
    lastTappedCellId: lastTappedCellId == _sentinel
        ? this.lastTappedCellId
        : lastTappedCellId as String?,
  );
}

const _sentinel = Object();
