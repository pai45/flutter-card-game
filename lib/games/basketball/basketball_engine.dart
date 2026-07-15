/// Hoop Duel engine — the pure 1v1 half-court basketball simulation.
///
/// Deterministic given a seed + intent streams (mirrors the Grand Prix
/// engine): players move on a 1D court axis, the ball is 2D (x, height).
/// The Flame layer only renders this state and translates pointers into
/// [BasketballIntent]s; the AI produces the same intents. Every rule gate
/// (dunk rating, lockouts) lives HERE, so the AI cannot cheat
/// structurally. No Flutter/Flame imports.
library;

import 'dart:math';

import '../../models/basketball.dart';
import 'basketball_tuning.dart';

// ---------------------------------------------------------------------------
// Intents (identical API for thumbs and AI)
// ---------------------------------------------------------------------------

class BasketballIntent {
  const BasketballIntent({
    this.moveAxis = 0,
    this.burst = false,
    this.actionDown = false,
    this.actionPressed = false,
    this.actionReleased = false,
    this.heldSeconds = 0,
    this.swipeBack = false,
  });

  static const idle = BasketballIntent();

  /// -1 = away from the hoop, +1 = toward it.
  final double moveAxis;

  /// Edge: double-tap burst on the move pad.
  final bool burst;

  /// Action zone currently held.
  final bool actionDown;

  /// Edge: action press started this tick.
  final bool actionPressed;

  /// Edge: action released this tick.
  final bool actionReleased;

  /// How long the action was held at release (or so far).
  final double heldSeconds;

  /// Edge: swipe away from the hoop inside the action zone.
  final bool swipeBack;
}

// ---------------------------------------------------------------------------
// Simulation state
// ---------------------------------------------------------------------------

enum BodyState {
  idle,
  run,
  drive,
  crossover,
  stepback,
  gather,
  jump,
  land,
  stance,
  lunge,
  contest,
  fake,
  stagger,
  celebrate,
  dejected,
  spin,
}

enum JumpPurpose { shot, layup, dunk, putback, block, rebound }

enum BallPhase { held, shot, loose, dead }

enum PlayPhase { awaiting, live, deadReset, finished }

/// The tap-hold intent 'hold' threshold that separates tap from shot gather.
const double kBbTapThreshold = 0.12;

class BasketballAthleteBody {
  BasketballAthleteBody(this.spec, this.team);

  BasketballAthlete spec;
  final int team;

  double x = 0;
  int facing = 1;
  BodyState body = BodyState.idle;
  double stateT = 0;

  JumpPurpose? jumpPurpose;
  double jumpT = 0;
  double jumpDur = 0;

  double stamina = 100;
  double recoverT = 0;
  double driveT = 0;
  double fakeT = 0;

  /// Ball-exposed window (crossover / drive start) — boosts steals.
  double exposedT = 0;

  /// Put-back quick-shot window after an offensive board.
  double putbackT = 0;

  /// The defender jumped at a pump fake; staggers on landing.
  bool baited = false;

  /// A defender was in the lane when the spin started (the spin had someone
  /// to beat — gates the SPIN CYCLE payoff event).
  bool spinTargeted = false;

  /// Steal lunge has rolled already (one roll per lunge).
  bool lungeRolled = false;

  double lastMoveDir = 0;
  double sinceDirChange = 99;

  bool get airborne => body == BodyState.jump;
  bool get locked =>
      body == BodyState.gather ||
      body == BodyState.jump ||
      body == BodyState.stagger ||
      body == BodyState.stepback ||
      body == BodyState.spin ||
      recoverT > 0;

  double get stamina01 => stamina / 100;

  /// 0..1 vertical jump progress mapped to a sine arc.
  double get jumpHeight => body == BodyState.jump && jumpDur > 0
      ? sin(pi * (jumpT / jumpDur).clamp(0.0, 1.0)) *
            kBbMaxJumpHeight *
            _tiredJump
      : 0;

  double get _tiredJump =>
      kBbTiredJumpFloor + (1 - kBbTiredJumpFloor) * stamina01;

  /// Distance to the rim.
  double get d => kBbRimX - x;

  double get reach =>
      spec.heightM * 1.31 + jumpHeight + (spec.heightM - 1.95) * 0.2;

  void enter(BodyState next) {
    body = next;
    stateT = 0;
  }

  void startJump(JumpPurpose purpose, double duration) {
    jumpPurpose = purpose;
    jumpT = 0;
    jumpDur = duration;
    enter(BodyState.jump);
  }

  void drain(double amount) => stamina = (stamina - amount).clamp(0, 100);
}

class BasketballTeamSim {
  BasketballTeamSim(this.roster, int starterIndex)
    : activeIndex = starterIndex,
      staminas = List<double>.filled(roster.length, 100);

  final List<BasketballAthlete> roster;
  int activeIndex;
  final List<double> staminas;

  int score = 0;
  int unanswered = 0;
  double heatMeter = 0;
  bool heatActive = false;
  double heatT = 0;
}

class ShotFlight {
  ShotFlight({
    required this.make,
    required this.points,
    required this.zone,
    required this.grade,
    required this.shooterTeam,
    required this.duration,
    required this.startX,
    required this.startH,
    required this.releasedBeforeBuzzer,
    this.dunk = false,
  });

  final bool make;
  final int points;
  final ShotZone zone;
  final ReleaseGrade grade;
  final int shooterTeam;
  final double duration;
  final double startX;
  final double startH;
  final bool releasedBeforeBuzzer;
  final bool dunk;
  double t = 0;
}

/// Public rebound prediction — exposed only after rim contact.
class ReboundPrediction {
  const ReboundPrediction(this.landX, this.tLand);

  final double landX;
  final double tLand;
}

class BasketballBall {
  BallPhase phase = BallPhase.dead;

  /// Team index holding the ball, or -1 while loose/in flight.
  int holder = -1;
  double x = kBbCheckSpotX;
  double h = 1.1;
  double vx = 0;
  double vh = 0;
  ShotFlight? flight;
  ReboundPrediction? prediction;
}

/// Shot-meter view for the HUD (null when no meter is running).
class ShotMeterView {
  const ShotMeterView({
    required this.progress,
    required this.perfectCenter,
    required this.perfectHalf,
    required this.goodHalf,
  });

  final double progress;
  final double perfectCenter;
  final double perfectHalf;
  final double goodHalf;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

enum BasketballEventType {
  basketMade,
  shotMissed,
  steal,
  block,
  rebound,
  shotClockViolation,
  heatStarted,
  heatEnded,
  ankleBreaker,
  poster,
  stagger,
  perfectRelease,
  halfEnded,
  overtimeStarted,
  matchEnded,
  substitution,
  dunk,
  shotReleased,
  buzzerBeater,
  spinMove,
  crossover,
}

class BasketballEvent {
  const BasketballEvent(
    this.type, {
    this.team = -1,
    this.points = 0,
    this.zone,
    this.grade,
    this.offensive = false,
    this.halfIndex = 0,
    this.needsOvertime = false,
    this.onDunk = false,
  });

