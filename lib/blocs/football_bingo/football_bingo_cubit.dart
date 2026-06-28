import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/football_bingo_puzzles.dart';
import '../../models/football_bingo.dart';
import '../../services/secure_storage_service.dart';
import 'football_bingo_state.dart';

class FootballBingoCubit extends Cubit<FootballBingoState> {
  FootballBingoCubit(this._storage)
    : super(FootballBingoState.initial(DateTime.now()));

  final SecureGameStorage _storage;

  Future<void> load({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final archive = await _loadArchive(current);
    final todayKey = footballBingoDayKey(current);
    final hydrated = _withUnlockedDays(archive, current);
    final progress = hydrated.progressByDay[todayKey]!;
    emit(
      FootballBingoState(
        loading: false,
        archive: hydrated,
        activeDayKey: todayKey,
        todayKey: todayKey,
        puzzle: footballBingoPuzzleFor(progress.puzzleId),
        progress: progress,
      ),
    );
    await _storage.saveFootballBingoArchive(hydrated);
  }

  Future<void> openDay(String dayKey, {DateTime? now}) async {
    final current = now ?? DateTime.now();
    final archive = _withUnlockedDays(state.archive, current);
    final progress = archive.progressByDay[dayKey];
    if (progress == null) return;
    emit(
      state.copyWith(
        archive: archive,
        activeDayKey: dayKey,
        todayKey: footballBingoDayKey(current),
        puzzle: footballBingoPuzzleFor(progress.puzzleId),
        progress: progress,
        lastAnswerCorrect: null,
        lastTappedCellId: null,
      ),
    );
    await _storage.saveFootballBingoArchive(archive);
  }

  Future<bool> selectCell(String cellId) async {
    if (state.loading ||
        state.readOnly ||
        state.completed ||
        state.needsLifeline) {
      return false;
    }
    final current = state.currentCell;
    if (current == null) return false;

    if (cellId == current.id) {
      final solved = {...state.progress.solvedCellIds, cellId}.toList();
      final completed = solved.length >= state.puzzle.cells.length;
      final progress = state.progress.copyWith(
        solvedCellIds: solved,
        currentIndex: solved.length,
        completed: completed,
      );
      await _saveActiveProgress(
        progress,
        lastAnswerCorrect: true,
        lastTappedCellId: cellId,
      );
      return true;
    }

    final progress = state.progress.copyWith(
      lifelines: (state.progress.lifelines - 1).clamp(0, 99),
    );
    await _saveActiveProgress(
      progress,
      lastAnswerCorrect: false,
      lastTappedCellId: cellId,
    );
    return false;
  }

  Future<bool> buyLifeline(int coinBalance) async {
    if (state.readOnly ||
        !state.needsLifeline ||
        coinBalance < kFootballBingoLifelineCost) {
      return false;
    }
    final progress = state.progress.copyWith(lifelines: 1);
    await _saveActiveProgress(
      progress,
      lastAnswerCorrect: null,
      lastTappedCellId: null,
    );
    return true;
  }

  Future<void> _saveActiveProgress(
    FootballBingoProgress progress, {
    required bool? lastAnswerCorrect,
    required String? lastTappedCellId,
  }) async {
    final archive = state.archive.copyWith(
      progressByDay: {
        ...state.archive.progressByDay,
        state.activeDayKey: progress,
      },
    );
    emit(
      state.copyWith(
        archive: archive,
        progress: progress,
        lastAnswerCorrect: lastAnswerCorrect,
        lastTappedCellId: lastTappedCellId,
      ),
    );
    await _storage.saveFootballBingoArchive(archive);
  }

  Future<FootballBingoArchive> _loadArchive(DateTime now) async {
    final archive = await _storage.loadFootballBingoArchive();
    if (archive != null && archive.firstUnlockDayKey.isNotEmpty) {
      return archive;
    }

    final legacy = await _storage.loadFootballBingoProgress();
    if (legacy != null && legacy.puzzleId.isNotEmpty) {
      final legacyDayKey = footballBingoDayKey(legacy.startedAt);
      return FootballBingoArchive(
        firstUnlockDayKey: legacyDayKey,
        progressByDay: {legacyDayKey: _safeProgress(legacy, legacyDayKey)},
      );
    }

    final todayKey = footballBingoDayKey(now);
    return FootballBingoArchive(
      firstUnlockDayKey: todayKey,
      progressByDay: {todayKey: _newProgressForDay(todayKey, todayKey)},
    );
  }

  FootballBingoArchive _withUnlockedDays(
    FootballBingoArchive archive,
    DateTime now,
  ) {
    final todayKey = footballBingoDayKey(now);
    final firstKey = archive.firstUnlockDayKey.isEmpty
        ? todayKey
        : archive.firstUnlockDayKey;
    final progressByDay = Map<String, FootballBingoProgress>.from(
      archive.progressByDay,
    );
    for (final dayKey in footballBingoUnlockedDayKeys(firstKey, now)) {
      progressByDay.putIfAbsent(
        dayKey,
        () => _newProgressForDay(firstKey, dayKey),
      );
    }
    return FootballBingoArchive(
      firstUnlockDayKey: firstKey,
      progressByDay: {
        for (final entry in progressByDay.entries)
          entry.key: _safeProgress(entry.value, entry.key, firstKey: firstKey),
      },
    );
  }

  FootballBingoProgress _newProgressForDay(
    String firstUnlockDayKey,
    String dayKey,
  ) {
    final puzzle = footballBingoPuzzleForDayIndex(
      footballBingoDayIndex(firstUnlockDayKey, dayKey),
    );
    return FootballBingoProgress.initial(
      puzzle.id,
      parseFootballBingoDayKey(dayKey) ?? DateTime.now(),
    ).copyWith(cellOrderIds: _cellOrderFor(puzzle, dayKey));
  }

  FootballBingoProgress _safeProgress(
    FootballBingoProgress progress,
    String dayKey, {
    String? firstKey,
  }) {
    final fallback = firstKey == null
        ? footballBingoPuzzleFor(progress.puzzleId)
        : footballBingoPuzzleForDayIndex(
            footballBingoDayIndex(firstKey, dayKey),
          );
    final puzzle = footballBingoPuzzleFor(progress.puzzleId);
    final resolvedPuzzle = progress.puzzleId.isEmpty ? fallback : puzzle;
    final safeSolved = progress.solvedCellIds
        .where((id) => resolvedPuzzle.cells.any((cell) => cell.id == id))
        .toList();
    final safeOrder = _safeCellOrder(progress, resolvedPuzzle, dayKey);
    return progress.copyWith(
      puzzleId: resolvedPuzzle.id,
      startedAt: parseFootballBingoDayKey(dayKey) ?? progress.startedAt,
      solvedCellIds: safeSolved,
      currentIndex: safeSolved.length,
      lifelines: progress.lifelines.clamp(0, 99),
      completed: safeSolved.length == resolvedPuzzle.cells.length,
      cellOrderIds: safeOrder,
    );
  }

  List<String> _safeCellOrder(
    FootballBingoProgress progress,
    FootballBingoPuzzle puzzle,
    String dayKey,
  ) {
    final cellIds = puzzle.cells.map((cell) => cell.id).toSet();
    final seen = <String>{};
    final order = progress.cellOrderIds
        .where((id) => cellIds.contains(id) && seen.add(id))
        .toList();
    if (order.toSet().length == cellIds.length &&
        order.length == cellIds.length) {
      return order;
    }
    final missing = cellIds.difference(order.toSet()).toList();
    return [...order, ..._cellOrderFor(puzzle, dayKey).where(missing.contains)];
  }

  List<String> _cellOrderFor(FootballBingoPuzzle puzzle, String dayKey) {
    final ids = puzzle.cells.map((cell) => cell.id).toList();
    ids.shuffle(Random(_stableSeed('${puzzle.id}:$dayKey')));
    return ids;
  }

  int _stableSeed(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
