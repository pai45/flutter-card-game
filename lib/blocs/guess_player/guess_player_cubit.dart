import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/guess_player_data.dart';
import '../../models/cards.dart';
import '../../models/guess_player.dart';
import '../../models/sport_match.dart';
import '../../services/secure_storage_service.dart';

enum GuessPlayerGameState { playing, won, lost }

typedef GuessPlayerNow = DateTime Function();

class GuessPlayerState {
  const GuessPlayerState({
    required this.loadStatus,
    required this.viewMode,
    required this.archive,
    required this.currentDayKey,
    required this.activeDayKey,
    required this.attemptsRemaining,
    required this.revealedClueCount,
    required this.guesses,
    required this.feedback,
    required this.feedbackSerial,
    required this.saving,
    required this.settlementPending,
    this.revealedHintTypes = const [],
    this.puzzle,
    this.targetPlayer,
    this.activeRecord,
    this.errorMessage,
  });

  factory GuessPlayerState.loading(String dayKey) => GuessPlayerState(
    loadStatus: GuessPlayerLoadStatus.loading,
    viewMode: GuessPlayerViewMode.home,
    archive: const GuessPlayerArchive(),
    currentDayKey: dayKey,
    activeDayKey: dayKey,
    attemptsRemaining: GuessPlayerCubit.maxAttempts,
    revealedClueCount: 1,
    guesses: const [],
    feedback: GuessPlayerSubmissionFeedback.none,
    feedbackSerial: 0,
    saving: false,
    settlementPending: false,
  );

  final GuessPlayerLoadStatus loadStatus;
  final GuessPlayerViewMode viewMode;
  final GuessPlayerArchive archive;
  final String currentDayKey;
  final String activeDayKey;
  final GuessPlayerPuzzle? puzzle;
  final PlayerCard? targetPlayer;
  final GuessPlayerDayRecord? activeRecord;
  final int attemptsRemaining;
  final int revealedClueCount;
  final List<PlayerCard> guesses;
  final GuessPlayerSubmissionFeedback feedback;
  final int feedbackSerial;
  final bool saving;
  final bool settlementPending;
  final List<String> revealedHintTypes;
  final String? errorMessage;

  bool hasHint(GuessPlayerHintType type) =>
      revealedHintTypes.contains(type.name);

  GuessPlayerGameState get gameState {
    return switch (activeRecord?.status) {
      GuessPlayerResultStatus.won => GuessPlayerGameState.won,
      GuessPlayerResultStatus.lost ||
      GuessPlayerResultStatus.gaveUp ||
      GuessPlayerResultStatus.expired ||
      GuessPlayerResultStatus.legacy => GuessPlayerGameState.lost,
      _ => GuessPlayerGameState.playing,
    };
  }

  bool get isPlaying =>
      activeRecord?.status == GuessPlayerResultStatus.inProgress;
  bool get isReview => viewMode == GuessPlayerViewMode.review;
  bool get isToday => activeDayKey == currentDayKey;
  int get remainingHearts => attemptsRemaining;
  int get hintsRevealed => max(0, revealedClueCount - 1);
  String get todayKey => currentDayKey;
  List<String> get unlockedDayKeys =>
      archive.resultsByDay.keys.toList()..sort();
  int get potentialXp => 20 + attemptsRemaining * 5;
  int get potentialScore => attemptsRemaining * 100;