  final BasketballEventType type;
  final int team;
  final int points;
  final ShotZone? zone;
  final ReleaseGrade? grade;
  final bool offensive;
  final int halfIndex;
  final bool needsOvertime;
  final bool onDunk;
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

class BasketballEngine {
  BasketballEngine(this.config)
    : _rng = Random(config.seed),
      teams = [
        BasketballTeamSim(config.playerRoster, config.playerStarterIndex),
        BasketballTeamSim(config.cpuRoster, config.cpuStarterIndex),
      ] {
    bodies = [
      BasketballAthleteBody(
        config.playerRoster[config.playerStarterIndex],
        0,
      ),
      BasketballAthleteBody(config.cpuRoster[config.cpuStarterIndex], 1),
    ];
    _firstPossession = _rng.nextBool() ? 0 : 1;
  }

  final BasketballMatchConfig config;
  final Random _rng;
  final List<BasketballTeamSim> teams;
  late final List<BasketballAthleteBody> bodies;
  final BasketballBall ball = BasketballBall();

  PlayPhase playPhase = PlayPhase.awaiting;
  int halfIndex = 0;
  double halfClock = kBbHalfSeconds;
  double shotClock = kBbShotClockSeconds;
  int possession = 0;
  double resetT = 0;
  bool overtime = false;

  late int _firstPossession;
  bool _buzzerPending = false;
  bool _matchOver = false;
  double _looseSeconds = 0;

  // Player-team box score accumulation.
  int _attempts = 0;
  int _makes = 0;
  int _threes = 0;
  int _perfects = 0;
  int _dunks = 0;
  int _blocks = 0;
  int _steals = 0;
  int _rebounds = 0;
  int _turnovers = 0;
  int _bestRun = 0;

  /// Repeat-shot penalty stacks per team, keyed by coarse zone bucket.
  final List<ShotZone?> _lastMakeZone = [null, null];
  final List<int> _repeatStacks = [0, 0];

  List<BasketballEvent> _events = [];

  bool get matchOver => _matchOver;

  BasketballAthleteBody get playerBody => bodies[0];
  BasketballAthleteBody get cpuBody => bodies[1];

  /// Court x of the three-point arc line (feet on/behind = a 3). Used to draw
  /// the arc and to decide 2 vs 3 at release.
  static const double arcLineX = kBbRimX - kBbArcDist;

  // -------------------------------------------------------------------------
  // Match flow API (cubit-driven)
  // -------------------------------------------------------------------------

  void startHalf(int index) {
    halfIndex = index;
    overtime = index >= 2;
    halfClock = overtime ? 0 : kBbHalfSeconds;
    possession = switch (index) {
      0 => _firstPossession,
      1 => 1 - _firstPossession,
      _ => _rng.nextBool() ? 0 : 1,
    };
    _buzzerPending = false;
    _placeForPossession();
    shotClock = kBbShotClockSeconds;
    playPhase = PlayPhase.live;
  }

  void substitute(int team, int rosterIndex) {
    final sim = teams[team];
    if (rosterIndex < 0 ||
        rosterIndex >= sim.roster.length ||
        rosterIndex == sim.activeIndex) {
      return;
    }
    // Store the outgoing athlete's stamina, bring the sub in fresh-legged.
    sim.staminas[sim.activeIndex] = bodies[team].stamina;
    sim.activeIndex = rosterIndex;
    final body = BasketballAthleteBody(sim.roster[rosterIndex], team);
    body.stamina = sim.staminas[rosterIndex];
    body.x = bodies[team].x;
    bodies[team] = body;
  }

  /// Bench regeneration + active top-up at halftime.
  void halftimeRest() {
    for (var t = 0; t < 2; t++) {
      final sim = teams[t];
      for (var i = 0; i < sim.staminas.length; i++) {
        sim.staminas[i] = 100;
      }
      bodies[t].stamina = (bodies[t].stamina + kBbHalftimeActiveRegen).clamp(
        0,
        100,
      );
    }
  }

  BasketballMatchSummary summary({bool abandoned = false}) =>
      BasketballMatchSummary(
        playerScore: teams[0].score,
        cpuScore: teams[1].score,
        overtime: overtime,
        difficulty: config.difficulty,
        buzzerBeater: _endedOnBuzzer,
        abandoned: abandoned,
        box: BasketballBoxScore(
          attempts: _attempts,
          makes: _makes,
          threesMade: _threes,
          perfectReleases: _perfects,
          dunks: _dunks,
          blocks: _blocks,
          steals: _steals,
          rebounds: _rebounds,
          turnovers: _turnovers,
          bestRun: _bestRun,
        ),
      );

  bool _endedOnBuzzer = false;

  ShotMeterView? meterView(int team) {
    final body = bodies[team];
    if (body.body == BodyState.gather && body.jumpPurpose == JumpPurpose.shot) {
      return ShotMeterView(
        progress: 0,
        perfectCenter: _apexFrac(body),
        perfectHalf: perfectHalfWindow(body) / kBbJumpShotDuration,
        goodHalf: kBbGoodHalfWindow / kBbJumpShotDuration,
      );
    }
    if (body.body == BodyState.jump &&
        body.jumpPurpose == JumpPurpose.shot &&
        ball.holder == team) {
      return ShotMeterView(
        progress: (body.jumpT / body.jumpDur).clamp(0.0, 1.0),
        perfectCenter: _apexFrac(body),
        perfectHalf: perfectHalfWindow(body) / body.jumpDur,
        goodHalf: kBbGoodHalfWindow / body.jumpDur,
      );
    }
    return null;
  }

  double _apexFrac(BasketballAthleteBody body) =>
      body.spec.trait == BasketballTrait.quickRelease
      ? kBbShotApexQuickRelease
      : kBbShotApexFrac;

  /// Perfect half-window in seconds for this body right now.
  double perfectHalfWindow(BasketballAthleteBody body) {
    final rating = body.spec.ratingFor(zoneFor(body.d));
    final contest = _contestOn(body);
    var half =
        kBbPerfectHalfWindow *
        (0.7 + 0.5 * ((rating - 50) / 50).clamp(0.0, 1.0)) *
        _lerp(kBbTiredWindowFloor, 1.0, (body.stamina01 / 0.6).clamp(0.0, 1.0)) *
        (1 - 0.25 * contest);
    if (teams[body.team].heatActive) half *= kBbHeatWindowMult;
    if (body.spec.trait == BasketballTrait.quickRelease) half *= 1.15;
    return half;
  }

  // -------------------------------------------------------------------------
  // step
  // -------------------------------------------------------------------------

  List<BasketballEvent> step(
    BasketballIntent player,
    BasketballIntent cpu,
    double dt,
  ) {
    _events = [];
    if (playPhase == PlayPhase.awaiting || playPhase == PlayPhase.finished) {
      return _events;
    }

    _advanceTimers(dt);

    if (playPhase == PlayPhase.deadReset) {
      _stepDeadReset(dt);
      return _events;
    }

    final intents = [player, cpu];
    for (var t = 0; t < 2; t++) {
      final onOffense = ball.holder == t;
      if (onOffense) {
        _resolveOffense(bodies[t], intents[t]);
      } else {
        _resolveDefense(bodies[t], intents[t]);
      }
      _integrateMovement(bodies[t], intents[t], dt);
    }
    _separateBodies();
    _stepBall(dt);
    _stepClocks(dt);
    return _events;
  }

  // -------------------------------------------------------------------------
  // Timers & states
  // -------------------------------------------------------------------------

