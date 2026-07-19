import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final GrandSlamCard targetGrandSlam;
  final int remainingHearts;
  final List<String> guesses;
  final int hintsRevealed;
  final GuessWinnerGameState gameState;
  final GuessWinnerArchive archive;
  final String todayKey;
  final List<String> unlockedDayKeys;

  GuessWinnerState copyWith({
    GrandSlamCard? targetGrandSlam,
    int? remainingHearts,
    List<String>? guesses,
    int? hintsRevealed,
    GuessWinnerGameState? gameState,
    GuessWinnerArchive? archive,
    String? todayKey,
    List<String>? unlockedDayKeys,
  }) {
    return GuessWinnerState(
      targetGrandSlam: targetGrandSlam ?? this.targetGrandSlam,
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

class GuessWinnerCubit extends Cubit<GuessWinnerState> {
  GuessWinnerCubit({
    required this.grandSlams,
    required this.allPlayers,
    required this.storage,
  }) : super(_initialState(allPlayers, grandSlams));

  final List<GrandSlamCard> grandSlams;
  final List<String> allPlayers;
  final SecureGameStorage storage;

  static const int maxHearts = 10;

  static String _getTodayKey() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  static GuessWinnerState _initialState(
    List<String> players,
    List<GrandSlamCard> grandSlams,
  ) {
    final todayKey = _getTodayKey();
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
      unlockedDayKeys: const [],
    );
  }

  Future<void> load() async {
    final archive = await storage.loadTennisGuessWinnerArchive() ??
        const GuessWinnerArchive();

    final keys = archive.resultsByDay.keys.toSet();
    keys.add(state.todayKey);
    final sortedKeys = keys.toList()..sort();

    final todayResult = archive.resultsByDay[state.todayKey];
    GuessWinnerGameState currentState = GuessWinnerGameState.playing;
    int currentHearts = maxHearts;
    if (todayResult != null) {
      currentState = todayResult.won
          ? GuessWinnerGameState.won
          : GuessWinnerGameState.lost;
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
    final target = grandSlams[random.nextInt(grandSlams.length)];

    final result = state.archive.resultsByDay[dayKey];

    emit(
      state.copyWith(
        targetGrandSlam: target,
        todayKey: dayKey,
        gameState: result != null
            ? (result.won
                  ? GuessWinnerGameState.won
                  : GuessWinnerGameState.lost)
            : GuessWinnerGameState.playing,
        remainingHearts: result?.heartsRemaining ?? maxHearts,
        guesses: const [],
        hintsRevealed: maxHearts - (result?.heartsRemaining ?? maxHearts),
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
    } else {
      final newHearts = state.remainingHearts - 1;
      final newHints = state.hintsRevealed + 1;

      emit(
        state.copyWith(
          guesses: [...state.guesses, guessPlayerName],
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
        gameState: won ? GuessWinnerGameState.won : GuessWinnerGameState.lost,
        remainingHearts: heartsRemaining,
      ),
    );

    final newResult = GuessWinnerDailyResult(
      won: won,
      heartsRemaining: heartsRemaining,
      targetWinnerName: state.targetGrandSlam.winnerName,
    );

    final updatedMap = Map<String, GuessWinnerDailyResult>.from(
      state.archive.resultsByDay,
    );
    updatedMap[state.todayKey] = newResult;

    final newArchive = GuessWinnerArchive(resultsByDay: updatedMap);
    emit(state.copyWith(archive: newArchive));
    storage.saveTennisGuessWinnerArchive(newArchive);
  }
}
