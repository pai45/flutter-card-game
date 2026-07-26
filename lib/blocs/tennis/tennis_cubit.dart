import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/tennis.dart';
import '../../services/secure_storage_service.dart';
import 'tennis_state.dart';

class TennisCubit extends Cubit<TennisState> {
  TennisCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const TennisState());

  final SecureGameStorage _storage;
  final Random _random;

  Future<void> load() async {
    final results = await Future.wait<Object?>([
      _storage.loadTennisProfile(),
      _storage.loadTennisMatchSnapshot(),
    ]);
    var profile = results[0]! as TennisProfile;
    final validIds = tennisPlayers.map((player) => player.id).toSet();
    if (!validIds.contains(profile.selectedPlayerId)) {
      profile = profile.copyWith(selectedPlayerId: tennisPlayers.first.id);
    }
    final validOwned = profile.ownedPlayerIds
        .where(validIds.contains)
        .toSet()
        .toList(growable: false);
    if (validOwned.length != profile.ownedPlayerIds.length) {
      profile = profile.copyWith(ownedPlayerIds: validOwned);
    }
    if (profile.starterPackClaimed && profile.ownedPlayerIds.isEmpty) {
      profile = profile.copyWith(ownedPlayerIds: [profile.selectedPlayerId]);
    }
    if (profile.starterPackClaimed &&
        !profile.ownedPlayerIds.contains(profile.selectedPlayerId)) {
      profile = profile.copyWith(
        selectedPlayerId: profile.ownedPlayerIds.first,
      );
    }
    if (!validIds.contains(profile.lastOpponentId) ||
        profile.lastOpponentId == profile.selectedPlayerId) {
      profile = profile.copyWith(
        lastOpponentId: _randomOpponentIdFor(profile.selectedPlayerId),
      );
    }
    emit(
      state.copyWith(
        loading: false,
        profile: profile,
        resumeSnapshot: results[1] as TennisMatchSnapshot?,
      ),
    );
  }

  void selectMode(TennisMode mode) {
    emit(state.copyWith(selectedMode: mode, phase: TennisFlowPhase.selection));
  }

  void selectPlayer(String playerId) {
    if (!state.profile.isPlayerUnlocked(playerId)) return;
    var opponentId = state.profile.lastOpponentId;
    if (opponentId == playerId) {
      opponentId = tennisPlayers
          .firstWhere((player) => player.id != playerId)
          .id;
    }
    _updateProfile(
      state.profile.copyWith(
        selectedPlayerId: playerId,
        lastOpponentId: opponentId,
      ),
    );
  }

  /// Mirrors the tennis cards held in the active [GameBloc] deck slot into the
  /// tennis profile.
  ///
  /// The starter pack itself is granted by `GameBloc` (see
  /// `TennisStarterPackOpened`) so tennis shares one card economy with every
  /// other sport; this profile is a cache of that, not a second source of truth.
  Future<void> syncFromDeck(List<String> ownedIds, String? starterId) async {
    final validIds = tennisPlayers.map((player) => player.id).toSet();
    final owned = ownedIds.where(validIds.contains).toSet().toList();
    if (owned.isEmpty) return;

    final selectedId = owned.contains(starterId) ? starterId! : owned.first;
    final unchanged =
        state.profile.starterPackClaimed &&
        state.profile.selectedPlayerId == selectedId &&
        state.profile.ownedPlayerIds.toSet().containsAll(owned) &&
        owned.length == state.profile.ownedPlayerIds.length;
    if (unchanged) return;

    final profile = state.profile.copyWith(
      starterPackClaimed: true,
      ownedPlayerIds: owned,
      selectedPlayerId: selectedId,
      lastOpponentId: _randomOpponentIdFor(selectedId),
    );
    emit(state.copyWith(profile: profile));
    await _storage.saveTennisProfile(profile);
  }

  void prepareQuickMatchPreview() {
    if (!state.profile.starterPackClaimed ||
        state.profile.ownedPlayerIds.isEmpty) {
      emit(
        state.copyWith(
          selectedMode: TennisMode.quickMatch,
          phase: TennisFlowPhase.hub,
          clearConfig: true,
          clearResult: true,
        ),
      );
      return;
    }
    final playerId =
        state.profile.ownedPlayerIds.contains(state.profile.selectedPlayerId)
        ? state.profile.selectedPlayerId
        : state.profile.ownedPlayerIds.first;
    final profile = state.profile.copyWith(
      selectedPlayerId: playerId,
      lastOpponentId: _randomOpponentIdFor(playerId),
    );
    _updateProfile(profile);
    emit(
      state.copyWith(
        selectedMode: TennisMode.quickMatch,
        phase: TennisFlowPhase.preview,
        clearConfig: true,
        clearResult: true,
      ),
    );
  }

  void selectOpponent(String opponentId) {
    if (opponentId == state.profile.selectedPlayerId) return;
    if (!tennisPlayers.any((player) => player.id == opponentId)) return;
    _updateProfile(state.profile.copyWith(lastOpponentId: opponentId));
  }

  void selectDifficulty(TennisDifficulty difficulty) {
    _updateProfile(state.profile.copyWith(difficulty: difficulty));
  }

  void selectTrainingLesson(int lesson) {
    emit(state.copyWith(trainingLesson: lesson.clamp(1, 8)));
  }

  void updateSettings(TennisSettings settings) {
    _updateProfile(state.profile.copyWith(settings: settings));
  }

  void showPreview() {
    emit(state.copyWith(phase: TennisFlowPhase.preview));
  }

  void prepareTournament() {
    final tournament = state.profile.tournament;
    if (tournament != null && tournament.active) return;
    _updateProfile(state.profile.copyWith(tournament: _createTournament()));
  }

  TennisMatchConfig buildMatch({TennisMode? mode, int? trainingLesson}) {
    final selectedMode = mode ?? state.selectedMode;
    var opponentId = state.profile.lastOpponentId;
    String? tournamentId;
    int? tournamentRound;
    if (selectedMode == TennisMode.tournament) {
      var tournament = state.profile.tournament;
      if (tournament == null || !tournament.active) {
        tournament = _createTournament();
        _updateProfile(state.profile.copyWith(tournament: tournament));
      }
      opponentId = tournament.currentOpponentId ?? opponentId;
      tournamentId = tournament.id;
      tournamentRound = tournament.currentRound;
    }
    final now = DateTime.now();
    final config = TennisMatchConfig(
      matchId:
          'tennis-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}',
      mode: selectedMode,
      playerId: state.profile.selectedPlayerId,
      opponentId: opponentId,
      difficulty: state.profile.difficulty,
      seed: _random.nextInt(0x7fffffff),
      trainingLesson: selectedMode == TennisMode.training
          ? (trainingLesson ?? state.trainingLesson)
          : null,
      tournamentId: tournamentId,
      tournamentRound: tournamentRound,
    );
    emit(
      state.copyWith(
        selectedMode: selectedMode,
        phase: TennisFlowPhase.match,
        config: config,
        clearResult: true,
      ),
    );
    return config;
  }

  TennisMatchConfig resumeMatch() {
    final snapshot = state.resumeSnapshot;
    if (snapshot == null) {
      throw StateError('No Tennis Rally match is available to resume.');
    }
    emit(
      state.copyWith(
        selectedMode: snapshot.config.mode,
        phase: TennisFlowPhase.match,
        config: snapshot.config,
        clearResult: true,
      ),
    );
    return snapshot.config;
  }

  Future<void> saveSnapshot(TennisMatchSnapshot snapshot) async {
    if (snapshot.config.matchId != state.config?.matchId) return;
    emit(state.copyWith(resumeSnapshot: snapshot));
    await _storage.saveTennisMatchSnapshot(snapshot);
  }

  Future<void> clearSnapshot() async {
    emit(state.copyWith(clearResume: true));
    await _storage.clearTennisMatchSnapshot();
  }

  Future<TennisReward> settle(TennisMatchSummary summary) async {
    if (state.profile.settledMatchIds.contains(summary.matchId)) {
      return TennisReward.zero;
    }
    final reward = calculateTennisReward(summary, state.profile);
    final profile = _recordSummary(state.profile, summary, reward);
    emit(
      state.copyWith(
        profile: profile,
        phase: TennisFlowPhase.result,
        summary: summary,
        reward: reward,
        clearResume: true,
      ),
    );
    await Future.wait([
      _storage.saveTennisProfile(profile),
      _storage.clearTennisMatchSnapshot(),
    ]);
    return reward;
  }

  Future<void> abandonMatch() async {
    emit(
      state.copyWith(
        phase: TennisFlowPhase.hub,
        clearConfig: true,
        clearResume: true,
        clearResult: true,
      ),
    );
    await _storage.clearTennisMatchSnapshot();
  }

  void returnToHub() {
    emit(
      state.copyWith(
        phase: TennisFlowPhase.hub,
        clearConfig: true,
        clearResult: true,
      ),
    );
  }

  TennisTournament _createTournament() {
    final entrants = tennisPlayers.map((player) => player.id).toList();
    final rivals =
        entrants.where((id) => id != state.profile.selectedPlayerId).toList()
          ..shuffle(_random);
    return TennisTournament(
      id: 'tour-${DateTime.now().microsecondsSinceEpoch}',
      playerId: state.profile.selectedPlayerId,
      difficulty: state.profile.difficulty,
      entrants: entrants,
      opponents: rivals.take(3).toList(growable: false),
    );
  }

  TennisProfile _recordSummary(
    TennisProfile profile,
    TennisMatchSummary summary,
    TennisReward reward,
  ) {
    final settled = <String>[...profile.settledMatchIds, summary.matchId];
    if (settled.length > 256) settled.removeRange(0, settled.length - 256);
    final mastery = Map<String, int>.from(profile.masteryXp);
    mastery[summary.playerId] =
        (mastery[summary.playerId] ?? 0) + reward.masteryXp;
    final completedLessons = Set<int>.from(profile.completedLessons);
    if (summary.mode == TennisMode.training && summary.trainingLesson != null) {
      completedLessons.add(summary.trainingLesson!);
    }
    final styles = Set<TennisArchetype>.from(profile.stylesWon);
    if (summary.won &&
        (summary.mode == TennisMode.quickMatch ||
            summary.mode == TennisMode.tournament)) {
      styles.add(tennisPlayerById(summary.playerId).archetype);
    }
    final achievements = Set<String>.from(profile.achievements);
    if (summary.stats.cleanHolds > 0) achievements.add('clean-hold');
    if (summary.stats.breakPointsWon > 0) achievements.add('break-through');
    if (summary.stats.maxBreakPointsSavedInGame >= 3) {
      achievements.add('unbreakable');
    }
    if (profile.totalAces + summary.stats.aces >= 5) {
      achievements.add('ace-high');
    }
    if (summary.stats.wonTwentyShotRally) {
      achievements.add('rally-architect');
    }
    final isServeVolley =
        tennisPlayerById(summary.playerId).archetype ==
        TennisArchetype.serveAndVolley;
    final serveVolleyNetPoints =
        profile.serveVolleyNetPoints +
        (isServeVolley ? summary.stats.netPointsWon : 0);
    if (serveVolleyNetPoints >= 10) {
      achievements.add('net-authority');
    }
    if (summary.stats.comebackFromThreeGames && summary.won) {
      achievements.add('comeback-set');
    }
    if (summary.stats.tiebreakNerve && summary.won) {
      achievements.add('tiebreak-nerve');
    }
    const baseStyles = <TennisArchetype>{
      TennisArchetype.allRounder,
      TennisArchetype.powerBaseliner,
      TennisArchetype.speedDefender,
      TennisArchetype.serveAndVolley,
      TennisArchetype.spinSpecialist,
    };
    if (styles.containsAll(baseStyles)) achievements.add('all-styles');
    if (summary.tournamentChampion) achievements.add('champion');

    final isSet =
        summary.mode == TennisMode.quickMatch ||
        summary.mode == TennisMode.tournament;
    final quickSignature =
        '${summary.playerId}:${summary.opponentId}:${summary.difficulty.name}';
    final repeatCount = summary.mode == TennisMode.quickMatch
        ? (profile.lastQuickSignature == quickSignature
              ? profile.quickRepeatCount + 1
              : 1)
        : profile.quickRepeatCount;
    var tournament = profile.tournament;
    final trophies = Map<String, int>.from(profile.trophies);
    if (summary.mode == TennisMode.tournament &&
        tournament != null &&
        tournament.id == state.config?.tournamentId) {
      final results = <String>[...tournament.results, summary.won ? 'W' : 'L'];
      if (summary.won && tournament.currentRound >= 2) {
        tournament = tournament.copyWith(
          results: results,
          currentRound: 3,
          active: false,
          champion: true,
        );
        trophies[summary.difficulty.name] =
            (trophies[summary.difficulty.name] ?? 0) + 1;
      } else if (summary.won) {
        tournament = tournament.copyWith(
          results: results,
          currentRound: tournament.currentRound + 1,
        );
      } else {
        tournament = tournament.copyWith(results: results, active: false);
      }
    }

    final winStreak = isSet
        ? (summary.won ? profile.currentWinStreak + 1 : 0)
        : profile.currentWinStreak;
    return profile.copyWith(
      setsPlayed: profile.setsPlayed + (isSet ? 1 : 0),
      setsWon: profile.setsWon + (isSet && summary.won ? 1 : 0),
      currentWinStreak: winStreak,
      bestWinStreak: max(profile.bestWinStreak, winStreak),
      totalAces: profile.totalAces + summary.stats.aces,
      longestRally: max(profile.longestRally, summary.stats.longestRally),
      cleanHolds: profile.cleanHolds + summary.stats.cleanHolds,
      breaksConverted: profile.breaksConverted + summary.stats.breakPointsWon,
      breakPointsSaved:
          profile.breakPointsSaved + summary.stats.breakPointsSaved,
      netPointsWon: profile.netPointsWon + summary.stats.netPointsWon,
      serveVolleyNetPoints: serveVolleyNetPoints,
      comebackSets:
          profile.comebackSets +
          (summary.stats.comebackFromThreeGames && summary.won ? 1 : 0),
      tiebreakNerveWins:
          profile.tiebreakNerveWins +
          (summary.stats.tiebreakNerve && summary.won ? 1 : 0),
      stylesWon: styles,
      achievements: achievements,
      masteryXp: mastery,
      completedLessons: completedLessons,
      trophies: trophies,
      bestEndless: summary.mode == TennisMode.endlessRally
          ? max(profile.bestEndless, summary.practiceScore)
          : profile.bestEndless,
      bestTarget: summary.mode == TennisMode.targetPractice
          ? max(profile.bestTarget, summary.practiceScore)
          : profile.bestTarget,
      lastQuickSignature: summary.mode == TennisMode.quickMatch
          ? quickSignature
          : profile.lastQuickSignature,
      quickRepeatCount: repeatCount,
      settledMatchIds: settled,
      tournament: tournament,
    );
  }

  void _updateProfile(TennisProfile profile) {
    emit(state.copyWith(profile: profile));
    unawaited(_storage.saveTennisProfile(profile));
  }

  String _randomOpponentIdFor(String playerId) {
    final opponents = tennisPlayers
        .where((player) => player.id != playerId)
        .toList(growable: false);
    return opponents[_random.nextInt(opponents.length)].id;
  }
}
