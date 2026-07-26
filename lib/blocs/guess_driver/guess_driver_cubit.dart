import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/daily_mystery.dart';
import '../../models/guess_driver.dart';
import '../../services/secure_storage_service.dart';

enum GuessDriverGameState { playing, won, lost }

class GuessDriverState {
  const GuessDriverState({
    required this.targetRace,
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

  final F1RaceCard targetRace;
  final int remainingHearts;
  final List<String> guesses;
  final int hintsRevealed;
  final GuessDriverGameState gameState;
  final GuessDriverArchive archive;
  final String todayKey;
  final String activeDayKey;
  final List<String> unlockedDayKeys;
  final DailyMysteryViewMode viewMode;
  final DailyMysteryLoadStatus loadStatus;
  final String? errorMessage;
  final bool freshResult;

  GuessDriverState copyWith({
    F1RaceCard? targetRace,
    int? remainingHearts,
    List<String>? guesses,
    int? hintsRevealed,
    GuessDriverGameState? gameState,
    GuessDriverArchive? archive,
    String? todayKey,
    String? activeDayKey,
    List<String>? unlockedDayKeys,
    DailyMysteryViewMode? viewMode,
    DailyMysteryLoadStatus? loadStatus,
    String? errorMessage,
    bool clearError = false,
    bool? freshResult,
  }) {
    return GuessDriverState(
      targetRace: targetRace ?? this.targetRace,
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

class GuessDriverCubit extends Cubit<GuessDriverState> {
  GuessDriverCubit({
    required this.races,
    required this.allDrivers,
    required this.storage,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       super(_initialState(races, (now ?? DateTime.now)()));

  final List<F1RaceCard> races;
  final List<String> allDrivers;
  final SecureGameStorage storage;
  final DateTime Function() now;

  static const int maxHearts = 10;
  static const int archiveWindowDays = 30;

  static GuessDriverState _initialState(List<F1RaceCard> races, DateTime now) {
    final todayKey = dailyMysteryDayKey(now);
    final random = Random(todayKey.hashCode);
    final target = races[random.nextInt(races.length)];
    return GuessDriverState(
      targetRace: target,
      remainingHearts: maxHearts,
      guesses: const [],
      hintsRevealed: 0,
      gameState: GuessDriverGameState.playing,
      archive: const GuessDriverArchive(),
      todayKey: todayKey,
      activeDayKey: todayKey,
      unlockedDayKeys: const [],
    );
  }

  F1RaceCard targetForDay(String dayKey) {
    final random = Random(dayKey.hashCode);
    return races[random.nextInt(races.length)];
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
          await storage.loadGuessDriverArchive() ?? const GuessDriverArchive();
      final keys = {...archive.resultsByDay.keys, todayKey}.toList()..sort();
      final todayResult = archive.resultsByDay[todayKey];
      emit(
        state.copyWith(
          targetRace: targetForDay(todayKey),
          remainingHearts: todayResult?.heartsRemaining ?? maxHearts,
          guesses: const [],
          hintsRevealed:
              maxHearts - (todayResult?.heartsRemaining ?? maxHearts),
          gameState: todayResult == null
              ? GuessDriverGameState.playing
              : todayResult.won
              ? GuessDriverGameState.won
              : GuessDriverGameState.lost,
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
        state.gameState == GuessDriverGameState.playing;
    emit(
      state.copyWith(
        targetRace: targetForDay(state.todayKey),
        activeDayKey: state.todayKey,
        remainingHearts:
            result?.heartsRemaining ??
            (canResume ? state.remainingHearts : maxHearts),
        guesses: result == null && canResume ? state.guesses : const [],
        hintsRevealed: result == null && canResume
            ? state.hintsRevealed
            : maxHearts - (result?.heartsRemaining ?? maxHearts),
        gameState: result == null
            ? GuessDriverGameState.playing
            : result.won
            ? GuessDriverGameState.won
            : GuessDriverGameState.lost,
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
        targetRace: targetForDay(dayKey),
        activeDayKey: dayKey,
        remainingHearts: result.heartsRemaining,
        guesses: const [],
        hintsRevealed: maxHearts - result.heartsRemaining,
        gameState: result.won
            ? GuessDriverGameState.won
            : GuessDriverGameState.lost,
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
    if (state.gameState != GuessDriverGameState.playing) return;
    _finishGame(false, 0);
  }

  void submitGuess(String guessDriverName) {
    if (state.gameState != GuessDriverGameState.playing) return;
    if (guessDriverName.trim().toLowerCase() ==
        state.targetRace.driverName.trim().toLowerCase()) {
      _finishGame(true, state.remainingHearts);
      emit(state.copyWith(guesses: [...state.guesses, guessDriverName]));
      return;
    }

    final newHearts = state.remainingHearts - 1;
    emit(
      state.copyWith(
        guesses: [...state.guesses, guessDriverName],
        remainingHearts: newHearts,
        hintsRevealed: state.hintsRevealed + 1,
      ),
    );
    if (newHearts <= 0) _finishGame(false, 0);
  }

  void _finishGame(bool won, int heartsRemaining) {
    final newResult = GuessDriverDailyResult(
      won: won,
      heartsRemaining: heartsRemaining,
      targetDriverName: state.targetRace.driverName,
    );
    final archive = GuessDriverArchive(
      resultsByDay: {
        ...state.archive.resultsByDay,
        state.activeDayKey: newResult,
      },
    );
    final keys = {...state.unlockedDayKeys, state.activeDayKey}.toList()
      ..sort();
    emit(
      state.copyWith(
        gameState: won ? GuessDriverGameState.won : GuessDriverGameState.lost,
        remainingHearts: heartsRemaining,
        archive: archive,
        unlockedDayKeys: keys,
        viewMode: DailyMysteryViewMode.review,
        freshResult: true,
      ),
    );
    storage.saveGuessDriverArchive(archive);
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