  GuessPlayerState copyWith({
    GuessPlayerLoadStatus? loadStatus,
    GuessPlayerViewMode? viewMode,
    GuessPlayerArchive? archive,
    String? currentDayKey,
    String? activeDayKey,
    GuessPlayerPuzzle? puzzle,
    PlayerCard? targetPlayer,
    GuessPlayerDayRecord? activeRecord,
    int? attemptsRemaining,
    int? revealedClueCount,
    List<PlayerCard>? guesses,
    GuessPlayerSubmissionFeedback? feedback,
    int? feedbackSerial,
    bool? saving,
    bool? settlementPending,
    List<String>? revealedHintTypes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GuessPlayerState(
      loadStatus: loadStatus ?? this.loadStatus,
      viewMode: viewMode ?? this.viewMode,
      archive: archive ?? this.archive,
      currentDayKey: currentDayKey ?? this.currentDayKey,
      activeDayKey: activeDayKey ?? this.activeDayKey,
      puzzle: puzzle ?? this.puzzle,
      targetPlayer: targetPlayer ?? this.targetPlayer,
      activeRecord: activeRecord ?? this.activeRecord,
      attemptsRemaining: attemptsRemaining ?? this.attemptsRemaining,
      revealedClueCount: revealedClueCount ?? this.revealedClueCount,
      guesses: guesses ?? this.guesses,
      feedback: feedback ?? this.feedback,
      feedbackSerial: feedbackSerial ?? this.feedbackSerial,
      saving: saving ?? this.saving,
      settlementPending: settlementPending ?? this.settlementPending,
      revealedHintTypes: revealedHintTypes ?? this.revealedHintTypes,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class GuessPlayerCubit extends Cubit<GuessPlayerState> {
  GuessPlayerCubit({
    required this.sport,
    required this.timelines,
    required this.allPlayers,
    required this.storage,
    GuessPlayerPuzzleRepository? repository,
    GuessPlayerNow? now,
  }) : repository =
           repository ??
           LocalGuessPlayerPuzzleRepository(
             sport: sport,
             timelines: timelines,
             players: allPlayers,
           ),
       now = now ?? DateTime.now,
       super(
         GuessPlayerState.loading(
           guessPlayerDayKey((now ?? DateTime.now).call()),
         ),
       );

  final Sport sport;
  final List<GuessPlayerTimeline> timelines;
  final List<PlayerCard> allPlayers;
  final SecureGameStorage storage;
  final GuessPlayerPuzzleRepository repository;
  final GuessPlayerNow now;

  static const int maxAttempts = 6;
  static const int maxHearts = maxAttempts;
  static const int archiveWindowDays = 30;

  Future<void> load() async {
    final currentDayKey = guessPlayerDayKey(now());
    emit(
      state.copyWith(
        loadStatus: GuessPlayerLoadStatus.loading,
        currentDayKey: currentDayKey,
        activeDayKey: currentDayKey,
        viewMode: GuessPlayerViewMode.home,
        clearError: true,
      ),
    );
    try {
      final issues = repository.validate();
      if (issues.isNotEmpty) {
        throw StateError(issues.join('\n'));
      }

      var archive =
          await storage.loadGuessPlayerArchive(sport) ??
          const GuessPlayerArchive();
      var records = Map<String, GuessPlayerDayRecord>.from(
        archive.resultsByDay,
      );
      var changed = false;

      for (final entry in records.entries.toList()) {
        final record = entry.value;
        if (entry.key.compareTo(currentDayKey) < 0 &&
            record.status == GuessPlayerResultStatus.inProgress) {
          records[entry.key] = record.copyWith(
            status: GuessPlayerResultStatus.expired,
            completedAtEpochMs: now().millisecondsSinceEpoch,
          );
          changed = true;
        }
      }

      var currentRecord = records[currentDayKey];
      GuessPlayerPuzzle currentPuzzle;
      if (currentRecord == null) {
        currentPuzzle = repository.puzzleForDay(now());
        final target = _playerById(currentPuzzle.playerId);
        currentRecord = _freshRecord(currentDayKey, currentPuzzle, target.name);
        records[currentDayKey] = currentRecord;
        changed = true;
      } else {
        currentPuzzle = _puzzleForRecord(currentRecord);
      }

      archive = GuessPlayerArchive(resultsByDay: records);
      // Always materialize v2 on load; the v1 key remains untouched.
      if (changed || archive.resultsByDay.isNotEmpty) {
        await storage.saveGuessPlayerArchive(sport, archive);
      }
      emit(
        _stateForRecord(
          archive: archive,
          record: currentRecord,
          puzzle: currentPuzzle,
          viewMode: GuessPlayerViewMode.home,
          currentDayKey: currentDayKey,
          settlementPending: await _needsSettlement(currentRecord),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loadStatus: GuessPlayerLoadStatus.error,
          saving: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> refreshForCurrentDay() async {
    if (guessPlayerDayKey(now()) != state.currentDayKey) {
      await load();
    }
  }

  Future<void> openToday() async {
    await refreshForCurrentDay();
    final record = state.archive.resultsByDay[state.currentDayKey];
    if (record == null ||
        state.loadStatus == GuessPlayerLoadStatus.loading ||
        state.loadStatus == GuessPlayerLoadStatus.error) {
      return;
    }
    final puzzle = _puzzleForRecord(record);
    var active = record;
    if (record.status == GuessPlayerResultStatus.inProgress &&
        record.startedAtEpochMs == 0) {
      active = record.copyWith(startedAtEpochMs: now().millisecondsSinceEpoch);
      final archive = state.archive.copyWithRecord(active);
      try {
        await storage.saveGuessPlayerArchive(sport, archive);
        emit(
          _stateForRecord(
            archive: archive,
            record: active,
            puzzle: puzzle,
            viewMode: GuessPlayerViewMode.play,
            currentDayKey: state.currentDayKey,
            settlementPending: state.settlementPending,
          ),
        );
      } catch (error) {
        emit(state.copyWith(errorMessage: error.toString()));
      }
      return;
    }
    emit(
      _stateForRecord(
        archive: state.archive,
        record: active,
        puzzle: puzzle,
        viewMode: active.status == GuessPlayerResultStatus.inProgress
            ? GuessPlayerViewMode.play
            : GuessPlayerViewMode.review,
        currentDayKey: state.currentDayKey,
        settlementPending: state.settlementPending,
      ),
    );
  }

  Future<bool> openDay(String dayKey) async {
    if (dayKey == state.currentDayKey) {
      await openToday();
      return true;
    }
    final record = state.archive.resultsByDay[dayKey];
    if (record == null ||
        record.status == GuessPlayerResultStatus.expired ||
        record.status == GuessPlayerResultStatus.inProgress) {
      return false;
    }
    try {
      final puzzle = _puzzleForRecord(record);
      emit(
        _stateForRecord(
          archive: state.archive,
          record: record,
          puzzle: puzzle,
          viewMode: GuessPlayerViewMode.review,
          currentDayKey: state.currentDayKey,
        ),
      );
      return true;
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
      return false;
    }
  }

  void showHome() {
    final record = state.archive.resultsByDay[state.currentDayKey];
    if (record == null) return;
    try {
      emit(
        _stateForRecord(
          archive: state.archive,
          record: record,
          puzzle: _puzzleForRecord(record),
          viewMode: GuessPlayerViewMode.home,
          currentDayKey: state.currentDayKey,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    }
  }

  void showLogs() {
    emit(state.copyWith(viewMode: GuessPlayerViewMode.logs, clearError: true));
  }

  Future<void> submitGuess(PlayerCard guess) async {
    final record = state.activeRecord;
    if (state.saving ||
        state.viewMode != GuessPlayerViewMode.play ||
        record == null ||
        record.status != GuessPlayerResultStatus.inProgress ||
        record.attemptsRemaining <= 0) {
      return;
    }
    if (record.guessedPlayerIds.contains(guess.id)) {
      emit(
        state.copyWith(
          feedback: GuessPlayerSubmissionFeedback.duplicate,
          feedbackSerial: state.feedbackSerial + 1,
        ),
      );
      return;
    }

    final correct = guess.id == state.puzzle?.playerId;
    final guessIds = [...record.guessedPlayerIds, guess.id];
    final timestamp = now().millisecondsSinceEpoch;
    final started = record.startedAtEpochMs == 0
        ? timestamp
        : record.startedAtEpochMs;
    GuessPlayerDayRecord next;
    if (correct) {
      final score = record.attemptsRemaining * 100;
      final xp = 20 + record.attemptsRemaining * 5;
      next = record.copyWith(
        status: GuessPlayerResultStatus.won,
        guessedPlayerIds: guessIds,
        score: score,
        xpEarned: xp,
        startedAtEpochMs: started,
        completedAtEpochMs: timestamp,
        elapsedMs: max(0, timestamp - started),
      );
    } else {
      final remaining = max(0, record.attemptsRemaining - 1);
      next = record.copyWith(
        status: GuessPlayerResultStatus.inProgress,
        guessedPlayerIds: guessIds,
        attemptsRemaining: remaining,
        revealedClueCount: min(6, record.revealedClueCount + 1),
        startedAtEpochMs: started,
        completedAtEpochMs: 0,
        elapsedMs: max(0, timestamp - started),
      );
    }
    await _persistSubmission(
      next,
      feedback: correct
          ? GuessPlayerSubmissionFeedback.correct
          : GuessPlayerSubmissionFeedback.wrong,
      settlementPending: correct,
    );
  }

  /// Restores a single paid guess after the free six attempts are exhausted.
  ///
  /// Coin settlement is deliberately performed by the UI through [GameBloc],
  /// matching hints and Football Bingo lifelines.
  Future<bool> buyExtraAttempt() async {
    final record = state.activeRecord;
    if (state.saving ||
        state.viewMode != GuessPlayerViewMode.play ||
        record == null ||
        record.status != GuessPlayerResultStatus.inProgress ||
        record.attemptsRemaining > 0) {
      return false;
    }
    await _persistSubmission(
      record.copyWith(attemptsRemaining: 1, revealedClueCount: 6),
      feedback: GuessPlayerSubmissionFeedback.none,
      settlementPending: false,
    );
    return state.activeRecord?.attemptsRemaining == 1;
  }

  Future<void> giveUp() async {
    final record = state.activeRecord;
    if (state.saving ||
        state.viewMode != GuessPlayerViewMode.play ||
        record == null ||
        record.status != GuessPlayerResultStatus.inProgress) {
      return;
    }
    final timestamp = now().millisecondsSinceEpoch;
    final started = record.startedAtEpochMs == 0
        ? timestamp
        : record.startedAtEpochMs;
    await _persistSubmission(
      record.copyWith(
        status: GuessPlayerResultStatus.gaveUp,
        revealedClueCount: 6,
        startedAtEpochMs: started,
        completedAtEpochMs: timestamp,
        elapsedMs: max(0, timestamp - started),
      ),
      feedback: GuessPlayerSubmissionFeedback.wrong,
      settlementPending: true,
    );
  }

  /// Persists a purchased profile scan without spending an attempt. Coin
  /// settlement is deliberately performed by the UI through [GameBloc], which
  /// owns the wallet and its ledger.
  Future<bool> unlockHint(GuessPlayerHintType type) async {
    final record = state.activeRecord;
    if (state.saving ||
        state.viewMode != GuessPlayerViewMode.play ||
        record == null ||
        record.status != GuessPlayerResultStatus.inProgress ||
        record.hasHint(type)) {
      return false;
    }
    final hintTypes = {...record.revealedHintTypes, type.name}.toList();
    await _persistSubmission(
      record.copyWith(revealedHintTypes: hintTypes),
      feedback: GuessPlayerSubmissionFeedback.none,
      settlementPending: false,
    );
    return state.activeRecord?.hasHint(type) ?? false;
  }

  Future<void> skip() => giveUp();

  void consumeSettlement() {
    if (state.settlementPending) {
      emit(state.copyWith(settlementPending: false));
    }
  }

  List<String> archiveDayKeys({int days = archiveWindowDays}) {
    final date = DateTime.tryParse(state.currentDayKey) ?? now();
    return [
      for (var index = 0; index < days; index++)
        guessPlayerDayKey(date.subtract(Duration(days: index))),
    ];
  }

  List<PlayerCard> searchPlayers(String query) {
    final normalized = normalizeGuessPlayerSearch(query);
    if (normalized.length < 2) return const [];
    final guessed = state.activeRecord?.guessedPlayerIds.toSet() ?? <String>{};
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
    final matches = allPlayers.where((player) {
      if (guessed.contains(player.id)) return false;
      final name = normalizeGuessPlayerSearch(player.name);
      return tokens.every(name.contains);
    }).toList();
    matches.sort((a, b) {
      final aName = normalizeGuessPlayerSearch(a.name);
      final bName = normalizeGuessPlayerSearch(b.name);
      final aPrefix = aName.startsWith(normalized);
      final bPrefix = bName.startsWith(normalized);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      final rating = b.rating.compareTo(a.rating);
      return rating != 0 ? rating : a.name.compareTo(b.name);
    });
    return matches.take(8).toList();
  }

  Future<void> _persistSubmission(
    GuessPlayerDayRecord record, {
    required GuessPlayerSubmissionFeedback feedback,
    required bool settlementPending,
  }) async {
    emit(
      state.copyWith(
        loadStatus: GuessPlayerLoadStatus.submitting,
        saving: true,
        clearError: true,
      ),
    );
    final archive = state.archive.copyWithRecord(record);
    try {
      await storage.saveGuessPlayerArchive(sport, archive);
      final puzzle = state.puzzle ?? _puzzleForRecord(record);
      emit(
        _stateForRecord(
          archive: archive,
          record: record,
          puzzle: puzzle,
          viewMode: record.status == GuessPlayerResultStatus.inProgress
              ? GuessPlayerViewMode.play
              : GuessPlayerViewMode.review,
          currentDayKey: state.currentDayKey,
          feedback: feedback,
          feedbackSerial: state.feedbackSerial + 1,
          settlementPending: settlementPending,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loadStatus: GuessPlayerLoadStatus.error,
          saving: false,
          errorMessage: 'Could not save this guess. ${error.toString()}',
        ),
      );
    }
  }

  GuessPlayerState _stateForRecord({
    required GuessPlayerArchive archive,
    required GuessPlayerDayRecord record,
    required GuessPlayerPuzzle puzzle,
    required GuessPlayerViewMode viewMode,
    required String currentDayKey,
    GuessPlayerSubmissionFeedback feedback = GuessPlayerSubmissionFeedback.none,
    int? feedbackSerial,
    bool settlementPending = false,
  }) {
    final target = _playerForRecord(record, puzzle);
    final guesses = <PlayerCard>[
      for (final id in record.guessedPlayerIds) ?_playerByIdOrNull(id),
    ];
    return GuessPlayerState(
      loadStatus:
          viewMode == GuessPlayerViewMode.review &&
              record.status != GuessPlayerResultStatus.inProgress
          ? GuessPlayerLoadStatus.completed
          : GuessPlayerLoadStatus.ready,
      viewMode: viewMode,
      archive: archive,
      currentDayKey: currentDayKey,
      activeDayKey: record.dayKey,
      puzzle: puzzle,
      targetPlayer: target,
      activeRecord: record,
      attemptsRemaining: record.attemptsRemaining,
      revealedClueCount: record.revealedClueCount.clamp(1, 6),
      guesses: guesses,
      feedback: feedback,
      feedbackSerial: feedbackSerial ?? state.feedbackSerial,
      saving: false,
      settlementPending: settlementPending,
      revealedHintTypes: record.revealedHintTypes,
    );
  }

  GuessPlayerDayRecord _freshRecord(
    String dayKey,
    GuessPlayerPuzzle puzzle,
    String playerName,
  ) {
    return GuessPlayerDayRecord(
      dayKey: dayKey,
      puzzleId: puzzle.id,
      playerId: puzzle.playerId,
      targetPlayerName: playerName,
      status: GuessPlayerResultStatus.inProgress,
      guessedPlayerIds: const [],
      revealedClueCount: 1,
      attemptsRemaining: maxAttempts,
      score: 0,
      xpEarned: 0,
      elapsedMs: 0,
      startedAtEpochMs: 0,
      completedAtEpochMs: 0,
      revealedHintTypes: const [],
    );
  }

  GuessPlayerPuzzle _puzzleForRecord(GuessPlayerDayRecord record) {
    final direct = repository.puzzleById(record.puzzleId);
    if (direct != null) return direct;
    if (record.legacy && record.targetPlayerName.isNotEmpty) {
      final player = allPlayers
          .where((candidate) => candidate.name == record.targetPlayerName)
          .firstOrNull;
      if (player != null) {
        for (final puzzle in repository.puzzles) {
          if (puzzle.playerId == player.id) return puzzle;
        }
      }
    }
    throw StateError(
      'Puzzle ${record.puzzleId.isEmpty ? '(legacy)' : record.puzzleId} '
      'is no longer available.',
    );
  }

  PlayerCard _playerForRecord(
    GuessPlayerDayRecord record,
    GuessPlayerPuzzle puzzle,
  ) {
    if (!record.legacy && record.playerId != puzzle.playerId) {
      throw StateError(
        'Puzzle ${puzzle.id} does not match stored player ${record.playerId}.',
      );
    }
    final direct = _playerByIdOrNull(
      record.legacy ? puzzle.playerId : record.playerId,
    );
    if (direct != null) return direct;
    if (record.legacy) {
      final named = allPlayers
          .where((player) => player.name == record.targetPlayerName)
          .firstOrNull;
      if (named != null) return named;
    }
    throw StateError('Puzzle target ${puzzle.playerId} is missing.');
  }

  Future<bool> _needsSettlement(GuessPlayerDayRecord record) async {
    if (record.legacy ||
        record.status == GuessPlayerResultStatus.inProgress ||
        record.status == GuessPlayerResultStatus.expired) {
      return false;
    }
    final settled = await storage.loadGuessPlayerSettlementIds();
    return !settled.contains('guess-player:${sport.name}:${record.dayKey}');
  }

  PlayerCard _playerById(String id) {
    final player = _playerByIdOrNull(id);
    if (player == null) throw StateError('Player $id is missing.');
    return player;
  }

  PlayerCard? _playerByIdOrNull(String id) {
    for (final player in allPlayers) {
      if (player.id == id) return player;
    }
    return null;
  }
}

String normalizeGuessPlayerSearch(String value) {
  const folds = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ø': 'o',
    'œ': 'oe',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'š': 's',
    'ž': 'z',
  };
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(folds[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
