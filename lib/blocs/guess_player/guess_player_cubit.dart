import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/sport_match.dart';
import '../../data/guess_player_data.dart';
import '../../models/cards.dart';
import '../../models/guess_player.dart';
import '../../services/secure_storage_service.dart';

enum GuessPlayerGameState { playing, won, lost }

class GuessPlayerState {
  const GuessPlayerState({
    required this.targetPlayer,
    required this.timeline,
    required this.remainingHearts,
    required this.guesses,
    required this.hintsRevealed,
    required this.gameState,
    required this.archive,
    required this.todayKey,
    required this.unlockedDayKeys,
  });

  final PlayerCard targetPlayer;
  final GuessPlayerTimeline timeline;
  final int remainingHearts;
  final List<PlayerCard> guesses;
  final int hintsRevealed;
  final GuessPlayerGameState gameState;
  final GuessPlayerArchive archive;
  final String todayKey;
  final List<String> unlockedDayKeys;

  GuessPlayerState copyWith({
    PlayerCard? targetPlayer,
    GuessPlayerTimeline? timeline,
    int? remainingHearts,
    List<PlayerCard>? guesses,
    int? hintsRevealed,
    GuessPlayerGameState? gameState,
    GuessPlayerArchive? archive,
    String? todayKey,
    List<String>? unlockedDayKeys,
  }) {
    return GuessPlayerState(
      targetPlayer: targetPlayer ?? this.targetPlayer,
      timeline: timeline ?? this.timeline,
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

class GuessPlayerCubit extends Cubit<GuessPlayerState> {
  GuessPlayerCubit({
    required this.sport,
    required this.timelines,
    required this.allPlayers,
    required this.storage,
  }) : super(_initialState(allPlayers, timelines));

  final Sport sport;
  final List<GuessPlayerTimeline> timelines;
  final List<PlayerCard> allPlayers;
  final SecureGameStorage storage;

  static const int maxHearts = 10;

  static String _getTodayKey() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  static GuessPlayerState _initialState(
    List<PlayerCard> players,
    List<GuessPlayerTimeline> timelines,
  ) {
    // Pick a deterministic player for today based on the date string
    final todayKey = _getTodayKey();
    final random = Random(todayKey.hashCode);
    final timeline = timelines[random.nextInt(timelines.length)];

    final target = players.firstWhere(
      (p) => p.name == timeline.playerName,
      orElse: () => players.first,
    );

    return GuessPlayerState(
      targetPlayer: target,
      timeline: timeline,
      remainingHearts: maxHearts,
      guesses: const [],
      hintsRevealed: 0,
      gameState: GuessPlayerGameState.playing,
      archive: const GuessPlayerArchive(),
      todayKey: todayKey,
      unlockedDayKeys: const [],
    );
  }

  Future<void> load() async {
    final archive =
        await storage.loadGuessPlayerArchive(sport) ?? const GuessPlayerArchive();

    // We unlock days based on the archive, plus today.
    // In a real app we'd have a backend schedule, but here we just show today and any past played days.
    final keys = archive.resultsByDay.keys.toSet();
    keys.add(state.todayKey);
    final sortedKeys = keys.toList()..sort();

    // Check if today was already played
    final todayResult = archive.resultsByDay[state.todayKey];
    GuessPlayerGameState currentState = GuessPlayerGameState.playing;
    int currentHearts = maxHearts;
    if (todayResult != null) {
      currentState = todayResult.won
          ? GuessPlayerGameState.won
          : GuessPlayerGameState.lost;
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

  // Opens a specific day for viewing (can't play past days in this simple logic, just view result)
  Future<void> openDay(String dayKey) async {
    final random = Random(dayKey.hashCode);
    final timeline = timelines[random.nextInt(timelines.length)];

    final target = allPlayers.firstWhere(
      (p) => p.name == timeline.playerName,
      orElse: () => allPlayers.first,
    );

    final result = state.archive.resultsByDay[dayKey];

    emit(
      state.copyWith(
        targetPlayer: target,
        timeline: timeline,
        todayKey: dayKey, // We use todayKey as the "active" day key
        gameState: result != null
            ? (result.won
                  ? GuessPlayerGameState.won
                  : GuessPlayerGameState.lost)
            : GuessPlayerGameState.playing,
        remainingHearts: result?.heartsRemaining ?? maxHearts,
        guesses: const [], // We don't save guesses in archive for simplicity
        hintsRevealed:
            maxHearts -
            (result?.heartsRemaining ??
                maxHearts), // Just estimate hints based on lost hearts
      ),
    );
  }

  void skip() {
    if (state.gameState != GuessPlayerGameState.playing) return;
    _finishGame(false, 0);
  }

  void submitGuess(PlayerCard guess) {
    if (state.gameState != GuessPlayerGameState.playing) return;

    if (guess.id == state.targetPlayer.id) {
      // Won
      _finishGame(true, state.remainingHearts);
      emit(state.copyWith(guesses: [...state.guesses, guess]));
    } else {
      // Wrong guess
      final newHearts = state.remainingHearts - 1;
      final newHints = state.hintsRevealed + 1;

      emit(
        state.copyWith(
          guesses: [...state.guesses, guess],
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
        gameState: won ? GuessPlayerGameState.won : GuessPlayerGameState.lost,
        remainingHearts: heartsRemaining,
      ),
    );

    final newResult = GuessPlayerDailyResult(
      won: won,
      heartsRemaining: heartsRemaining,
      targetPlayerName: state.targetPlayer.name,
    );

    final updatedMap = Map<String, GuessPlayerDailyResult>.from(
      state.archive.resultsByDay,
    );
    updatedMap[state.todayKey] = newResult;

    final newArchive = GuessPlayerArchive(resultsByDay: updatedMap);
    emit(state.copyWith(archive: newArchive));
    storage.saveGuessPlayerArchive(sport, newArchive);
  }
}
