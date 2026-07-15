import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../games/super_over/super_over_engine.dart';
import '../../models/cards.dart';
import '../../models/super_over.dart';
import '../../services/secure_storage_service.dart';
import 'super_over_event.dart';
import 'super_over_state.dart';

class SuperOverBloc extends Bloc<SuperOverEvent, SuperOverState> {
  SuperOverBloc(this._storage, {Random? random})
    : _random = random ?? Random(),
      _engine = SuperOverEngine(random: random),
      super(const SuperOverState()) {
    on<SuperOverStarted>(_onStarted);
    on<SuperOverSnapshotRestored>(_onSnapshotRestored);
    on<SuperOverFlowChanged>(_onFlowChanged);
    on<SuperOverPhaseChanged>(_onPhaseChanged);
    on<SuperOverPlayPhaseChanged>(_onPlayPhaseChanged);
    on<SuperOverInputArmed>(_onInputArmed);
    on<SuperOverIntentLocked>(_onIntentLocked);
    on<SuperOverSwingLocked>(_onSwingLocked);
    on<SuperOverShotResolved>(_onShotResolved);
    on<SuperOverSectorSelected>(_onSectorSelected);
    on<SuperOverShotStyleSelected>(_onShotStyleSelected);
    on<SuperOverDeliveryResolved>(_onDeliveryResolved);
    on<SuperOverNextBallRequested>(_onNextBallRequested);
    on<SuperOverPaused>(_onPaused);
    on<SuperOverResumed>(_onResumed);
    on<SuperOverSettingsChanged>(_onSettingsChanged);
    on<SuperOverReset>(_onReset);
    on<SuperOverJerseySelected>(_onJerseySelected);
  }

  final SecureGameStorage _storage;
  final Random _random;
  final SuperOverEngine _engine;

  Future<void> _onStarted(
    SuperOverStarted event,
    Emitter<SuperOverState> emit,
  ) async {
    final battingOrder = event.battingOrder.length == 3
        ? event.battingOrder
        : batsmen.take(3).toList(growable: false);
    if (battingOrder.length != 3) return;
    final now = DateTime.now();
    final config =
        event.config ??
        SuperOverMatchConfig(
          matchId:
              'so-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}',
          seed: _random.nextInt(0x7fffffff),
          mode: event.mode,
          difficulty: event.difficulty,
          level: event.playerLevel,
          battingCardIds: battingOrder.map((card) => card.id).toList(),
          jerseyId: event.jersey.name,
          tutorial: event.tutorial,
        );
    final target = config.mode == SuperOverMode.chase
        ? _engine.targetForConfig(config)
        : 0;
    final objective = _engine.objectiveForConfig(config, target: target);
    final committed = _engine.commitNextBall(
      config: config,
      completedBalls: const [],
      target: target,
    );
    final settings = event.settings.copyWith(difficulty: config.difficulty);
    final rhythm = {for (final card in battingOrder) card.id: 0};
    final next = SuperOverState(
      flowPhase: SuperOverFlowPhase.targetReveal,
      playPhase: SuperOverPlayPhase.fieldReveal,
      phase: SuperOverPhase.targetReveal,
      config: config,
      settings: settings,
      jersey: event.jersey,
      battingOrder: battingOrder,
      mode: config.mode,
      cpuTarget: target,
      fieldSectors: committed.fieldPlan.sectorCounts,
      fieldPlan: committed.fieldPlan,
      committedBall: committed,
      deliveryPlan: committed.delivery,
      objective: objective,
      rhythmByCardId: rhythm,
    );
    emit(next);
    await _saveBoundarySnapshot(next);
  }

