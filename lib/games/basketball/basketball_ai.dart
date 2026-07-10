/// Hoop Duel CPU controller.
///
/// The AI produces the same [BasketballIntent]s a thumb would — every rule
/// gate stays in the engine, so the AI cannot cheat structurally. It reads
/// the opponent and ball through a perception buffer delayed by a
/// difficulty-dependent latency (it never sees inputs, only observable
/// state), reads its OWN body directly (proprioception), and its timing is
/// blurred by gaussian jitter. Difficulty touches only latency, jitter,
/// decision quality and fake discipline. Pure Dart.
library;

import 'dart:collection';
import 'dart:math';

import '../../models/basketball.dart';
import 'basketball_engine.dart';
import 'basketball_tuning.dart';

class _Observation {
  _Observation({
    required this.t,
    required this.oppX,
    required this.oppBody,
    required this.oppJump,
    required this.oppJumpT,
    required this.ballPhase,
    required this.holder,
    required this.ballX,
    required this.flightT,
    required this.predictionX,
    required this.predictionT,
  });

  final double t;
  final double oppX;
  final BodyState oppBody;
  final JumpPurpose? oppJump;
  final double oppJumpT;
  final BallPhase ballPhase;
  final int holder;
  final double ballX;
  final double flightT;
  final double? predictionX;
  final double? predictionT;
}

enum _OffensePlan { bringUp, probe, createSpace, attack, pullUp }

class BasketballAI {
  BasketballAI({required this.difficulty, required int seed, this.team = 1})
    : _rng = Random(seed);

  final BasketballDifficulty difficulty;
  final Random _rng;

  /// Which side this AI drives (1 = CPU in normal play).
  final int team;

  final Queue<_Observation> _buffer = Queue();
  double _now = 0;

  _OffensePlan _plan = _OffensePlan.bringUp;
  double _replanT = 0;

  /// Non-null while the action zone is held (accumulated hold seconds).
  double? _holdT;

  /// Scheduled hold-release time for a timed shot/block release.
  double? _releaseAt;
  bool _releaseIsBlock = false;

  double _stealCooldown = 0;
  double _fakeBiteChance = 0;
  bool _fakeBiteInit = false;
  double _wiggleT = 0;
  int _wiggleDir = 1;