  void _advanceTimers(double dt) {
    for (final body in bodies) {
      body.stateT += dt;
      body.sinceDirChange += dt;
      if (body.recoverT > 0) body.recoverT = max(0, body.recoverT - dt);
      if (body.exposedT > 0) body.exposedT = max(0, body.exposedT - dt);
      if (body.putbackT > 0) body.putbackT = max(0, body.putbackT - dt);

      switch (body.body) {
        case BodyState.fake:
          if (body.stateT >= kBbFakeSeconds) body.enter(BodyState.idle);
        case BodyState.crossover:
          if (body.stateT >= kBbCrossoverDuration) body.enter(BodyState.run);
        case BodyState.stepback:
          if (body.stateT >= kBbStepbackDuration) {
            // Step-back flows straight into a gather (shooting space).
            _beginGather(body);
          }
        case BodyState.stagger:
          if (body.stateT >= kBbStaggerSeconds) body.enter(BodyState.idle);
        case BodyState.celebrate:
        case BodyState.dejected:
          if (body.stateT >= kBbReactSeconds) body.enter(BodyState.idle);
        case BodyState.spin:
          if (body.stateT >= kBbSpinDuration) {
            final defender = bodies[1 - body.team];
            final setDefender =
                defender.body == BodyState.stance ||
                defender.body == BodyState.contest;
            // Ending the turn on top of a planted body = the defender held
            // their ground. To beat a set stance the spin must be launched
            // close enough to carry fully PAST it — a timing skill.
            if (setDefender &&
                (defender.x - body.x).abs() <= kBbBodyGap * 1.4) {
              body.enter(BodyState.idle);
              body.recoverT = kBbSpinAbsorbRecover;
            } else {
              body.driveT = kBbSpinCarryDrive;
              body.enter(BodyState.drive);
              if (body.spinTargeted &&
                  (defender.x - body.x) * body.facing < 0) {
                _emit(
                  BasketballEvent(
                    BasketballEventType.spinMove,
                    team: body.team,
                  ),
                );
              }
            }
            body.spinTargeted = false;
          }
        case BodyState.lunge:
          if (body.stateT >= 0.35) {
            body.enter(BodyState.idle);
            if (!body.lungeRolled) body.recoverT = kBbWhiffRecover;
          }
        case BodyState.land:
          if (body.stateT >= 0.18) body.enter(BodyState.idle);
        case BodyState.gather:
          final gatherDur =
              body.spec.trait == BasketballTrait.quickRelease
              ? kBbGatherQuickRelease
              : kBbGatherSeconds;
          if (body.stateT >= gatherDur) {
            body.startJump(body.jumpPurpose ?? JumpPurpose.shot, _jumpDurFor(
              body.jumpPurpose ?? JumpPurpose.shot,
            ));
          }
        case BodyState.jump:
          body.jumpT += dt;
          _stepJump(body);
        case BodyState.drive:
          body.driveT -= dt;
          body.drain(kBbDrainDrivePerSec * dt * _heatDrain(body.team));
          if (body.driveT <= 0) body.enter(BodyState.run);
        case BodyState.stance:
          body.drain(kBbDrainStancePerSec * dt * _heatDrain(body.team));
        default:
          break;
      }

      // Calm regeneration. Reaction beats count as calm so the reset-walk
      // regen is unchanged from before reactions existed.
      final calm =
          body.body == BodyState.idle ||
          body.body == BodyState.celebrate ||
          body.body == BodyState.dejected ||
          (body.body == BodyState.run && body.lastMoveDir == 0);
      if (calm) {
        final rate = playPhase == PlayPhase.deadReset
            ? kBbRegenResetPerSec
            : kBbRegenCalmPerSec;
        body.stamina = (body.stamina + rate * dt * (0.8 + body.spec.stamina / 250))
            .clamp(0, 100);
      }
    }

    for (var t = 0; t < 2; t++) {
      final team = teams[t];
      if (team.heatActive) {
        team.heatT -= dt;
        if (team.heatT <= 0) {
          team.heatActive = false;
          team.heatMeter = 0;
          _emit(BasketballEvent(BasketballEventType.heatEnded, team: t));
        }
      }
    }
  }

  double _heatDrain(int team) =>
      teams[team].heatActive ? kBbHeatDrainMult : 1.0;

  double _jumpDurFor(JumpPurpose purpose) => switch (purpose) {
    JumpPurpose.shot => kBbJumpShotDuration,
    JumpPurpose.layup || JumpPurpose.putback => kBbLayupDuration,
    JumpPurpose.dunk => kBbDunkDuration,
    JumpPurpose.block => kBbBlockJumpDuration,
    JumpPurpose.rebound => kBbReboundJumpDuration,
  };

  void _stepJump(BasketballAthleteBody body) {
    final purpose = body.jumpPurpose;
    final apex = body.jumpDur * 0.5;

    // Layups/dunks/put-backs auto-release at their apex.
    if (ball.holder == body.team &&
        body.jumpT >= apex &&
        (purpose == JumpPurpose.layup ||
            purpose == JumpPurpose.dunk ||
            purpose == JumpPurpose.putback)) {
      _releaseShot(body, auto: true);
    }

    // Rebound grab attempt through the jump.
    if (purpose == JumpPurpose.rebound && ball.phase == BallPhase.loose) {
      _tryGrab(body);
    }

    if (body.jumpT >= body.jumpDur) {
      // Shot jump that never released: auto Late release at landing.
      if (ball.holder == body.team && purpose == JumpPurpose.shot) {
        _releaseShot(body, forcedLate: true);
      }
      final wasBaited = body.baited;
      body.baited = false;
      body.jumpPurpose = null;
      if (wasBaited) {
        body.enter(BodyState.stagger);
        _emit(BasketballEvent(BasketballEventType.stagger, team: body.team));
      } else {
        body.enter(BodyState.land);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Offense resolution (deterministic priority table)
  // -------------------------------------------------------------------------

  void _resolveOffense(BasketballAthleteBody body, BasketballIntent intent) {
    if (playPhase != PlayPhase.live) return;

    // O1.5 — spin move: a second double-tap mid-drive whips past the defender.
    // Deterministic counterplay: a defender holding a set stance in the lane
    // absorbs the spin (resolved in _advanceTimers) — no RNG rolls.
    if (intent.burst &&
        body.body == BodyState.drive &&
        !body.airborne &&
        body.stamina >= kBbSpinStaminaCost) {
      final defender = bodies[1 - body.team];
      body.drain(kBbSpinStaminaCost);
      body.exposedT = kBbSpinExposed;
      body.spinTargeted =
          (defender.x - body.x) * body.facing > 0 &&
          (defender.x - body.x).abs() <= 1.6;
      body.enter(BodyState.spin);
      return;
    }

    // Burst drive.
    if (intent.burst &&
        !body.locked &&
        body.stamina >= kBbBurstStaminaCost &&
        body.body != BodyState.drive) {
      body.driveT = kBbDriveDuration;
      body.exposedT = 0.15;
      body.drain(kBbBurstStaminaCost * 0.4);
      body.enter(BodyState.drive);
    }

    // O1 — step-back.
    if (intent.swipeBack && !body.locked && !body.airborne) {
      body.drain(kBbDrainCrossover);
      body.jumpPurpose = JumpPurpose.shot;
      body.enter(BodyState.stepback);
      return;
    }

    // O3 — dunk: hold while driving inside the gate.
    if (intent.actionDown &&
        body.body == BodyState.drive &&
        body.d <= _dunkGate(body) &&
        !body.airborne) {
      if (body.spec.dunk >= 72 &&
          body.stamina >= kBbDunkStaminaGate &&
          _laneClear(body)) {
        body.drain(kBbDrainDunk);
        body.startJump(JumpPurpose.dunk, kBbDunkDuration);
      } else {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.layup, kBbLayupDuration);
      }
      return;
    }

    // O2 — held past the tap threshold: begin the shot gather. Holding
    // through a drive is reserved for the dunk gate (O3) until the drive ends.
    if (intent.actionDown &&
        intent.heldSeconds >= kBbTapThreshold &&
        !body.locked &&
        !body.airborne &&
        body.body != BodyState.drive &&
        body.body != BodyState.gather) {
      body.jumpPurpose = JumpPurpose.shot;
      _beginGather(body);
      return;
    }

    // O7 — release the shot.
    if (intent.actionReleased &&
        (body.body == BodyState.gather ||
            (body.airborne && body.jumpPurpose == JumpPurpose.shot))) {
      _releaseShot(body);
      return;
    }

    if (intent.actionReleased && intent.heldSeconds < kBbTapThreshold) {
      // O6 — put-back.
      if (body.putbackT > 0 && body.d <= kBbLayupRange && !body.airborne) {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.putback, kBbLayupDuration);
        return;
      }
      // O4 — layup on the move near the rim.
      final moving =
          body.body == BodyState.run || body.body == BodyState.drive;
      if (moving && body.d <= kBbLayupRange && !body.airborne) {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.layup, kBbLayupDuration);
        return;
      }
      // O5 — pump fake while set.
      if (!body.locked && !body.airborne) {
        body.enter(BodyState.fake);
        return;
      }
    }
  }

