import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/daily_mystery.dart';
import '../../models/guess_winner.dart';
import '../../services/secure_storage_service.dart';

enum GuessWinnerGameState { playing, won, lost }

class GuessWinnerState {
  const GuessWinnerState({
    required this.targetGrandSlam,
    required this.remainingHearts,
    required this.guesses,
    required this.hintsRevealed,
    required this.gameState,
    required this.archive,
    required this.todayKey,
    required this.unlockedDayKeys,
    String? activeDayKey,
    this.viewMode = DailyMysteryViewMode.home,
    this.loadStatus = DailyMysteryLoadStatus.loading,
    this.errorMessage,
    this.freshResult = false,
  }) : activeDayKey = activeDayKey ?? todayKey;

  final GrandSlamCard targetGrandSlam;
  final int remainingHearts;
  final List<String> guesses;
  final int hintsRevealed;
  final GuessWinnerGameState gameState;
  final GuessWinnerArchive archive;
  final String todayKey;
  final String activeDayKey;
  final List<String> unlockedDayKeys;
  final DailyMysteryViewMode viewMode;
  final DailyMysteryLoadStatus loadStatus;
  final String? errorMessage;
  final bool freshResult;

  GuessWinnerState copyWith({
    GrandSlamCard? targetGrandSlam,
    int? remainingHearts,
    List<String>? guesses,
    int? hintsRevealed,
    GuessWinnerGameState? gameState,
    GuessWinnerArchive? archive,
    String? todayKey,
    String? activeDayKey,
    List<String>? unlockedDayKeys,
    DailyMysteryViewMode? viewMode,
    DailyMysteryLoadStatus? loadStatus,
    String? errorMessage,
    bool clearError = false,
    bool? freshResult,
  }) {
    return GuessWinnerState(
      targetGrandSlam: targetGrandSlam ?? this.targetGrandSlam,
      remainingHearts: remainingHearts ?? this.remainingHearts,
      guesses: guesses ?? this.guesses,
      hintsRevealed: hintsRevealed ?? this.hintsRevealed,
      gameState: gameState ?? this.gameState,
      archive: archive ?? this.archive,
      todayKey: todayKey ?? this.todayKey,
      activeDayKey: activeDayKey ?? this.activeDayKey,
      unlockedDayKeys: unlockedDayKeys ?? this.unlockedDayKeys,
      viewMode: viewMode ?? this.viewMode,
      loadStatus: loadStatus ?? this.loadStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      freshResult: freshResult ?? this.freshResult,
    );
  }
}

