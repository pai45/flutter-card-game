import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final F1RaceCard targetRace;
  final int remainingHearts;
  final List<String> guesses;
  final int hintsRevealed;
  final GuessDriverGameState gameState;
  final GuessDriverArchive archive;
  final String todayKey;
  final List<String> unlockedDayKeys;

  GuessDriverState copyWith({
    F1RaceCard? targetRace,
    int? remainingHearts,
    List<String>? guesses,
    int? hintsRevealed,
    GuessDriverGameState? gameState,
    GuessDriverArchive? archive,
    String? todayKey,
    List<String>? unlockedDayKeys,
  }) {
    return GuessDriverState(
      targetRace: targetRace ?? this.targetRace,
      remainingHearts: remainingHearts ?? this.remainingHearts,
      guesses: guesses ?? this.guesses,
      hintsRevealed: hintsRevealed ?? this.hintsRevealed,
      gameState: gameState ?? this.gameState,
      archive: archive ?? this.archive,
      todayKey: todayKey ?? this.todayKey,
      unlockedDayKeys: unlockedDayKeys ?? this.unlockedDayKeys,
    );
  }
}

class GuessDriverCubit extends Cubit<GuessDriverState> {
  GuessDriverCubit({
    required this.races,
    required this.allDrivers,
    required this.storage,
  }) : super(_initialState(allDrivers, races));

  final List<F1RaceCard> races;
  final List<String> allDrivers;
  final SecureGameStorage storage;

  static const int maxHearts = 10;

  static String _getTodayKey() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  static GuessDriverState _initialState(
    List<String> drivers,
    List<F1RaceCard> races,
  ) {
    // Pick a deterministic race for today based on the date string
    final todayKey = _getTodayKey();
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
      unlockedDayKeys: const [],
    );
  }

  Future<void> load() async {
    final archive =
        await storage.loadGuessDriverArchive() ?? const GuessDriverArchive();

    // We unlock days based on the archive, plus today.
    final keys = archive.resultsByDay.keys.toSet();
    keys.add(state.todayKey);
    final sortedKeys = keys.toList()..sort();

    // Check if today was already played
    final todayResult = archive.resultsByDay[state.todayKey];
    GuessDriverGameState currentState = GuessDriverGameState.playing;
    int currentHearts = maxHearts;
    if (todayResult != null) {
      currentState = todayResult.won
          ? GuessDriverGameState.won
          : GuessDriverGameState.lost;
      currentHearts = todayResult.heartsRemaining;
    }

    emit(
      state.copyWith(
        archive: archive,
        unlockedDayKeys: sortedKeys,
        gameState: currentState,
        remainingHearts: currentHearts,
      ),
    );
  }

  Future<void> openDay(String dayKey) async {
    final random = Random(dayKey.hashCode);
    final target = races[random.nextInt(races.length)];

    final result = state.archive.resultsByDay[dayKey];

    emit(
      state.copyWith(
        targetRace: target,
        todayKey: dayKey, // We use todayKey as the "active" day key
        gameState: result != null
            ? (result.won
                  ? GuessDriverGameState.won
                  : GuessDriverGameState.lost)
            : GuessDriverGameState.playing,
        remainingHearts: result?.heartsRemaining ?? maxHearts,
        guesses: const [], // We don't save guesses in archive for simplicity
        hintsRevealed:
            maxHearts -
            (result?.heartsRemaining ?? maxHearts), // Estimate hints based on lost hearts
      ),
    );
  }

  void skip() {
    if (state.gameState != GuessDriverGameState.playing) return;
    _finishGame(false, 0);
  }

  void submitGuess(String guessDriverName) {
    if (state.gameState != GuessDriverGameState.playing) return;

    if (guessDriverName.trim().toLowerCase() == state.targetRace.driverName.trim().toLowerCase()) {
      // Won
      _finishGame(true, state.remainingHearts);
      emit(state.copyWith(guesses: [...state.guesses, guessDriverName]));
    } else {
      // Wrong guess
      final newHearts = state.remainingHearts - 1;
      final newHints = state.hintsRevealed + 1;

      emit(
        state.copyWith(
          guesses: [...state.guesses, guessDriverName],
          remainingHearts: newHearts,
          hintsRevealed: newHints,
        ),
      );

      if (newHearts <= 0) {
        _finishGame(false, 0);
      }
    }
  }

  void _finishGame(bool won, int heartsRemaining) {
    emit(
      state.copyWith(
        gameState: won ? GuessDriverGameState.won : GuessDriverGameState.lost,
        remainingHearts: heartsRemaining,
      ),
    );

    final newResult = GuessDriverDailyResult(
      won: won,
      heartsRemaining: heartsRemaining,
      targetDriverName: state.targetRace.driverName,
    );

    final updatedMap = Map<String, GuessDriverDailyResult>.from(
      state.archive.resultsByDay,
    );
    updatedMap[state.todayKey] = newResult;

    final newArchive = GuessDriverArchive(resultsByDay: updatedMap);
    emit(state.copyWith(archive: newArchive));
    storage.saveGuessDriverArchive(newArchive);
  }
}