  double _dunkGate(BasketballAthleteBody body) =>
      body.spec.trait == BasketballTrait.rimPressure
      ? kBbDunkGateRimPressure
      : kBbDunkGate;

  bool _laneClear(BasketballAthleteBody body) {
    final defender = bodies[1 - body.team];
    if (defender.body != BodyState.stance &&
        defender.body != BodyState.contest &&
        !defender.airborne) {
      return true;
    }
    // A set defender between the driver and the rim blocks the lane.
    final between = defender.x > body.x && defender.x < kBbRimX;
    return !(between && (defender.x - body.x).abs() < 0.9);
  }

  void _beginGather(BasketballAthleteBody body) {
    body.drain(kBbDrainJumpShot);
    body.jumpPurpose = JumpPurpose.shot;
    body.enter(BodyState.gather);
  }

  // -------------------------------------------------------------------------
  // Defense resolution
  // -------------------------------------------------------------------------

  void _resolveDefense(BasketballAthleteBody body, BasketballIntent intent) {
    if (playPhase != PlayPhase.live) return;
    final attacker = bodies[1 - body.team];
    final gap = (attacker.x - body.x).abs();

    // Sustained hold near the handler = stance; hold + release = block jump.
    if (intent.actionDown && !body.locked && !body.airborne) {
      if (body.body != BodyState.stance && gap <= 1.8) {
        body.enter(BodyState.stance);
      }
    } else if (body.body == BodyState.stance && !intent.actionDown &&
        !intent.actionReleased) {
      body.enter(BodyState.idle);
    }

    if (intent.actionReleased && intent.heldSeconds >= 0.16 && !body.locked) {
      // D3 — block jump, but only against a rising/faking shooter or a ball
      // that just left the hand. Releasing a plain stance hold stays grounded.
      final shooterThreat =
          attacker.body == BodyState.gather ||
          attacker.body == BodyState.fake ||
          (attacker.airborne &&
              (attacker.jumpPurpose == JumpPurpose.shot ||
                  attacker.jumpPurpose == JumpPurpose.layup ||
                  attacker.jumpPurpose == JumpPurpose.dunk ||
                  attacker.jumpPurpose == JumpPurpose.putback)) ||
          (ball.phase == BallPhase.shot &&
              (ball.flight?.t ?? 99) <= kBbBlockSyncWindow);
      if (shooterThreat && body.stamina >= kBbDrainBlockJump) {
        body.drain(kBbDrainBlockJump);
        if (attacker.body == BodyState.fake) body.baited = true;
        body.startJump(JumpPurpose.block, kBbBlockJumpDuration);
        _tryBlockInFlight(body);
      } else if (body.body == BodyState.stance) {
        body.enter(BodyState.idle);
      }
      return;
    }

    if (intent.actionReleased && intent.heldSeconds < kBbTapThreshold) {
      // Taps resolve top-down: rebound → contest → steal → whiff.
      if (body.locked || body.airborne) return;

      // D1 — rebound jump at a loose or descending ball.
      final ballComing =
          ball.phase == BallPhase.loose ||
          (ball.phase == BallPhase.shot &&
              ball.flight != null &&
              ball.flight!.t / ball.flight!.duration > 0.55);
      if (ballComing) {
        body.drain(kBbDrainReboundJump);
        body.startJump(JumpPurpose.rebound, kBbReboundJumpDuration);
        return;
      }

      // D2 — grounded contest while the shooter gathers/rises.
      final shooterUp =
          attacker.body == BodyState.gather ||
          (attacker.airborne && attacker.jumpPurpose == JumpPurpose.shot);
      if (shooterUp && gap <= kBbContestGap) {
        body.drain(kBbDrainContest);
        body.enter(BodyState.contest);
        return;
      }

      // D4 — steal lunge.
      if (ball.holder == attacker.team && gap <= kBbStealReach + 0.4) {
        body.drain(kBbDrainLunge);
        body.lungeRolled = false;
        body.enter(BodyState.lunge);
        return;
      }

      // D5 — whiff.
      body.drain(kBbDrainLunge);
      body.lungeRolled = false;
      body.enter(BodyState.lunge);
    }

    // Steal roll during the lunge's active frames.
    if (body.body == BodyState.lunge &&
        !body.lungeRolled &&
        body.stateT >= kBbStealActiveFrom &&
        body.stateT <= kBbStealActiveTo &&
        ball.holder == attacker.team) {
      final reach = (attacker.x - body.x).abs() <= kBbStealReach;
      if (reach) {
        body.lungeRolled = true;
        _rollSteal(body, attacker);
      }
    }

    // Contest state relaxes once the shot resolves.
    if (body.body == BodyState.contest && body.stateT > 0.5) {
      body.enter(BodyState.idle);
    }
  }

  void _rollSteal(
    BasketballAthleteBody defender,
    BasketballAthleteBody handler,
  ) {
    final exposed = handler.exposedT > 0 || handler.body == BodyState.crossover;
    final guarded = (handler.x - defender.x).abs() <= kBbGuardedGap;
    final protected =
        guarded && handler.body != BodyState.drive && !exposed;
    var p =
        kBbStealBase +
        (defender.spec.steal - 70) * kBbStealRatingSlope +
        (exposed ? kBbStealExposedBonus : 0) -
        (protected ? kBbStealProtectedPenalty : 0) -
        (handler.spec.handling - 70) * 0.003;
    p = p.clamp(0.03, 0.85);
    if (_rng.nextDouble() < p) {
      _turnover(to: defender.team, steal: true);
      defender.enter(BodyState.idle);
      if (defender.team == 0) _steals++;
      if (handler.team == 0) _turnovers++;
      teams[defender.team].heatMeter = (teams[defender.team].heatMeter +
              kBbHeatPerStop)
          .clamp(0.0, 1.0);
      _maybeIgniteHeat(defender.team);
      _emit(BasketballEvent(BasketballEventType.steal, team: defender.team));
    }
  }