class GuessWinnerCubit extends Cubit<GuessWinnerState> {
  GuessWinnerCubit({
    required this.grandSlams,
    required this.allPlayers,
    required this.storage,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(_initialState(grandSlams, (now ?? DateTime.now)()));

  final List<GrandSlamCard> grandSlams;
  final List<String> allPlayers;
  final SecureGameStorage storage;
  final DateTime Function() now;

  static const int maxHearts = 10;
  static const int archiveWindowDays = 30;

  static GuessWinnerState _initialState(
    List<GrandSlamCard> grandSlams,
    DateTime now,
  ) {
    final todayKey = dailyMysteryDayKey(now);
    final random = Random(todayKey.hashCode);
    final target = grandSlams[random.nextInt(grandSlams.length)];
    return GuessWinnerState(
      targetGrandSlam: target,
      remainingHearts: maxHearts,
      guesses: const [],
      hintsRevealed: 0,
      gameState: GuessWinnerGameState.playing,
      archive: const GuessWinnerArchive(),
      todayKey: todayKey,
      activeDayKey: todayKey,
      unlockedDayKeys: const [],
    );
  }

  GrandSlamCard targetForDay(String dayKey) {
    final random = Random(dayKey.hashCode);
    return grandSlams[random.nextInt(grandSlams.length)];
  }

  Future<void> load() async {
    emit(
      state.copyWith(
        loadStatus: DailyMysteryLoadStatus.loading,
        clearError: true,
        freshResult: false,
      ),
    );
    try {
      final todayKey = dailyMysteryDayKey(now());
      final archive =
          await storage.loadTennisGuessWinnerArchive() ??
          const GuessWinnerArchive();
      final keys = {...archive.resultsByDay.keys, todayKey}.toList()..sort();
      final todayResult = archive.resultsByDay[todayKey];
      emit(
        state.copyWith(
          targetGrandSlam: targetForDay(todayKey),
          remainingHearts: todayResult?.heartsRemaining ?? maxHearts,
          guesses: const [],
          hintsRevealed:
              maxHearts - (todayResult?.heartsRemaining ?? maxHearts),
          gameState: todayResult == null
              ? GuessWinnerGameState.playing
              : todayResult.won
              ? GuessWinnerGameState.won
              : GuessWinnerGameState.lost,
          archive: archive,
          todayKey: todayKey,
          activeDayKey: todayKey,
          unlockedDayKeys: keys,
          viewMode: DailyMysteryViewMode.home,
          loadStatus: DailyMysteryLoadStatus.ready,
          clearError: true,
          freshResult: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loadStatus: DailyMysteryLoadStatus.error,
          errorMessage: error.toString(),
          freshResult: false,
        ),
      );
    }
  }

  Future<void> refreshForCurrentDay() async {
    if (dailyMysteryDayKey(now()) != state.todayKey) {
      await load();
    }
  }

  Future<void> openToday() async {
    await refreshForCurrentDay();
    if (state.loadStatus != DailyMysteryLoadStatus.ready) return;
    final result = state.archive.resultsByDay[state.todayKey];
    final canResume =
        result == null &&
        state.activeDayKey == state.todayKey &&
        state.gameState == GuessWinnerGameState.playing;
    emit(
      state.copyWith(
        targetGrandSlam: targetForDay(state.todayKey),
        activeDayKey: state.todayKey,
        remainingHearts:
            result?.heartsRemaining ??
            (canResume ? state.remainingHearts : maxHearts),
        guesses: result == null && canResume ? state.guesses : const [],
        hintsRevealed: result == null && canResume
            ? state.hintsRevealed
            : maxHearts - (result?.heartsRemaining ?? maxHearts),
        gameState: result == null
            ? GuessWinnerGameState.playing
            : result.won
            ? GuessWinnerGameState.won
            : GuessWinnerGameState.lost,
        viewMode: result == null
            ? DailyMysteryViewMode.play
            : DailyMysteryViewMode.review,
        clearError: true,
        freshResult: false,
      ),
    );
  }

  Future<void> openDay(String dayKey) async {
    if (dayKey == state.todayKey) {
      await openToday();
      return;
    }
    final result = state.archive.resultsByDay[dayKey];
    if (result == null) return;
    emit(
      state.copyWith(
        targetGrandSlam: targetForDay(dayKey),
        activeDayKey: dayKey,
        remainingHearts: result.heartsRemaining,
        guesses: const [],
        hintsRevealed: maxHearts - result.heartsRemaining,
        gameState: result.won
            ? GuessWinnerGameState.won
            : GuessWinnerGameState.lost,
        viewMode: DailyMysteryViewMode.review,
        clearError: true,
        freshResult: false,
      ),
    );
  }

  void showHome() {
    emit(
      state.copyWith(
        viewMode: DailyMysteryViewMode.home,
        clearError: true,
        freshResult: false,
      ),
    );
  }

  void showLogs() {
    emit(
      state.copyWith(
        viewMode: DailyMysteryViewMode.logs,
        clearError: true,
        freshResult: false,
      ),
    );
  }

  void skip() {
    if (state.gameState != GuessWinnerGameState.playing) return;
    _finishGame(false, 0);
  }

  void submitGuess(String guessPlayerName) {
    if (state.gameState != GuessWinnerGameState.playing) return;
    if (guessPlayerName.trim().toLowerCase() ==
        state.targetGrandSlam.winnerName.trim().toLowerCase()) {
      _finishGame(true, state.remainingHearts);
      emit(state.copyWith(guesses: [...state.guesses, guessPlayerName]));
      return;
    }

    final newHearts = state.remainingHearts - 1;
    emit(
      state.copyWith(
        guesses: [...state.guesses, guessPlayerName],
        remainingHearts: newHearts,
        hintsRevealed: state.hintsRevealed + 1,
      ),
    );
    if (newHearts <= 0) _finishGame(false, 0);
  }

  void _finishGame(bool won, int heartsRemaining) {
    final newResult = GuessWinnerDailyResult(
      won: won,
      heartsRemaining: heartsRemaining,
      targetWinnerName: state.targetGrandSlam.winnerName,
    );
    final archive = GuessWinnerArchive(
      resultsByDay: {
        ...state.archive.resultsByDay,
        state.activeDayKey: newResult,
      },
    );
    final keys = {...state.unlockedDayKeys, state.activeDayKey}.toList()
      ..sort();
    emit(
      state.copyWith(
        gameState: won ? GuessWinnerGameState.won : GuessWinnerGameState.lost,
        remainingHearts: heartsRemaining,
        archive: archive,
        unlockedDayKeys: keys,
        viewMode: DailyMysteryViewMode.review,
        freshResult: true,
      ),
    );
    storage.saveTennisGuessWinnerArchive(archive);
  }

  void consumeResultReveal() {
    if (state.freshResult) {
      emit(state.copyWith(freshResult: false));
    }
  }

  List<String> archiveDayKeys({int days = archiveWindowDays}) {
    final today = DateTime.tryParse(state.todayKey) ?? now();
    return [
      for (var index = 0; index < days; index++)
        dailyMysteryDayKey(today.subtract(Duration(days: index))),
    ];
  }
}