  void _onSnapshotRestored(
    SuperOverSnapshotRestored event,
    Emitter<SuperOverState> emit,
  ) {
    final snapshot = event.snapshot;
    final records = snapshot.ballRecords;
    final last = records.lastOrNull;
    final committed = snapshot.committedBall;
    final jersey = cricketJerseyFromName(snapshot.config.jerseyId);
    emit(
      SuperOverState(
        flowPhase: SuperOverFlowPhase.playing,
        playPhase: SuperOverPlayPhase.fieldReveal,
        phase: SuperOverPhase.ballSetup,
        config: snapshot.config,
        settings: state.settings.copyWith(
          difficulty: snapshot.config.difficulty,
        ),
        jersey: jersey,
        score: snapshot.score,
        wickets: snapshot.wickets,
        ballsFaced: records.length,
        battingOrder: event.battingOrder,
        strikerIndex: snapshot.strikerIndex,
        nonStrikerIndex: snapshot.nonStrikerIndex,
        combo: snapshot.combo,
        maxCombo: snapshot.maxCombo,
        mode: snapshot.config.mode,
        cpuTarget: snapshot.target ?? 0,
        wagonWheel: records.map((ball) => ball.outcome).toList(),
        ballRecords: records,
        fieldSectors: committed.fieldPlan.sectorCounts,
        fieldPlan: committed.fieldPlan,
        committedBall: committed,
        deliveryPlan: committed.delivery,
        selectedSector: snapshot.selectedSector,
        selectedShotStyle: snapshot.selectedShotStyle,
        rhythmByCardId: snapshot.rhythmByCardId,
        confidence:
            snapshot.rhythmByCardId[event
                .battingOrder[snapshot.strikerIndex]
                .id] ??
            0,
        finisherReady: snapshot.finisherReady,
        finisherProgress: snapshot.finisherReady ? 3 : 0,
        objective: snapshot.objective,
        perfectContacts: records
            .where((ball) => ball.timingTier == TimingTier.perfect)
            .length,
        openGapHits: records.where((ball) => ball.scoredInOpenSector).length,
        lastOutcome: last?.outcome,
      ),
    );
  }

  void _onFlowChanged(
    SuperOverFlowChanged event,
    Emitter<SuperOverState> emit,
  ) => emit(state.copyWith(flowPhase: event.phase));