  // -------------------------------------------------------------------------
  // Movement
  // -------------------------------------------------------------------------

  void _integrateMovement(
    BasketballAthleteBody body,
    BasketballIntent intent,
    double dt,
  ) {
    // Scripted step-back slide.
    if (body.body == BodyState.stepback) {
      body.x -= kBbStepbackDistance * (dt / kBbStepbackDuration);
      body.x = body.x.clamp(kBbCourtMinX, kBbCourtMaxX);
      return;
    }
    // Scripted spin slide — the turn carries the handler forward.
    if (body.body == BodyState.spin) {
      body.x = (body.x + body.facing * kBbBaseSpeed * kBbSpinSpeedMult * dt)
          .clamp(kBbCourtMinX, kBbCourtMaxX);
      return;
    }
    if (body.locked || body.airborne || playPhase != PlayPhase.live) {
      return;
    }
    // Lunge carries a small forward step toward the attacker.
    if (body.body == BodyState.lunge) {
      final attacker = bodies[1 - body.team];
      final dir = (attacker.x - body.x).sign;
      body.x += dir * 1.6 * dt;
      return;
    }

    final axis = intent.moveAxis.clamp(-1.0, 1.0);

    // Crossover: quick direction flip while moving with the ball.
    if (axis != 0 &&
        body.lastMoveDir != 0 &&
        axis.sign != body.lastMoveDir.sign &&
        body.sinceDirChange <= kBbCrossoverWindow &&
        ball.holder == body.team &&
        (body.body == BodyState.run || body.body == BodyState.drive)) {
      body.drain(kBbDrainCrossover);
      body.exposedT = 0.12;
      body.enter(BodyState.crossover);
      _emit(BasketballEvent(BasketballEventType.crossover, team: body.team));
      _checkAnkleBreaker(body);
    }
    if (axis != 0 && axis.sign != body.lastMoveDir.sign) {
      body.sinceDirChange = 0;
    }
    body.lastMoveDir = axis;
    if (axis != 0) body.facing = axis > 0 ? 1 : -1;

    var speed =
        kBbBaseSpeed *
        (0.8 + 0.4 * ((body.spec.speed - 30) / 69).clamp(0.0, 1.0)) *
        _lerp(kBbTiredSpeedFloor, 1.0, body.stamina01);
    if (teams[body.team].heatActive) speed *= kBbHeatSpeedMult;
    switch (body.body) {
      case BodyState.drive:
        speed *= kBbDriveMult;
      case BodyState.stance:
        speed *= kBbStanceMult;
      case BodyState.crossover:
        speed *= 1.15;
      default:
        break;
    }
    // Guarded auto ball-protection: slower but steal-resistant.
    if (ball.holder == body.team &&
        body.body != BodyState.drive &&
        (bodies[1 - body.team].x - body.x).abs() <= kBbGuardedGap) {
      speed *= kBbProtectMult;
    }

    if (axis != 0 &&
        (body.body == BodyState.idle || body.body == BodyState.land)) {
      body.enter(BodyState.run);
    } else if (axis == 0 && body.body == BodyState.run) {
      body.enter(BodyState.idle);
    }

    body.x = (body.x + axis * speed * dt).clamp(kBbCourtMinX, kBbCourtMaxX);
  }

  void _checkAnkleBreaker(BasketballAthleteBody handler) {
    final defender = bodies[1 - handler.team];
    final gap = (handler.x - defender.x).abs();
    if (gap > 1.3) return;
    final overcommitted =
        defender.body == BodyState.lunge ||
        (defender.body == BodyState.stance &&
            defender.lastMoveDir != 0 &&
            defender.lastMoveDir.sign != handler.lastMoveDir.sign);
    if (overcommitted) {
      defender.enter(BodyState.stagger);
      _emit(
        BasketballEvent(BasketballEventType.ankleBreaker, team: handler.team),
      );
    }
  }

  void _separateBodies() {
    final a = bodies[0];
    final b = bodies[1];
    // A spinning handler rotates around the defender's body rather than
    // bulldozing them — separation is suspended for the spin's duration.
    if (a.body == BodyState.spin || b.body == BodyState.spin) return;
    final dx = b.x - a.x;
    if (dx.abs() >= kBbBodyGap || dx == 0) return;
    final overlap = kBbBodyGap - dx.abs();
    final dir = dx.sign;
    // Heavier bodies hold their ground.
    double wa = b.spec.heightM / (a.spec.heightM + b.spec.heightM);
    double wb = 1 - wa;

    // Fix: When fighting for a loose ball, the player closer to the ball establishes
    // position and cannot be bulldozed from behind by the opponent.
    if (ball.phase == BallPhase.loose || ball.phase == BallPhase.shot) {
      final aDist = (a.x - ball.x).abs();
      final bDist = (b.x - ball.x).abs();
      if (aDist < bDist - 0.1 && (b.x - a.x).sign == b.lastMoveDir.sign) {
        wa = 0.05;
        wb = 0.95;
      } else if (bDist < aDist - 0.1 && (a.x - b.x).sign == a.lastMoveDir.sign) {
        wa = 0.95;
        wb = 0.05;
      }
    }

    a.x = (a.x - dir * overlap * wa).clamp(kBbCourtMinX, kBbCourtMaxX);
    b.x = (b.x + dir * overlap * wb).clamp(kBbCourtMinX, kBbCourtMaxX);
  }

  // -------------------------------------------------------------------------
  // Shooting
  // -------------------------------------------------------------------------

  ShotZone zoneFor(double d) {
    if (d <= kBbDunkGate) return ShotZone.dunk;
    if (d <= kBbLayupRange) return ShotZone.layup;
    if (d <= kBbCloseRange) return ShotZone.close;
    if (d < kBbArcDist) return ShotZone.mid;
    return ShotZone.three;
  }

  /// Contest factor 0..1 on a shooter from the opposing defender.
  double _contestOn(BasketballAthleteBody shooter) {
    final defender = bodies[1 - shooter.team];
    final gap = (defender.x - shooter.x).abs();
    final proximity = (1 - gap / kBbContestRange).clamp(0.0, 1.0);
    final arms = switch (defender.body) {
      BodyState.stance || BodyState.contest => 1.0,
      BodyState.jump when defender.jumpPurpose == JumpPurpose.block => 1.3,
      _ => 0.5,
    };
    final height = 1 + (defender.spec.heightM - 1.95) * 0.3;
    return (proximity * arms * height).clamp(0.0, 1.3);
  }