  double get _latency => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiLatencyRookie,
    BasketballDifficulty.pro => kBbAiLatencyPro,
    BasketballDifficulty.allStar => kBbAiLatencyAllStar,
  };

  double get _jitter => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiJitterRookie,
    BasketballDifficulty.pro => kBbAiJitterPro,
    BasketballDifficulty.allStar => kBbAiJitterAllStar,
  };

  double get _epsilon => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiEpsilonRookie,
    BasketballDifficulty.pro => kBbAiEpsilonPro,
    BasketballDifficulty.allStar => kBbAiEpsilonAllStar,
  };

  /// Gaussian-ish jitter (sum of two uniforms) around zero.
  double _noise() => (_rng.nextDouble() + _rng.nextDouble() - 1) * _jitter * 2;

  BasketballIntent think(BasketballEngine engine, double dt) {
    _now += dt;
    if (!_fakeBiteInit) {
      _fakeBiteInit = true;
      _fakeBiteChance = switch (difficulty) {
        BasketballDifficulty.rookie => kBbAiBiteRookie,
        BasketballDifficulty.pro => kBbAiBitePro,
        BasketballDifficulty.allStar => kBbAiBiteAllStar,
      };
    }
    _stealCooldown = max(0, _stealCooldown - dt);
    _replanT -= dt;
    _wiggleT -= dt;

    _push(engine);
    final obs = _delayed();
    if (obs == null || engine.playPhase != PlayPhase.live) {
      return _emit(moveAxis: 0);
    }

    final me = engine.bodies[team];
    final onBall = engine.ball.holder == team;

    if (onBall) return _offense(engine, me, obs, dt);
    return _defense(engine, me, obs, dt);
  }

  void _push(BasketballEngine engine) {
    final opp = engine.bodies[1 - team];
    final ball = engine.ball;
    _buffer.addLast(
      _Observation(
        t: _now,
        oppX: opp.x,
        oppBody: opp.body,
        oppJump: opp.jumpPurpose,
        oppJumpT: opp.jumpT,
        ballPhase: ball.phase,
        holder: ball.holder,
        ballX: ball.x,
        flightT: ball.flight?.t ?? -1,
        predictionX: ball.prediction?.landX,
        predictionT: ball.prediction?.tLand,
      ),
    );
    while (_buffer.length > 2 && _buffer.first.t < _now - _latency - 0.05) {
      _buffer.removeFirst();
    }
  }

  _Observation? _delayed() {
    final cutoff = _now - _latency;
    _Observation? result;
    for (final obs in _buffer) {
      if (obs.t <= cutoff) {
        result = obs;
      } else {
        break;
      }
    }
    return result ?? (_buffer.isNotEmpty ? _buffer.first : null);
  }

  // ---------------------------------------------------------------------
  // Offense
  // ---------------------------------------------------------------------

  BasketballIntent _offense(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
    double dt,
  ) {
    final spec = me.spec;

    // Mid-shot: manage the timed release.
    if (me.body == BodyState.gather ||
        (me.airborne && me.jumpPurpose == JumpPurpose.shot)) {
      return _manageShotRelease(engine, me);
    }
    if (me.airborne) return _emit(moveAxis: 0);

    final gap = (obs.oppX - me.x).abs();
    final open = gap > 1.7;
    final oppStaggered = obs.oppBody == BodyState.stagger;
    final oppAirborne =
        obs.oppBody == BodyState.jump && obs.oppJump == JumpPurpose.block;
    final shotClock = engine.shotClock;
    final leading = engine.teams[team].score > engine.teams[1 - team].score;

    // Replan.
    if (_replanT <= 0) {
      _replanT = 0.35 + _rng.nextDouble() * 0.4;
      _plan = _pickPlan(
        engine,
        me,
        open: open,
        oppStaggered: oppStaggered || oppAirborne,
        shotClock: shotClock,
        leading: leading,
      );
      if (_rng.nextDouble() < _epsilon) {
        _plan = _OffensePlan
            .values[_rng.nextInt(_OffensePlan.values.length)];
      }
    }

    switch (_plan) {
      case _OffensePlan.bringUp:
        // Walk it toward the preferred range.
        final targetX = _preferredX(spec);
        if ((me.x - targetX).abs() < 0.2) {
          _plan = _OffensePlan.probe;
          return _emit(moveAxis: 0);
        }
        return _emit(moveAxis: me.x < targetX ? 0.8 : -0.8);

      case _OffensePlan.probe:
        // Leading late: burn clock before making a move (never full stall).
        if (leading && shotClock > 7 && !oppStaggered) {
          return _wiggle();
        }
        return _wiggle();

      case _OffensePlan.createSpace:
        // Step-back for a jumper (guarded), or crossover shake.
        if (gap < 1.4 && _rng.nextDouble() < 0.6) {
          _plan = _OffensePlan.pullUp;
          return _emit(swipeBack: true);
        }
        return _wiggle(fast: true);

      case _OffensePlan.attack:
        // Drive the lane; finish at the rim.
        final d = me.d;
        final wantsDunk = spec.dunk >= 72 && me.stamina >= kBbDunkStaminaGate;
        if (d <= (wantsDunk ? _dunkGateFor(spec) : kBbLayupRange)) {
          if (wantsDunk && me.body == BodyState.drive) {
            // Hold through the gate for the slam.
            return _hold(dt, moveAxis: 1);
          }
          return _tap(moveAxis: 1); // layup
        }
        return _emit(
          moveAxis: 1,
          burst: me.body != BodyState.drive && me.stamina > 25,
        );

      case _OffensePlan.pullUp:
        // Rise for the jumper — the engine's meter does the rest.
        _scheduleShotRelease(me);
        return _hold(dt, moveAxis: 0);
    }
  }

  double _dunkGateFor(BasketballAthlete spec) =>
      spec.trait == BasketballTrait.rimPressure
      ? kBbDunkGateRimPressure
      : kBbDunkGate;

  _OffensePlan _pickPlan(
    BasketballEngine engine,
    BasketballAthleteBody me, {
    required bool open,
    required bool oppStaggered,
    required double shotClock,
    required bool leading,
  }) {
    final spec = me.spec;
    if (shotClock < 3) {
      return me.d < kBbCloseRange ? _OffensePlan.attack : _OffensePlan.pullUp;
    }
    if (oppStaggered) {
      return spec.dunk >= spec.three ? _OffensePlan.attack : _OffensePlan.pullUp;
    }
    // Archetype tendencies.
    final roll = _rng.nextDouble();
    switch (spec.archetype) {
      case BasketballArchetype.sharpshooter:
        if (open && me.d >= kBbCloseRange) return _OffensePlan.pullUp;
        return roll < 0.6 ? _OffensePlan.createSpace : _OffensePlan.probe;
      case BasketballArchetype.slasher:
        if (roll < 0.65) return _OffensePlan.attack;
        return open ? _OffensePlan.pullUp : _OffensePlan.probe;
      case BasketballArchetype.interiorPower:
        if (me.d > kBbCloseRange) return _OffensePlan.attack;
        return roll < 0.55 ? _OffensePlan.attack : _OffensePlan.pullUp;
      case BasketballArchetype.balancedGuard:
        if (open) {
          return me.d < kBbLayupRange + 1
              ? _OffensePlan.attack
              : _OffensePlan.pullUp;
        }
        return roll < 0.4
            ? _OffensePlan.attack
            : roll < 0.7
            ? _OffensePlan.createSpace
            : _OffensePlan.probe;
    }
  }

  /// Preferred shooting distance from the rim, as a court x.
  double _preferredX(BasketballAthlete spec) => switch (spec.archetype) {
    BasketballArchetype.sharpshooter => kBbRimX - kBbArcDist - 0.3,
    BasketballArchetype.slasher => kBbRimX - kBbCloseRange,
    BasketballArchetype.interiorPower => kBbRimX - kBbLayupRange - 0.8,
    BasketballArchetype.balancedGuard => kBbRimX - kBbCloseRange - 0.6,
  };

  void _scheduleShotRelease(BasketballAthleteBody me) {
    if (_releaseAt != null) return;
    final gatherDur = me.spec.trait == BasketballTrait.quickRelease
        ? kBbGatherQuickRelease
        : kBbGatherSeconds;
    final apexFrac = me.spec.trait == BasketballTrait.quickRelease
        ? kBbShotApexQuickRelease
        : kBbShotApexFrac;
    _releaseAt =
        _now + gatherDur + kBbJumpShotDuration * apexFrac + _noise();
    _releaseIsBlock = false;
  }

  BasketballIntent _manageShotRelease(
    BasketballEngine engine,
    BasketballAthleteBody me,
  ) {
    _scheduleShotRelease(me);
    if (_now >= (_releaseAt ?? _now)) {
      return _release();
    }
    return _hold(0.0001, moveAxis: 0);
  }

  // ---------------------------------------------------------------------
  // Defense
  // ---------------------------------------------------------------------

  BasketballIntent _defense(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
    double dt,
  ) {
    // Pending timed block release.
    if (_holdT != null && _releaseIsBlock) {
      if (_now >= (_releaseAt ?? _now)) return _release();
      return _hold(dt, moveAxis: 0);
    }

    // Loose ball / live shot → crash the boards.
    if (obs.ballPhase == BallPhase.loose || obs.ballPhase == BallPhase.shot) {
      return _crashBoards(engine, me, obs);
    }

    final oppHasBall = obs.holder == 1 - team;
    if (!oppHasBall) {
      // Transition — retreat between the (delayed) opponent and the rim.
      final target = obs.oppX + 1.1;
      return _moveToward(me, target.clamp(kBbCourtMinX, kBbRimX - 0.5));
    }

    final oppSpec = engine.bodies[1 - team].spec;
    final gap = (obs.oppX - me.x).abs();

    // Shooter rising (delayed observation): contest or block.
    final shooterUp =
        obs.oppBody == BodyState.gather ||
        (obs.oppBody == BodyState.jump && obs.oppJump == JumpPurpose.shot);
    if (shooterUp && gap <= kBbContestGap) {
      final canBlock =
          me.spec.block >= 60 && gap <= 1.4 && me.stamina > 20;
      if (canBlock && _rng.nextDouble() > _epsilon) {
        // Time the block to the shooter's apex.
        final apexIn =
            kBbJumpShotDuration * kBbShotApexFrac - obs.oppJumpT;
        _releaseAt = _now + max(0.05, apexIn) + _noise();
        _releaseIsBlock = true;
        return _hold(dt, moveAxis: 0);
      }
      return _tap(moveAxis: 0); // grounded contest
    }

    // Pump fake shown: disciplined defenders hold ground, biters jump.
    if (obs.oppBody == BodyState.fake && gap <= 1.6) {
      if (_rng.nextDouble() < _fakeBiteChance * dt * 8) {
        _fakeBiteChance *= 0.6; // it learns within the match
        _releaseAt = _now + 0.1;
        _releaseIsBlock = true;
        return _hold(dt, moveAxis: 0);
      }
    }

    // Steal only when the ball is exposed (and not too often).
    final exposed =
        obs.oppBody == BodyState.crossover || obs.oppBody == BodyState.drive;
    if (exposed &&
        gap <= kBbStealReach + 0.3 &&
        _stealCooldown <= 0 &&
        me.spec.steal >= 45 &&
        _rng.nextDouble() > _epsilon) {
      _stealCooldown = switch (difficulty) {
        BasketballDifficulty.rookie => 2.2,
        BasketballDifficulty.pro => 1.6,
        BasketballDifficulty.allStar => 1.1,
      };
      return _tap(moveAxis: 0);
    }

    // Shadow: sit between the attacker and the rim; respect shooters by
    // pressing up, sag off weak shooters.
    final respect = oppSpec.three >= 75
        ? 0.9
        : oppSpec.three >= 55
        ? 1.2
        : 1.6;
    final targetX = (obs.oppX + respect).clamp(kBbCourtMinX, kBbRimX - 0.4);
    final wantStance = gap < 1.9;
    return _moveToward(me, targetX, stance: wantStance, dt: dt);
  }

  BasketballIntent _crashBoards(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
  ) {
    final landX = obs.predictionX;
    if (landX == null) {
      // No prediction public yet — drift toward the rim.
      return _moveToward(me, kBbRimX - 1.2);
    }
    final gap = (landX - me.x).abs();
    if (gap > 0.35) return _moveToward(me, landX);
    // Time the jump so the apex meets the drop.
    final tLand = engine.ball.prediction?.tLand ?? obs.predictionT ?? 1;
    if (!me.airborne && tLand <= kBbReboundJumpDuration * 0.5 + _noise().abs()) {
      return _tap(moveAxis: 0);
    }
    return _emit(moveAxis: 0);
  }

  // ---------------------------------------------------------------------
  // Intent plumbing (thumb-shaped edges)
  // ---------------------------------------------------------------------

  BasketballIntent _moveToward(
    BasketballAthleteBody me,
    double targetX, {
    bool stance = false,
    double dt = 0,
  }) {
    final delta = targetX - me.x;
    final axis = delta.abs() < 0.12 ? 0.0 : delta.sign;
    if (stance) return _hold(dt, moveAxis: axis * 0.8);
    return _emit(moveAxis: axis);
  }

  BasketballIntent _wiggle({bool fast = false}) {
    if (_wiggleT <= 0) {
      _wiggleT = fast ? 0.16 : 0.5 + _rng.nextDouble() * 0.5;
      _wiggleDir = -_wiggleDir;
    }
    return _emit(moveAxis: _wiggleDir * (fast ? 1.0 : 0.5));
  }

  BasketballIntent _emit({
    double moveAxis = 0,
    bool burst = false,
    bool swipeBack = false,
  }) {
    // Emitting a plain intent releases any stray hold as a no-op tap-safe
    // release only when a release was scheduled; otherwise just drop it.
    _holdT = null;
    _releaseAt = null;
    _releaseIsBlock = false;
    return BasketballIntent(
      moveAxis: moveAxis,
      burst: burst,
      swipeBack: swipeBack,
    );
  }

  BasketballIntent _tap({required double moveAxis}) {
    _holdT = null;
    _releaseAt = null;
    return BasketballIntent(
      moveAxis: moveAxis,
      actionPressed: true,
      actionReleased: true,
      heldSeconds: 0.05,
    );
  }

  BasketballIntent _hold(double dt, {required double moveAxis}) {
    final started = _holdT == null;
    _holdT = (_holdT ?? 0) + dt;
    return BasketballIntent(
      moveAxis: moveAxis,
      actionDown: true,
      actionPressed: started,
      heldSeconds: _holdT!,
    );
  }

  BasketballIntent _release() {
    final held = _holdT ?? 0.2;
    _holdT = null;
    _releaseAt = null;
    _releaseIsBlock = false;
    return BasketballIntent(actionReleased: true, heldSeconds: held);
  }
}