  void _onPhaseChanged(
    SuperOverPhaseChanged event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver) return;
    final playPhase = switch (event.phase) {
      SuperOverPhase.ballSetup => SuperOverPlayPhase.fieldReveal,
      SuperOverPhase.runUp => SuperOverPlayPhase.runUp,
      SuperOverPhase.ballInFlight => SuperOverPlayPhase.release,
      SuperOverPhase.swinging => SuperOverPlayPhase.contact,
      SuperOverPhase.outcome => SuperOverPlayPhase.outcome,
      SuperOverPhase.result => SuperOverPlayPhase.complete,
      _ => state.playPhase,
    };
    emit(
      state.copyWith(
        phase: event.phase,
        playPhase: playPhase,
        flowPhase: event.phase == SuperOverPhase.paused
            ? SuperOverFlowPhase.paused
            : state.flowPhase,
        inputEnabled: event.phase == SuperOverPhase.ballInFlight
            ? state.inputEnabled
            : false,
      ),
    );
  }

  void _onPlayPhaseChanged(
    SuperOverPlayPhaseChanged event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver) return;
    emit(state.copyWith(playPhase: event.phase));
  }

  void _onInputArmed(SuperOverInputArmed event, Emitter<SuperOverState> emit) {
    if (state.isOver) return;
    emit(
      state.copyWith(
        inputEnabled: true,
        phase: SuperOverPhase.ballInFlight,
        playPhase: SuperOverPlayPhase.inputArmed,
        flowPhase: SuperOverFlowPhase.playing,
      ),
    );
  }

  void _onIntentLocked(
    SuperOverIntentLocked event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver || state.swingLocked) return;
    emit(state.copyWith(swingLocked: true));
  }

  void _onSwingLocked(
    SuperOverSwingLocked event,
    Emitter<SuperOverState> emit,
  ) {
    if (!state.canTap && !state.swingLocked) return;
    emit(
      state.copyWith(
        swingLocked: true,
        inputEnabled: false,
        phase: SuperOverPhase.swinging,
        playPhase: SuperOverPlayPhase.contact,
      ),
    );
  }

  Future<void> _onShotResolved(
    SuperOverShotResolved event,
    Emitter<SuperOverState> emit,
  ) async {
    if (state.isOver || state.lastOutcome != null) return;
    final committed = state.committedBall;
    final config = state.config;
    if (committed == null || config == null || state.striker == null) return;
    final intent = event.noInput
        ? null
        : event.intent ??
              ShotIntent(
                sector: state.selectedSector,
                style: state.selectedShotStyle,
                timingErrorMs: event.timingErrorMs ?? 0,
                leftHanded:
                    event.leftHanded || state.settings.leftHandedControls,
              );
    final result = _engine.resolveCommittedBall(
      committedBall: committed,
      intent: intent,
      rating: state.striker!.rating,
      battingStyle: _engine.battingStyleFor(state.striker),
      rhythm: state.currentRhythm,
      finisherMode: state.finisherActive,
      difficulty: config.difficulty,
    );
    await _applyResolvedShot(result, intent: intent, emit: emit);
  }

  void _onSectorSelected(
    SuperOverSectorSelected event,
    Emitter<SuperOverState> emit,
  ) {
    if (!state.canSelectIntent) return;
    emit(state.copyWith(selectedSector: event.sector));
  }

  void _onShotStyleSelected(
    SuperOverShotStyleSelected event,
    Emitter<SuperOverState> emit,
  ) {
    if (!state.canSelectIntent) return;
    emit(state.copyWith(selectedShotStyle: event.style));
  }

  Future<void> _onDeliveryResolved(
    SuperOverDeliveryResolved event,
    Emitter<SuperOverState> emit,
  ) async {
    if (state.isOver || state.lastOutcome != null) return;
    final result = SuperOverShotResult(
      timingErrorMs: 0,
      normalizedError: 0,
      tier: switch (event.outcome) {
        ShotOutcome.six || ShotOutcome.four => TimingTier.perfect,
        ShotOutcome.one ||
        ShotOutcome.two ||
        ShotOutcome.three => TimingTier.good,
        ShotOutcome.dot => TimingTier.edgePoor,
        ShotOutcome.caught || ShotOutcome.bowled => TimingTier.miss,
      },
      sector: state.selectedSector,
      power: 80,
      outcome: event.outcome,
    );
    await _applyResolvedShot(
      result,
      intent: ShotIntent(
        sector: state.selectedSector,
        style: state.selectedShotStyle,
        timingErrorMs: 0,
      ),
      emit: emit,
    );
  }

  Future<void> _applyResolvedShot(
    SuperOverShotResult result, {
    required ShotIntent? intent,
    required Emitter<SuperOverState> emit,
  }) async {
    final config = state.config;
    final committed = state.committedBall;
    final striker = state.striker;
    final nonStriker = state.nonStriker;
    if (config == null ||
        committed == null ||
        striker == null ||
        nonStriker == null) {
      return;
    }
    final before = state.position;
    final after = _engine.applyOutcome(
      position: before,
      outcome: result.outcome,
      mode: config.mode,
      target: state.cpuTarget,
    );
    final rhythmBefore = state.currentRhythm;
    final rhythmAfter = _engine.rhythmAfter(
      currentRhythm: rhythmBefore,
      result: result,
    );
    final rhythmMap = Map<String, int>.of(state.rhythmByCardId)
      ..[striker.id] = rhythmAfter;
    final runs = SuperOverResolution.runsForOutcome(result.outcome);
    final isWicket =
        result.outcome == ShotOutcome.caught ||
        result.outcome == ShotOutcome.bowled;
    final clean =
        runs > 0 &&
        !isWicket &&
        result.tier != TimingTier.edgePoor &&
        result.tier != TimingTier.miss;
    var finisherProgress = state.finisherProgress;
    var finisherReady = false;
    if (isWicket) {
      finisherProgress = 0;
    } else if (clean) {
      finisherProgress = min(3, finisherProgress + 1);
      finisherReady = finisherProgress >= 3;
      if (finisherReady) finisherProgress = 0;
    } else {
      finisherProgress = max(0, finisherProgress - 1);
    }
    if (state.finisherActive) {
      finisherProgress = 0;
      finisherReady = false;
    }
    final record = SuperOverBallRecord(
      ballNumber: committed.ballNumber,
      strikerCardId: striker.id,
      nonStrikerCardId: nonStriker.id,
      committedBall: committed,
      intent: intent,
      contactType: result.contactType,
      timingErrorMs: result.timingErrorMs,
      normalizedTimingError: result.normalizedError,
      timingTier: result.tier,
      drift: result.drift,
      resolvedSector: result.sector,
      outcome: result.outcome,
      runs: runs,
      usedFinisherMode: state.finisherActive,
      rhythmBefore: rhythmBefore,
      rhythmAfter: rhythmAfter,
      scoreAfter: after.score,
      wicketsAfter: after.wickets,
    );
    final records = [...state.ballRecords, record];
    final objectiveProgress = _engine.objectiveProgress(
      objective: state.objective,
      ballRecords: records,
      score: after.score,
      wickets: after.wickets,
      matchComplete: after.isComplete,
      wonChase: after.wonChase,
    );
    final combo = runs > 0 && !isWicket ? state.combo + 1 : 0;
    SuperOverMatchSummary? summary = after.isComplete
        ? _engine.buildSummary(
            config: config,
            target: config.mode == SuperOverMode.chase ? state.cpuTarget : null,
            position: after,
            objective: state.objective,
            ballRecords: records,
            completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          )
        : null;
    final nextState = state.copyWith(
      flowPhase: after.isComplete
          ? SuperOverFlowPhase.result
          : SuperOverFlowPhase.playing,
      playPhase: after.isComplete
          ? SuperOverPlayPhase.complete
          : isWicket
          ? SuperOverPlayPhase.wicketTransition
          : SuperOverPlayPhase.outcome,
      phase: after.isComplete ? SuperOverPhase.result : SuperOverPhase.outcome,
      score: after.score,
      wickets: after.wickets,
      ballsFaced: after.ballsFaced,
      strikerIndex: after.strikerIndex,
      nonStrikerIndex: after.nonStrikerIndex,
      isOver: after.isComplete,
      wonChase: after.wonChase,
      wagonWheel: [...state.wagonWheel, result.outcome],
      ballRecords: records,
      momentum: finisherProgress,
      onFire: finisherReady,
      combo: combo,
      maxCombo: max(state.maxCombo, combo),
      confidence: rhythmAfter,
      rhythmByCardId: rhythmMap,
      cleanContactStreak: clean ? state.cleanContactStreak + 1 : 0,
      finisherProgress: finisherProgress,
      finisherReady: finisherReady,
      finisherActive: false,
      objectiveProgress: objectiveProgress,
      openGapHits: state.openGapHits + (record.scoredInOpenSector ? 1 : 0),
      perfectContacts:
          state.perfectContacts + (result.tier == TimingTier.perfect ? 1 : 0),
      inputEnabled: false,
      swingLocked: true,
      timingErrorMs: result.timingErrorMs,
      normalizedTimingError: result.normalizedError,
      timingTier: result.tier,
      shotSector: result.sector,
      shotPower: result.power,
      lastOutcome: result.outcome,
      summary: summary,
    );
    emit(nextState);
    if (after.isComplete) {
      final stats = await _storage.loadSuperOverStats();
      final isNewRecord = config.mode == SuperOverMode.scoreAttack
          ? after.score > stats.scoreAttackHighScore
          : after.score > stats.highScore;
      summary = _engine.buildSummary(
        config: config,
        target: config.mode == SuperOverMode.chase ? state.cpuTarget : null,
        position: after,
        objective: state.objective,
        ballRecords: records,
        isNewRecord: isNewRecord,
        completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      final archetypes = {
        for (final card in state.battingOrder)
          card.id: _engine.battingStyleFor(card),
      };
      final settled = stats.recordCompletedMatch(
        summary,
        battingArchetypes: archetypes,
      );
      await _storage.saveSuperOverStats(settled);
      await _storage.clearSuperOverMatchSnapshot();
      if (isNewRecord) emit(nextState.copyWith(summary: summary));
    }
  }

  Future<void> _onNextBallRequested(
    SuperOverNextBallRequested event,
    Emitter<SuperOverState> emit,
  ) async {
    if (state.isOver || state.config == null) return;
    final committed = _engine.commitNextBall(
      config: state.config!,
      completedBalls: state.ballRecords,
      target: state.mode == SuperOverMode.chase ? state.cpuTarget : null,
    );
    final useFinisher = state.finisherReady;
    final next = state.copyWith(
      flowPhase: SuperOverFlowPhase.playing,
      playPhase: SuperOverPlayPhase.fieldReveal,
      phase: SuperOverPhase.ballSetup,
      fieldSectors: committed.fieldPlan.sectorCounts,
      fieldPlan: committed.fieldPlan,
      committedBall: committed,
      deliveryPlan: committed.delivery,
      inputEnabled: false,
      swingLocked: false,
      finisherReady: false,
      finisherActive: useFinisher,
      onFire: useFinisher,
      timingErrorMs: null,
      normalizedTimingError: null,
      timingTier: null,
      shotSector: null,
      shotPower: null,
      lastOutcome: null,
      summary: null,
      confidence: state.rhythmByCardId[state.strikerCardId] ?? 0,
    );
    emit(next);
    await _saveBoundarySnapshot(next);
  }

  Future<void> _onPaused(
    SuperOverPaused event,
    Emitter<SuperOverState> emit,
  ) async {
    if (state.isOver) return;
    emit(
      state.copyWith(
        flowPhase: SuperOverFlowPhase.paused,
        phase: SuperOverPhase.paused,
        inputEnabled: false,
      ),
    );
    await _saveBoundarySnapshot(state);
  }

  void _onResumed(SuperOverResumed event, Emitter<SuperOverState> emit) {
    if (state.isOver) return;
    emit(
      state.copyWith(
        flowPhase: SuperOverFlowPhase.playing,
        phase: SuperOverPhase.ballSetup,
        playPhase: SuperOverPlayPhase.fieldReveal,
        inputEnabled: false,
        swingLocked: false,
      ),
    );
  }

  Future<void> _onSettingsChanged(
    SuperOverSettingsChanged event,
    Emitter<SuperOverState> emit,
  ) async {
    final settings = event.settings;
    emit(state.copyWith(settings: settings));
    final stats = await _storage.loadSuperOverStats();
    await _storage.saveSuperOverStats(
      stats.copyWith(settings: settings, difficulty: settings.difficulty),
    );
  }

  Future<void> _onReset(
    SuperOverReset event,
    Emitter<SuperOverState> emit,
  ) async {
    await _storage.clearSuperOverMatchSnapshot();
    emit(
      SuperOverState(
        flowPhase: event.toLanding
            ? SuperOverFlowPhase.landing
            : SuperOverFlowPhase.preMatch,
        settings: state.settings,
        jersey: state.jersey,
        mode: state.mode,
      ),
    );
  }

  Future<void> _onJerseySelected(
    SuperOverJerseySelected event,
    Emitter<SuperOverState> emit,
  ) async {
    emit(state.copyWith(jersey: event.jersey));
    final stats = await _storage.loadSuperOverStats();
    await _storage.saveSuperOverStats(stats.copyWith(lastJersey: event.jersey));
  }

  Future<void> _saveBoundarySnapshot(SuperOverState value) async {
    final config = value.config;
    final committed = value.committedBall;
    if (config == null || committed == null || value.isOver) return;
    final snapshot = SuperOverMatchSnapshot(
      config: config,
      target: config.mode == SuperOverMode.chase ? value.cpuTarget : null,
      objective: value.objective,
      score: value.score,
      wickets: value.wickets,
      strikerIndex: value.strikerIndex,
      nonStrikerIndex: value.nonStrikerIndex,
      rhythmByCardId: value.rhythmByCardId,
      finisherReady: value.finisherReady || value.finisherActive,
      combo: value.combo,
      maxCombo: value.maxCombo,
      ballRecords: value.ballRecords,
      committedBall: committed,
      selectedSector: value.selectedSector,
      selectedShotStyle: value.selectedShotStyle,
      playPhase: SuperOverPlayPhase.fieldReveal,
      savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _storage.saveSuperOverMatchSnapshot(snapshot);
  }
}