  void _releaseShot(
    BasketballAthleteBody body, {
    bool auto = false,
    bool forcedLate = false,
  }) {
    if (ball.holder != body.team) return;
    final purpose = body.jumpPurpose ?? JumpPurpose.shot;

    // Grade the release.
    ReleaseGrade grade;
    if (forcedLate) {
      grade = ReleaseGrade.late;
    } else if (auto) {
      grade = ReleaseGrade.good;
    } else if (body.body == BodyState.gather) {
      // Released before the jump even started.
      body.startJump(JumpPurpose.shot, kBbJumpShotDuration);
      grade = ReleaseGrade.early;
    } else {
      final apexT = body.jumpDur * _apexFrac(body);
      final offset = body.jumpT - apexT;
      final half = perfectHalfWindow(body);
      if (offset.abs() <= half) {
        grade = ReleaseGrade.perfect;
      } else if (offset.abs() <= half + kBbGoodHalfWindow) {
        grade = ReleaseGrade.good;
      } else {
        grade = offset < 0 ? ReleaseGrade.early : ReleaseGrade.late;
      }
    }

    final releaseX = body.x;
    final d = kBbRimX - releaseX;
    var zone = purpose == JumpPurpose.dunk
        ? ShotZone.dunk
        : purpose == JumpPurpose.layup || purpose == JumpPurpose.putback
        ? ShotZone.layup
        : zoneFor(d);
    // A jump shot from point blank still counts as a layup-range attempt.
    if (zone == ShotZone.dunk && purpose == JumpPurpose.shot) {
      zone = ShotZone.layup;
    }
    final points = zone == ShotZone.three ? 3 : 2;

    // Block check at release.
    final defender = bodies[1 - body.team];
    final blocked = _blockConnects(defender, body);

    // Make roll.
    final isDunk = purpose == JumpPurpose.dunk;
    bool make;
    if (blocked) {
      make = false;
    } else if (isDunk) {
      make = true;
    } else {
      make = _rng.nextDouble() < makeProbability(body, zone, grade, purpose);
    }

    if (body.team == 0) {
      _attempts++;
      if (grade == ReleaseGrade.perfect) _perfects++;
    }
    if (grade == ReleaseGrade.perfect) {
      _emit(
        BasketballEvent(BasketballEventType.perfectRelease, team: body.team),
      );
    }

    final releasedBeforeBuzzer = overtime || halfClock > 0;
    final startH = body.spec.heightM + body.jumpHeight + 0.3;
    final duration = isDunk
        ? 0.22
        : (0.42 + d.abs() * 0.055).clamp(0.3, 0.95);

    ball.phase = BallPhase.shot;
    ball.holder = -1;
    ball.x = releaseX;
    ball.h = startH;
    ball.prediction = null;
    ball.flight = ShotFlight(
      make: make,
      points: points,
      zone: zone,
      grade: grade,
      shooterTeam: body.team,
      duration: duration,
      startX: releaseX,
      startH: startH,
      releasedBeforeBuzzer: releasedBeforeBuzzer,
      dunk: isDunk,
    );
    _emit(
      BasketballEvent(
        BasketballEventType.shotReleased,
        team: body.team,
        zone: zone,
        grade: grade,
      ),
    );

    if (blocked) {
      _resolveBlock(defender, body, onDunk: isDunk);
    } else if (isDunk && defender.airborne &&
        defender.jumpPurpose == JumpPurpose.block) {
      // Beat a mistimed block jump at the rim: poster.
      _emit(BasketballEvent(BasketballEventType.poster, team: body.team));
    }
  }

  double makeProbability(
    BasketballAthleteBody body,
    ShotZone zone,
    ReleaseGrade grade,
    JumpPurpose purpose,
  ) {
    final spec = body.spec;
    final d = body.d;
    final rating = spec.ratingFor(zone);
    final zoneBase = switch (zone) {
      ShotZone.dunk || ShotZone.layup => kBbBaseLayup,
      ShotZone.close => kBbBaseClose,
      ShotZone.mid => kBbBaseMid,
      ShotZone.three => kBbBaseThree,
    };
    final zoneRef = switch (zone) {
      ShotZone.dunk || ShotZone.layup => kBbLayupRange,
      ShotZone.close => kBbCloseRange,
      ShotZone.mid => kBbArcDist,
      ShotZone.three => kBbArcDist,
    };
    var overshoot = max(0.0, d - zoneRef);
    if (zone == ShotZone.three && spec.trait == BasketballTrait.deepRange) {
      overshoot = 0;
    }
    var base =
        zoneBase +
        (rating - 70) * kBbRatingSlope -
        overshoot * kBbDistanceSlope;
    if (purpose == JumpPurpose.putback) base += kBbPutbackBonus;

    final timing = switch (grade) {
      ReleaseGrade.perfect => kBbTimingPerfect,
      ReleaseGrade.good => kBbTimingGood,
      _ => kBbTimingEarlyLate,
    };

    var contest = 1 - kBbContestMax * _contestOn(body).clamp(0.0, 1.0);
    if (purpose == JumpPurpose.layup &&
        spec.trait == BasketballTrait.rimPressure) {
      contest = 1 - (1 - contest) * 0.5;
    }

    final moving = body.lastMoveDir != 0 && purpose == JumpPurpose.shot;
    var balance = moving ? kBbBalanceMoving : 1.0;
    if (body.body == BodyState.jump && body.stateT < 0.05) balance *= 0.95;
    // Step-back shots carry a slight balance penalty.
    if (body.exposedT > 0 && purpose == JumpPurpose.shot) {
      balance = min(balance, kBbBalanceStepback);
    }

    final stamina = _lerp(
      0.85,
      1.0,
      (body.stamina01 / 0.6).clamp(0.0, 1.0),
    );
    final heat = teams[body.team].heatActive ? kBbHeatShotBonus : 1.0;
    final repeat = pow(kBbRepeatPenalty, _repeatStacks[body.team]).toDouble();

    final cap = grade == ReleaseGrade.perfect
        ? kBbShotCapPerfect
        : kBbShotCap;
    return (base * timing * contest * balance * stamina * heat * repeat)
        .clamp(kBbShotFloor, cap);
  }

  bool _blockConnects(
    BasketballAthleteBody defender,
    BasketballAthleteBody shooter,
  ) {
    if (!defender.airborne || defender.jumpPurpose != JumpPurpose.block) {
      return false;
    }
    if (defender.jumpT > kBbBlockSyncWindow * 2) return false;
    final gap = (defender.x - shooter.x).abs();
    final reach =
        kBbBlockReachBase +
        (defender.spec.block - 70) * kBbBlockReachSlope +
        (defender.spec.heightM - 1.95) * 0.5;
    if (gap > reach) return false;
    if (shooter.jumpPurpose == JumpPurpose.dunk) {
      final p = (kBbBlockDunkBase +
              (defender.spec.block - shooter.spec.dunk) * 0.004)
          .clamp(0.05, 0.75);
      return _rng.nextDouble() < p;
    }
    return true;
  }

  void _resolveBlock(
    BasketballAthleteBody defender,
    BasketballAthleteBody shooter, {
    required bool onDunk,
  }) {
    // Deflection: down / behind the shooter / toward the sideline, in play.
    final mode = _rng.nextInt(3);
    ball.phase = BallPhase.loose;
    ball.flight = null;
    ball.h = shooter.spec.heightM + shooter.jumpHeight;
    ball.x = shooter.x;
    switch (mode) {
      case 0: // straight down
        ball.vx = -0.4;
        ball.vh = -2.0;
      case 1: // behind the shooter
        ball.vx = -(1.8 + _rng.nextDouble() * 1.6);
        ball.vh = 1.2;
      default: // toward the sideline but kept in play
        ball.vx = -(0.8 + _rng.nextDouble() * 0.8);
        ball.vh = 2.2;
    }
    if (defender.team == 0) _blocks++;
    teams[defender.team].heatMeter =
        (teams[defender.team].heatMeter + kBbHeatPerStop).clamp(0.0, 1.0);
    _maybeIgniteHeat(defender.team);
    _emit(
      BasketballEvent(
        BasketballEventType.block,
        team: defender.team,
        onDunk: onDunk,
      ),
    );
  }

