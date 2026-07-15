import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/basketball_athletes.dart';
import '../../data/basketball_teams.dart';
import '../../models/basketball.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import 'basketball_state.dart';

/// Drives a Hoop Duel session: lobby roster/difficulty selections, the
/// intro → halves → halftime → overtime → result phase machine, and stats
/// persistence.
///
/// The 60fps simulation never touches this cubit — the Flame game owns the
/// engine and the match screen forwards only coarse beats (half ended, match
/// ended). Rewards are dispatched by the match screen (GameBloc lives in the
/// widget tree), mirroring the Grand Prix / Football Chess pattern.
class BasketballCubit extends Cubit<BasketballState> {
  BasketballCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const BasketballState());

  final SecureGameStorage _storage;
  final Random _random;

  static const _defaultRoster = [
    'okc-shai-gilgeous-alexander',
    'den-nikola-jokic',
    'sas-victor-wembanyama',
  ];

  Future<void> load() async {
    final stats = await _storage.loadBasketballStats();
    final validIds = {for (final athlete in basketballAthletes) athlete.id};
    var roster = [
      for (final id in stats.lastRosterIds)
        if (validIds.contains(id)) id,
    ];
    if (roster.toSet().length != 3) roster = List.of(_defaultRoster);
    final starter = roster.contains(stats.lastStarterId)
        ? stats.lastStarterId!
        : roster.first;
    emit(
      state.copyWith(
        loading: false,
        stats: stats,
        rosterIds: roster,
        starterId: starter,
        difficulty: stats.lastDifficulty,
        teamId: stats.lastTeamId,
      ),
    );
  }

  // -- lobby ------------------------------------------------------------------

  void toggleRoster(String id) {
    if (state.phase != BasketballPhase.idle) return;
    final roster = List.of(state.rosterIds);
    if (roster.contains(id)) {
      roster.remove(id);
    } else if (roster.length < 3) {
      roster.add(id);
    } else {
      return; // roster full — deselect someone first
    }
    var starter = state.starterId;
    if (starter != null && !roster.contains(starter)) {
      starter = roster.isEmpty ? null : roster.first;
    }
    starter ??= roster.isEmpty ? null : roster.first;
    emit(
      state.copyWith(
        rosterIds: roster,
        starterId: starter,
        clearStarter: starter == null,
      ),
    );
    _persistSelections();
  }

  void setStarter(String id) {
    if (!state.rosterIds.contains(id)) return;
    emit(state.copyWith(starterId: id));
    _persistSelections();
  }

  void setDifficulty(BasketballDifficulty difficulty) {
    emit(state.copyWith(difficulty: difficulty));
    _persistSelections();
  }

  void setTeamId(String teamId) {
    emit(state.copyWith(teamId: teamId));
    _persistSelections();
  }

  void _persistSelections() {
    final stats = state.stats.copyWith(
      lastRosterIds: state.rosterIds,
      lastStarterId: state.starterId,
      lastDifficulty: state.difficulty,
      lastTeamId: state.teamId,
    );
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveBasketballStats(stats));
  }

  // -- match lifecycle ----------------------------------------------------------

  /// Builds a fresh seeded match from the lobby selections and enters the
  /// intro (VS + countdown). The Flame game is constructed from this config.
  void buildMatch() {
    if (!state.rosterReady) return;
    buildMatchFromRoster(
      rosterIds: state.rosterIds,
      starterId: state.starterId!,
    );
  }

  void buildMatchFromRoster({
    required List<String> rosterIds,
    required String starterId,
  }) {
    if (rosterIds.length != 3 || !rosterIds.contains(starterId)) return;
    final validIds = {for (final athlete in basketballAthletes) athlete.id};
    if (!rosterIds.every(validIds.contains)) return;
    final playerRoster = [
      for (final id in rosterIds) basketballAthleteById(id),
    ];
    final cpuPool = List.of(basketballAthletes)..shuffle(_random);
    final cpuRoster = cpuPool.take(3).toList();
    final rivalLiveries = [
      for (final team in basketballTeams)
        if (team.id != state.teamId) team.id,
    ]..shuffle(_random);
    final config = BasketballMatchConfig(
      playerRoster: playerRoster,
      playerStarterIndex: rosterIds.indexOf(starterId),
      cpuRoster: cpuRoster,
      cpuStarterIndex: _random.nextInt(cpuRoster.length),
      difficulty: state.difficulty,
      seed: _random.nextInt(1 << 31),
      showHints: !state.stats.hintsSeen,
      teamId: state.teamId,
      cpuTeamId: rivalLiveries.first,
    );
    emit(
      state.copyWith(
        phase: BasketballPhase.intro,
        halfIndex: 0,
        config: config,
        rosterIds: rosterIds,
        starterId: starterId,
        xp: 0,
      ),
    );
  }

  /// Tip-off countdown finished — the screen starts half 1 on the game.
  void beginPlay() {
    if (state.phase != BasketballPhase.intro) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 0));
  }

  void onHalfEnded({required int halfIndex, required bool needsOvertime}) {
    if (state.phase != BasketballPhase.playing) return;
    if (halfIndex == 0) {
      emit(state.copyWith(phase: BasketballPhase.halftime));
    } else if (needsOvertime) {
      emit(state.copyWith(phase: BasketballPhase.overtimeBreak));
    }
  }

  /// Halftime overlay confirmed — the screen applies rest/subs + starts H2.
  void resumeSecondHalf() {
    if (state.phase != BasketballPhase.halftime) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 1));
  }

  /// OVERTIME stinger finished — sudden death.
  void beginOvertime() {
    if (state.phase != BasketballPhase.overtimeBreak) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 2));
  }

  Future<void> onMatchEnded(BasketballMatchSummary summary) async {
    if (state.phase != BasketballPhase.playing) return;
    final xp = calculateBasketballXP(
      won: summary.won,
      margin: summary.margin,
      overtime: summary.overtime,
    );
    final stats = state.stats.recordResult(summary);
    emit(
      state.copyWith(
        phase: BasketballPhase.finished,
        summary: summary,
        xp: xp,
        stats: stats,
      ),
    );
    await _storage.saveBasketballStats(stats);
  }

  /// The match screen calls this after its final beat to raise the overlay.
  void showResult() {
    if (state.phase != BasketballPhase.finished) return;
    emit(state.copyWith(phase: BasketballPhase.result));
  }

  /// The first-match control hints have served their purpose.
  void markHintsSeen() {
    if (state.stats.hintsSeen) return;
    final stats = state.stats.copyWith(hintsSeen: true);
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveBasketballStats(stats));
  }

  /// Leaving mid-match discards the attempt — no stats, no reward (spec).
  void abandonMatch() {
    emit(
      state.copyWith(
        phase: BasketballPhase.idle,
        halfIndex: 0,
        clearMatch: true,
      ),
    );
  }
}