  void _tryBlockInFlight(BasketballAthleteBody defender) {
    final flight = ball.flight;
    if (ball.phase != BallPhase.shot || flight == null) return;
    if (flight.t > kBbBlockSyncWindow) return;
    if (flight.shooterTeam == defender.team) return;
    final shooter = bodies[flight.shooterTeam];
    if (_blockConnects(defender, shooter)) {
      _resolveBlock(defender, shooter, onDunk: flight.dunk);
    }
  }

  // -------------------------------------------------------------------------
  // Ball
  // -------------------------------------------------------------------------

  void _stepBall(double dt) {
    if (ball.phase != BallPhase.loose) _looseSeconds = 0;
    switch (ball.phase) {
      case BallPhase.held:
        final holder = bodies[ball.holder];
        ball.x = holder.x + holder.facing * 0.35;
        ball.h = 1.1;
      case BallPhase.shot:
        final flight = ball.flight!;
        flight.t += dt;
        final s = (flight.t / flight.duration).clamp(0.0, 1.0);
        // Quadratic arc from release to the rim with lift above both ends.
        final lift = flight.dunk ? 0.25 : max(1.0, (kBbRimX - flight.startX).abs() * 0.22);
        final peak = max(flight.startH, kBbRimHeight) + lift;
        ball.x = _lerp(flight.startX, kBbRimX, s);
        ball.h = _arcHeight(flight.startH, peak, kBbRimHeight, s);
        if (s >= 1) _resolveShotArrival(flight);
      case BallPhase.loose:
        ball.vh -= kBbGravity * dt;
        ball.x += ball.vx * dt;
        ball.h += ball.vh * dt;
        if (ball.x < kBbCourtMinX + 0.15 || ball.x > kBbCourtMaxX - 0.15) {
          ball.vx = -ball.vx * 0.7;
          ball.x = ball.x.clamp(kBbCourtMinX + 0.15, kBbCourtMaxX - 0.15);
        }
        if (ball.h <= 0.12 && ball.vh < 0) {
          ball.h = 0.12;
          ball.vh = -ball.vh * 0.55;
          ball.vx *= 0.8;
          if (ball.vh.abs() < 0.8) ball.vh = 0;
        }
        _tryGroundPickup();
        // Safety net: a ball nobody chases down is scooped by the nearest
        // player, so there's never dead time and a pending buzzer can resolve.
        if (ball.phase == BallPhase.loose) {
          _looseSeconds += dt;
          if (_looseSeconds >= kBbLooseTimeout) _forceLooseRecovery();
        }
      case BallPhase.dead:
        break;
    }
  }

  void _forceLooseRecovery() {
    final a = bodies[0];
    final b = bodies[1];
    final nearest = (ball.x - a.x).abs() <= (ball.x - b.x).abs() ? a : b;
    _grabBall(nearest);
  }

  double _arcHeight(double from, double peak, double to, double s) {
    // Piecewise parabola through (0,from) (0.55,peak) (1,to).
    if (s < 0.55) {
      final u = s / 0.55;
      return from + (peak - from) * (1 - (1 - u) * (1 - u));
    }
    final u = (s - 0.55) / 0.45;
    return peak - (peak - to) * u * u;
  }

  void _resolveShotArrival(ShotFlight flight) {
    if (flight.make) {
      _scoreBasket(flight);
      return;
    }
    // Miss: rim bounce → loose ball with a seeded, varied trajectory.
    final missAngle = _rng.nextDouble();
    final long = _rng.nextBool();
    final spread = 0.8 + (kBbRimX - flight.startX).abs() * 0.35 * missAngle;
    ball.phase = BallPhase.loose;
    ball.flight = null;
    ball.x = kBbRimX;
    ball.h = kBbRimHeight;
    ball.vx = (long ? -1 : -0.45) * spread;
    ball.vh = 1.6 + missAngle * 1.8;
    // Publish the landing prediction now that the rim has been hit.
    ball.prediction = _predictLanding();
    _emit(
      BasketballEvent(
        BasketballEventType.shotMissed,
        team: flight.shooterTeam,
        zone: flight.zone,
        grade: flight.grade,
      ),
    );
    if (_buzzerPending) _finishHalfNow();
  }

  ReboundPrediction _predictLanding() {
    // Closed-form projectile: where the ball first falls to catch height.
    const target = 1.2;
    final vh = ball.vh;
    final disc = vh * vh + 2 * kBbGravity * (ball.h - target);
    final t = (vh + sqrt(max(0, disc))) / kBbGravity;
    final landX = (ball.x + ball.vx * t).clamp(
      kBbCourtMinX + 0.15,
      kBbCourtMaxX - 0.15,
    );
    return ReboundPrediction(landX, t);
  }

  void _scoreBasket(ShotFlight flight) {
    final scorer = flight.shooterTeam;
    final team = teams[scorer];
    final other = teams[1 - scorer];
    team.score += flight.points;
    team.unanswered += flight.points;
    other.unanswered = 0;
    if (other.heatActive) {
      other.heatActive = false;
      other.heatMeter = 0;
      _emit(BasketballEvent(BasketballEventType.heatEnded, team: 1 - scorer));
    } else {
      other.heatMeter = 0;
    }
    if (scorer == 0) {
      _makes++;
      if (flight.points == 3) _threes++;
      if (flight.dunk) _dunks++;
      _bestRun = max(_bestRun, teams[0].unanswered);
    }
    // Repeat-shot penalty bookkeeping.
    if (_lastMakeZone[scorer] == flight.zone) {
      _repeatStacks[scorer] =
          min(kBbRepeatMaxStacks, _repeatStacks[scorer] + 1);
    } else {
      _repeatStacks[scorer] = 0;
    }
    _lastMakeZone[scorer] = flight.zone;

    team.heatMeter = (team.heatMeter + kBbHeatPerBasket).clamp(0.0, 1.0);
    if (team.unanswered >= 6) team.heatMeter = 1;
    _maybeIgniteHeat(scorer);

    final buzzer = _buzzerPending;
    _emit(
      BasketballEvent(
        BasketballEventType.basketMade,
        team: scorer,
        points: flight.points,
        zone: flight.zone,
        grade: flight.grade,
      ),
    );
    if (flight.dunk) {
      _emit(BasketballEvent(BasketballEventType.dunk, team: scorer));
    }
    if (buzzer) {
      _emit(BasketballEvent(BasketballEventType.buzzerBeater, team: scorer));
    }

    ball.phase = BallPhase.dead;
    ball.flight = null;
    ball.prediction = null;

    if (overtime) {
      _endMatch(buzzer: false);
      return;
    }
    if (buzzer) {
      _finishHalfNow(buzzerBeater: true);
      return;
    }
    _beginReset(newPossession: 1 - scorer, scoredBy: scorer);
  }

  void _maybeIgniteHeat(int teamIndex) {
    final team = teams[teamIndex];
    if (!team.heatActive && team.heatMeter >= 1) {
      team.heatActive = true;
      team.heatT = kBbHeatDuration;
      _emit(BasketballEvent(BasketballEventType.heatStarted, team: teamIndex));
    }
  }

  // -------------------------------------------------------------------------
  // Rebounds & pickups
  // -------------------------------------------------------------------------

  void _tryGrab(BasketballAthleteBody body) {
    if (ball.phase != BallPhase.loose) return;
    if (ball.h > body.reach || ball.h < 0.5) return;
    if ((ball.x - body.x).abs() > kBbReboundReach) return;

    // Contested when the opponent is also mid rebound-jump in range.
    final other = bodies[1 - body.team];
    final contested =
        other.airborne &&
        other.jumpPurpose == JumpPurpose.rebound &&
        (ball.x - other.x).abs() <= kBbReboundReach &&
        ball.h <= other.reach;
    var winner = body;
    if (contested) {
      final sa = _reboundScore(body);
      final sb = _reboundScore(other);
      winner = sa == sb ? (_rng.nextBool() ? body : other) : (sa > sb ? body : other);
    }
    _grabBall(winner);
  }

  double _reboundScore(BasketballAthleteBody body) {
    var score =
        -2.0 * (ball.x - body.x).abs() +
        (body.spec.rebound - 70) * 0.01 +
        (body.spec.heightM - 1.95) * 0.6;
    // Apex bonus: grabbing near the top of the jump.
    final frac = body.jumpDur > 0 ? body.jumpT / body.jumpDur : 0.0;
    if ((frac - 0.5).abs() < 0.2) score += 0.3;
    if (body.spec.trait == BasketballTrait.glassCleaner) {
      score += kBbGlassCleanerBonus;
    }
    // Box-out assist: was holding stance in contact just before the jump.
    final other = bodies[1 - body.team];
    if ((other.x - body.x).abs() < kBbBodyGap + 0.15 &&
        body.d < other.d) {
      score += kBbBoxOutBonus * 0.5;
    }
    score += (_rng.nextDouble() - 0.5) * 0.05;
    return score;
  }

  void _tryGroundPickup() {
    if (ball.phase != BallPhase.loose || ball.h > 1.2) return;
    BasketballAthleteBody? nearest;
    for (final body in bodies) {
      if (body.airborne || body.locked) continue;
      final gap = (ball.x - body.x).abs();
      if (gap <= kBbGroundPickupRange &&
          (nearest == null ||
              gap < (ball.x - nearest.x).abs())) {
        nearest = body;
      }
    }
    if (nearest != null) _grabBall(nearest);
  }

  void _grabBall(BasketballAthleteBody body) {
    final wasShotBy = possession;
    ball.phase = BallPhase.held;
    ball.holder = body.team;
    ball.vx = 0;
    ball.vh = 0;
    ball.prediction = null;

    final offensive = body.team == wasShotBy;
    possession = body.team;
    shotClock = kBbShotClockSeconds;
    if (offensive) {
      body.putbackT = kBbPutbackWindow;
      teams[body.team].heatMeter =
          (teams[body.team].heatMeter + kBbHeatPerBoard).clamp(0.0, 1.0);
      _maybeIgniteHeat(body.team);
    }
    if (body.team == 0) _rebounds++;
    _emit(
      BasketballEvent(
        BasketballEventType.rebound,
        team: body.team,
        offensive: offensive,
      ),
    );
    // The buzzer already sounded — any recovered ball ends the half.
    if (_buzzerPending) _finishHalfNow();
  }

  // -------------------------------------------------------------------------
  // Clocks, possession, match flow
  // -------------------------------------------------------------------------

  void _stepClocks(double dt) {
    if (playPhase != PlayPhase.live) return;

    if (!overtime && !_buzzerPending) {
      halfClock -= dt;
      if (halfClock <= 0) {
        halfClock = 0;
        // Ball in the air (or loose off a live shot): buzzer-beater rule.
        if (ball.phase == BallPhase.shot || ball.phase == BallPhase.loose) {
          _buzzerPending = true;
        } else {
          _finishHalfNow();
          return;
        }
      }
    }

    if (ball.phase == BallPhase.held && !_buzzerPending) {
      shotClock -= dt;
      if (shotClock <= 0) {
        if (ball.holder == 0) _turnovers++;
        _emit(
          BasketballEvent(
            BasketballEventType.shotClockViolation,
            team: ball.holder,
          ),
        );
        _turnover(to: 1 - ball.holder, steal: false);
        _beginReset(newPossession: possession);
      }
    }
  }

  void _turnover({required int to, required bool steal}) {
    possession = to;
    shotClock = kBbShotClockSeconds;
    if (steal) {
      ball.phase = BallPhase.held;
      ball.holder = to;
    }
  }

  void _beginReset({required int newPossession, int? scoredBy}) {
    possession = newPossession;
    playPhase = PlayPhase.deadReset;
    resetT = kBbResetSeconds;
    ball.phase = BallPhase.dead;
    ball.flight = null;
    ball.prediction = null;
    for (final body in bodies) {
      body.jumpPurpose = null;
      body.putbackT = 0;
      // A scored-on reset plays a reaction beat (scorer celebrates, victim
      // slumps); both time out to idle well inside the reset walk-back.
      final react = scoredBy == null
          ? BodyState.idle
          : (body.team == scoredBy ? BodyState.celebrate : BodyState.dejected);
      if (body.body != react) body.enter(react);
    }
  }

  void _stepDeadReset(double dt) {
    resetT -= dt;
    final offense = bodies[possession];
    final defense = bodies[1 - possession];
    final k = (dt / max(0.01, resetT + dt)).clamp(0.0, 1.0);
    offense.x = _lerp(offense.x, kBbCheckSpotX, k);
    defense.x = _lerp(defense.x, kBbDefResetX, k);
    ball.x = offense.x + 0.35;
    ball.h = 1.1;
    if (resetT <= 0) {
      offense.x = kBbCheckSpotX;
      defense.x = kBbDefResetX;
      offense.facing = 1;
      defense.facing = -1;
      ball.phase = BallPhase.held;
      ball.holder = possession;
      shotClock = kBbShotClockSeconds;
      playPhase = PlayPhase.live;
    }
  }

  void _placeForPossession() {
    final offense = bodies[possession];
    final defense = bodies[1 - possession];
    offense.x = kBbCheckSpotX;
    defense.x = kBbDefResetX;
    offense.facing = 1;
    defense.facing = -1;
    offense.enter(BodyState.idle);
    defense.enter(BodyState.idle);
    ball.phase = BallPhase.held;
    ball.holder = possession;
    ball.prediction = null;
    ball.flight = null;
  }

  void _finishHalfNow({bool buzzerBeater = false}) {
    _buzzerPending = false;
    if (halfIndex == 0) {
      playPhase = PlayPhase.awaiting;
      _emit(
        const BasketballEvent(BasketballEventType.halfEnded, halfIndex: 0),
      );
      return;
    }
    // End of H2: decide or go to overtime.
    if (teams[0].score != teams[1].score) {
      _endMatch(buzzer: buzzerBeater);
    } else {
      playPhase = PlayPhase.awaiting;
      _emit(
        const BasketballEvent(
          BasketballEventType.halfEnded,
          halfIndex: 1,
          needsOvertime: true,
        ),
      );
    }
  }

  void _endMatch({required bool buzzer}) {
    _matchOver = true;
    _endedOnBuzzer = buzzer;
    playPhase = PlayPhase.finished;
    ball.phase = BallPhase.dead;
    _emit(
      BasketballEvent(
        BasketballEventType.matchEnded,
        team: teams[0].score > teams[1].score ? 0 : 1,
      ),
    );
  }

  void _emit(BasketballEvent event) => _events.add(event);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
