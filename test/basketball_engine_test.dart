import 'dart:convert';

import 'package:card_game/blocs/basketball/basketball_cubit.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/games/basketball/basketball_ai.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/basketball/basketball_tuning.dart';
import 'package:card_game/models/basketball.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dt = 1 / 120;

BasketballMatchConfig _config({
  int seed = 7,
  BasketballDifficulty difficulty = BasketballDifficulty.pro,
  String starter = 'okc-shai-gilgeous-alexander',
}) {
  final starterAthlete = basketballAthleteById(starter);
  final rest = basketballAthletes
      .where((a) => a.id != starter)
      .take(2)
      .toList();
  return BasketballMatchConfig(
    playerRoster: [starterAthlete, ...rest],
    playerStarterIndex: 0,
    cpuRoster: [
      basketballAthleteById('sas-victor-wembanyama'),
      basketballAthleteById('phi-joel-embiid'),
      basketballAthleteById('was-anthony-davis'),
    ],
    cpuStarterIndex: 0,
    difficulty: difficulty,
    seed: seed,
  );
}

/// Engine already in half 1 with the PLAYER holding the ball.
BasketballEngine _playerBallEngine({
  int seed = 7,
  String starter = 'okc-shai-gilgeous-alexander',
}) {
  var s = seed;
  while (true) {
    final engine = BasketballEngine(_config(seed: s, starter: starter))
      ..startHalf(0);
    if (engine.possession == 0) return engine;
    s++;
  }
}

List<BasketballEvent> _run(
  BasketballEngine engine,
  double seconds, {
  BasketballIntent Function(int tick)? player,
  BasketballIntent Function(int tick)? cpu,
}) {
  final events = <BasketballEvent>[];
  final ticks = (seconds * 120).round();
  for (var i = 0; i < ticks; i++) {
    events.addAll(
      engine.step(
        player?.call(i) ?? BasketballIntent.idle,
        cpu?.call(i) ?? BasketballIntent.idle,
        _dt,
      ),
    );
  }
  return events;
}

/// Holds the action zone into a jump shot, releasing at [releaseFrac] of the
/// jump. Returns all events produced until just after the release.
List<BasketballEvent> _shoot(
  BasketballEngine engine, {
  required double releaseFrac,
}) {
  final events = <BasketballEvent>[];
  var held = 0.0;
  for (var i = 0; i < 600; i++) {
    final body = engine.playerBody;
    final releasing =
        body.body == BodyState.jump &&
        body.jumpPurpose == JumpPurpose.shot &&
        body.jumpT >= body.jumpDur * releaseFrac;
    if (releasing) {
      events.addAll(
        engine.step(
          BasketballIntent(actionReleased: true, heldSeconds: held),
          BasketballIntent.idle,
          _dt,
        ),
      );
      return events;
    }
    held += _dt;
    events.addAll(
      engine.step(
        BasketballIntent(
          actionDown: true,
          actionPressed: i == 0,
          heldSeconds: held,
        ),
        BasketballIntent.idle,
        _dt,
      ),
    );
  }
  return events;
}

/// Drives Giannis to the rim and dunks (dunks always score unless blocked).
List<BasketballEvent> _dunk(BasketballEngine engine) {
  final events = <BasketballEvent>[];
  var held = 0.0;
  for (var i = 0; i < 2400; i++) {
    final body = engine.playerBody;
    BasketballIntent intent;
    if (engine.ball.holder == 0 && !body.airborne) {
      if (body.body == BodyState.drive && body.d <= kBbDunkGateRimPressure) {
        held += _dt;
        intent = BasketballIntent(
          moveAxis: 1,
          actionDown: true,
          heldSeconds: held,
        );
      } else {
        held = 0;
        intent = BasketballIntent(
          moveAxis: 1,
          burst: body.body != BodyState.drive && body.stamina > 25,
        );
      }
    } else {
      // Airborne dunk or ball in flight — let it play out.
      intent = const BasketballIntent();
    }
    events.addAll(engine.step(intent, BasketballIntent.idle, _dt));
    if (events.any(
      (e) =>
          e.type == BasketballEventType.basketMade ||
          e.type == BasketballEventType.matchEnded,
    )) {
      break;
    }
  }
  return events;
}

bool _has(List<BasketballEvent> events, BasketballEventType type) =>
    events.any((e) => e.type == type);

void main() {
  group('match setup & flow', () {
    test('startHalf places offense at the check spot, ball live', () {
      final engine = _playerBallEngine();
      expect(engine.playPhase, PlayPhase.live);
      expect(engine.ball.phase, BallPhase.held);
      expect(engine.playerBody.x, closeTo(kBbCheckSpotX, 0.01));
      expect(engine.cpuBody.x, closeTo(kBbDefResetX, 0.01));
      expect(engine.shotClock, kBbShotClockSeconds);
    });

    test('half 2 possession flips relative to half 1', () {
      final engine = BasketballEngine(_config())..startHalf(0);
      final first = engine.possession;
      engine.startHalf(1);
      expect(engine.possession, 1 - first);
    });

    test('movement respects bounds and moves toward the rim', () {
      final engine = _playerBallEngine();
      final startX = engine.playerBody.x;
      _run(engine, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      expect(engine.playerBody.x, greaterThan(startX));
      _run(engine, 30, player: (_) => const BasketballIntent(moveAxis: 1));
      expect(engine.playerBody.x, lessThanOrEqualTo(kBbCourtMaxX));
    });

    test('shot clock violation turns the ball over and resets', () {
      final engine = _playerBallEngine();
      final events = _run(engine, kBbShotClockSeconds + 2);
      expect(_has(events, BasketballEventType.shotClockViolation), isTrue);
      expect(engine.possession, 1);
      expect(engine.playPhase, PlayPhase.live);
      expect(engine.cpuBody.x, closeTo(kBbCheckSpotX, 0.05));
    });

    test('half ends at zero with a dead ball', () {
      final engine = _playerBallEngine();
      engine.halfClock = 0.3;
      final events = _run(engine, 1);
      expect(_has(events, BasketballEventType.halfEnded), isTrue);
      expect(engine.playPhase, PlayPhase.awaiting);
    });

    test('buzzer beater: half only ends after a live shot resolves', () {
      final engine = _playerBallEngine();
      // Long enough for the release to beat the buzzer, short enough that the
      // ball is still in the air when the clock hits zero.
      engine.halfClock = 0.6;
      final events = _shoot(engine, releaseFrac: 0.4);
      events.addAll(_run(engine, 3));
      final endIndex = events.indexWhere(
        (e) => e.type == BasketballEventType.halfEnded,
      );
      final resolveIndex = events.indexWhere(
        (e) =>
            e.type == BasketballEventType.basketMade ||
            e.type == BasketballEventType.shotMissed,
      );
      expect(endIndex, greaterThanOrEqualTo(0));
      expect(resolveIndex, greaterThanOrEqualTo(0));
      expect(endIndex, greaterThan(resolveIndex));
    });
  });

  group('shooting', () {
    test('release at apex grades perfect; extremes grade early/late', () {
      final apexFrac = kBbShotApexQuickRelease; // SGA has Quick Release
      final perfect = _shoot(_playerBallEngine(), releaseFrac: apexFrac);
      final released = perfect.firstWhere(
        (e) => e.type == BasketballEventType.shotReleased,
      );
      expect(released.grade, ReleaseGrade.perfect);
      expect(_has(perfect, BasketballEventType.perfectRelease), isTrue);

      final late_ = _shoot(_playerBallEngine(), releaseFrac: 0.95);
      expect(
        late_
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .grade,
        ReleaseGrade.late,
      );
    });

    test('zone and points come from the release position', () {
      final fromDeep = _playerBallEngine();
      final deepEvents = _shoot(fromDeep, releaseFrac: 0.36);
      expect(
        deepEvents
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .zone,
        ShotZone.three,
      );

      final fromMid = _playerBallEngine();
      fromMid.playerBody.x = kBbRimX - kBbCloseRange - 0.5;
      final midEvents = _shoot(fromMid, releaseFrac: 0.36);
      expect(
        midEvents
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .zone,
        ShotZone.mid,
      );
    });

    test('make probability is monotonic in grade, contest and distance', () {
      final engine = _playerBallEngine();
      final body = engine.playerBody;
      body.x = kBbRimX - kBbCloseRange - 0.4; // mid range
      engine.cpuBody.x = kBbCourtMinX; // no contest

      final perfect = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.perfect,
        JumpPurpose.shot,
      );
      final good = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      final early = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.early,
        JumpPurpose.shot,
      );
      expect(perfect, greaterThan(good));
      expect(good, greaterThan(early));

      // Contest suppresses.
      engine.cpuBody
        ..x = body.x + 0.5
        ..enter(BodyState.stance);
      final contested = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      expect(contested, lessThan(good));

      // Deeper threes are harder (no Deep Range on SGA).
      engine.cpuBody.x = kBbCourtMinX;
      body.x = kBbRimX - kBbArcDist - 0.1;
      final atLine = engine.makeProbability(
        body,
        ShotZone.three,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      body.x = kBbRimX - kBbArcDist - 2.5;
      final deep = engine.makeProbability(
        body,
        ShotZone.three,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      expect(deep, lessThan(atLine));

      // Probabilities stay inside the clamp.
      expect(perfect, lessThanOrEqualTo(kBbShotCapPerfect));
      expect(deep, greaterThanOrEqualTo(kBbShotFloor));
    });

    test('perfect window shrinks when tired and grows on heat', () {
      final engine = _playerBallEngine();
      final body = engine.playerBody;
      final fresh = engine.perfectHalfWindow(body);
      body.stamina = 15;
      final tired = engine.perfectHalfWindow(body);
      expect(tired, lessThan(fresh));
      body.stamina = 100;
      engine.teams[0].heatActive = true;
      final hot = engine.perfectHalfWindow(body);
      expect(hot, greaterThan(fresh));
    });
  });

  group('possession', () {
    test('a shot from inside resolves immediately — no clear required', () {
      final engine = _playerBallEngine();
      engine.playerBody.x = kBbRimX - kBbLayupRange; // inside the arc
      final shot = _shoot(engine, releaseFrac: 0.4);
      expect(_has(shot, BasketballEventType.shotReleased), isTrue);
    });
  });

  group('defense', () {
    test('a whiffed lunge locks the defender out', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 3; // far away — pure whiff
      _run(
        engine,
        0.1,
        cpu: (i) => BasketballIntent(
          actionPressed: i == 0,
          actionReleased: i == 0,
          heldSeconds: 0.05,
        ),
      );
      expect(engine.cpuBody.body, BodyState.lunge);
      _run(engine, 0.4);
      expect(engine.cpuBody.recoverT, greaterThan(0));
    });

    test('exposed dribbles are stolen more often than protected ones', () {
      var protectedSteals = 0;
      var exposedSteals = 0;
      for (var seed = 0; seed < 150; seed++) {
        // Protected: stationary, guarded handler.
        final a = _playerBallEngine(seed: seed * 3 + 1);
        a.cpuBody.x = a.playerBody.x + 0.9;
        final eventsA = _run(
          a,
          0.4,
          cpu: (i) => i == 2
              ? const BasketballIntent(
                  actionPressed: true,
                  actionReleased: true,
                  heldSeconds: 0.05,
                )
              : BasketballIntent.idle,
        );
        if (_has(eventsA, BasketballEventType.steal)) protectedSteals++;

        // Exposed: handler bursts into a drive as the defender lunges.
        final b = _playerBallEngine(seed: seed * 3 + 1);
        b.cpuBody.x = b.playerBody.x + 0.9;
        final eventsB = _run(
          b,
          0.4,
          player: (i) => BasketballIntent(moveAxis: 1, burst: i == 0),
          cpu: (i) => i == 2
              ? const BasketballIntent(
                  actionPressed: true,
                  actionReleased: true,
                  heldSeconds: 0.05,
                )
              : BasketballIntent.idle,
        );
        if (_has(eventsB, BasketballEventType.steal)) exposedSteals++;
      }
      expect(exposedSteals, greaterThan(protectedSteals));
      expect(exposedSteals, lessThan(150)); // never a guarantee
    });

    test('a synced block jump rejects the shot into a live ball', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 0.7;
      var held = 0.0;
      final events = <BasketballEvent>[];
      for (var i = 0; i < 400; i++) {
        final shooter = engine.playerBody;
        var playerHeld = (i + 1) * _dt;
        BasketballIntent playerIntent;
        BasketballIntent cpuIntent;
        final apex = shooter.jumpDur * kBbShotApexQuickRelease;
        if (shooter.airborne &&
            shooter.jumpPurpose == JumpPurpose.shot &&
            shooter.jumpT >= apex) {
          playerIntent = BasketballIntent(
            actionReleased: true,
            heldSeconds: playerHeld,
          );
        } else {
          playerIntent = BasketballIntent(
            actionDown: true,
            actionPressed: i == 0,
            heldSeconds: playerHeld,
          );
        }
        // Defender releases its held block the moment the shooter rises.
        if (shooter.airborne && shooter.jumpPurpose == JumpPurpose.shot) {
          cpuIntent = BasketballIntent(actionReleased: true, heldSeconds: held);
          held = 0;
        } else {
          held += _dt;
          cpuIntent = BasketballIntent(actionDown: true, heldSeconds: held);
        }
        events.addAll(engine.step(playerIntent, cpuIntent, _dt));
        if (_has(events, BasketballEventType.block)) break;
      }
      expect(_has(events, BasketballEventType.block), isTrue);
      expect(engine.ball.phase, BallPhase.loose);
    });

    test('a pump fake baits the leaping defender into a stagger', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 0.8;
      final events = <BasketballEvent>[];
      var held = 0.0;
      for (var i = 0; i < 240; i++) {
        // Player taps a pump fake at tick 0.
        final playerIntent = i == 0
            ? const BasketballIntent(
                actionPressed: true,
                actionReleased: true,
                heldSeconds: 0.05,
              )
            : BasketballIntent.idle;
        // Defender holds, then bites mid-fake.
        BasketballIntent cpuIntent;
        if (engine.playerBody.body == BodyState.fake && held >= 0.16) {
          cpuIntent = BasketballIntent(actionReleased: true, heldSeconds: held);
          held = 0;
        } else {
          held += _dt;
          cpuIntent = BasketballIntent(actionDown: true, heldSeconds: held);
        }
        events.addAll(engine.step(playerIntent, cpuIntent, _dt));
        if (_has(events, BasketballEventType.stagger)) break;
      }
      expect(_has(events, BasketballEventType.stagger), isTrue);
      expect(engine.cpuBody.body, BodyState.stagger);
    });
  });

  group('spin move', () {
    test('a second burst mid-drive enters the spin and carries into a drive',
        () {
      final engine = _playerBallEngine();
      // First burst → drive.
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.drive);
      // Second burst mid-drive → spin (the double-tap is reused; no new input).
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.spin);
      // Nobody set in the lane — the spin flows into a fresh drive.
      _run(
        engine,
        kBbSpinDuration + 0.05,
        player: (_) => const BasketballIntent(moveAxis: 1),
      );
      expect(engine.playerBody.body, BodyState.drive);
    });

    test('a set defender in the lane absorbs the spin into recovery', () {
      final engine = _playerBallEngine();
      // Plant the defender in the driving lane so the spin ends on their body.
      engine.cpuBody.x = engine.playerBody.x + 1.3;
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.spin);
      // Defender holds a set stance throughout the spin.
      _run(
        engine,
        kBbSpinDuration + 0.05,
        player: (_) => const BasketballIntent(moveAxis: 1),
        cpu: (_) => const BasketballIntent(actionDown: true, heldSeconds: 0.3),
      );
      // Absorbed: the handler is locked out, not driving.
      expect(engine.playerBody.body, BodyState.idle);
      expect(engine.playerBody.recoverT, greaterThan(0));
    });
  });

  group('dunks, heat, overtime', () {
    test('a clean dunk always scores and pays into heat', () {
      final engine = _playerBallEngine(starter: 'mia-giannis-antetokounmpo');
      engine.cpuBody.x = kBbCourtMinX; // open lane
      final events = _dunk(engine);
      expect(_has(events, BasketballEventType.basketMade), isTrue);
      expect(_has(events, BasketballEventType.dunk), isTrue);
      expect(engine.teams[0].score, 2);
      expect(engine.teams[0].heatMeter, greaterThan(0));
    });

    test('three unanswered baskets ignite heat; it expires on its own', () {
      final engine = _playerBallEngine(starter: 'mia-giannis-antetokounmpo');
      engine.halfClock = 500; // keep the half alive for the whole script
      final events = <BasketballEvent>[];
      for (var basket = 0; basket < 3; basket++) {
        engine.cpuBody.x = kBbCourtMinX;
        events.addAll(_dunk(engine));
        engine.playerBody.stamina = 100;
        // Ride out the reset + CPU shot-clock violation + second reset.
        events.addAll(_run(engine, kBbShotClockSeconds + 3));
      }
      expect(_has(events, BasketballEventType.heatStarted), isTrue);
      // Heat expires after its duration.
      events.addAll(_run(engine, kBbHeatDuration + 1));
      expect(_has(events, BasketballEventType.heatEnded), isTrue);
      expect(engine.teams[0].heatActive, isFalse);
    });

    test('overtime is sudden death — first basket ends the match', () {
      for (var seed = 1; seed < 60; seed++) {
        final engine = _playerBallEngine(
          starter: 'mia-giannis-antetokounmpo',
          seed: seed,
        );
        engine.teams[0].score = 10;
        engine.teams[1].score = 10;
        engine.startHalf(2);
        if (engine.possession != 0) continue;
        expect(engine.overtime, isTrue);
        engine.cpuBody.x = kBbCourtMinX;
        final events = _dunk(engine);
        expect(_has(events, BasketballEventType.matchEnded), isTrue);
        expect(engine.matchOver, isTrue);
        return;
      }
      fail('no seed put the player on ball in overtime');
    });
  });

  group('stamina & substitutions', () {
    test('stamina stays bounded and tired athletes are slower', () {
      final engine = _playerBallEngine();
      for (var i = 0; i < 1200; i++) {
        engine.step(
          BasketballIntent(moveAxis: i.isEven ? 1 : -1, burst: i % 40 == 0),
          BasketballIntent.idle,
          _dt,
        );
        expect(engine.playerBody.stamina, inInclusiveRange(0, 100));
      }

      // Fresh vs gassed straight-line speed.
      final fresh = _playerBallEngine();
      fresh.playerBody.x = 2;
      _run(fresh, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      final freshDistance = fresh.playerBody.x - 2;

      final tired = _playerBallEngine();
      tired.playerBody.x = 2;
      tired.playerBody.stamina = 5;
      _run(tired, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      final tiredDistance = tired.playerBody.x - 2;
      expect(tiredDistance, lessThan(freshDistance));
    });

    test('substitution stores stamina and fields the bench athlete', () {
      final engine = _playerBallEngine();
      final starter = engine.playerBody.spec;
      engine.playerBody.stamina = 37;
      engine.substitute(0, 1);
      expect(engine.playerBody.spec, isNot(starter));
      expect(engine.playerBody.stamina, 100);
      expect(engine.teams[0].staminas[0], 37);
      engine.substitute(0, 0);
      expect(engine.playerBody.spec, starter);
      expect(engine.playerBody.stamina, 37);
    });

    test('halftime rest refills the bench and tops up the active athlete', () {
      final engine = _playerBallEngine();
      engine.playerBody.stamina = 30;
      engine.teams[0].staminas[1] = 20;
      engine.halftimeRest();
      expect(engine.playerBody.stamina, 70);
      expect(engine.teams[0].staminas[1], 100);
    });
  });

  group('AI', () {
    BasketballMatchSummary playFullMatch(
      BasketballDifficulty difficulty,
      int seed, {
      List<BasketballEventType>? eventLog,
    }) {
      final engine = BasketballEngine(
        _config(seed: seed, difficulty: difficulty),
      )..startHalf(0);
      final home = BasketballAI(
        difficulty: difficulty,
        seed: seed + 1,
        team: 0,
      );
      final away = BasketballAI(difficulty: difficulty, seed: seed + 2);
      var simSeconds = 0.0;
      while (!engine.matchOver && simSeconds < 400) {
        simSeconds += _dt;
        final events = engine.step(
          home.think(engine, _dt),
          away.think(engine, _dt),
          _dt,
        );
        eventLog?.addAll(events.map((e) => e.type));
        for (final event in events) {
          if (event.type == BasketballEventType.halfEnded) {
            if (event.halfIndex == 0) {
              engine.halftimeRest();
              engine.startHalf(1);
            } else if (event.needsOvertime) {
              engine.startHalf(2);
            }
          }
        }
      }
      expect(
        engine.matchOver,
        isTrue,
        reason: 'AI vs AI match must finish ($difficulty, seed $seed)',
      );
      return engine.summary();
    }

    test('AI vs AI completes at every difficulty with sane scores', () {
      for (final difficulty in BasketballDifficulty.values) {
        for (var seed = 0; seed < 3; seed++) {
          final summary = playFullMatch(difficulty, seed * 11 + 1);
          final total = summary.playerScore + summary.cpuScore;
          expect(
            total,
            greaterThan(0),
            reason: 'someone must score ($difficulty seed $seed)',
          );
          expect(
            total,
            lessThan(90),
            reason: 'scores stay sane ($difficulty seed $seed)',
          );
        }
      }
    });

    test('identical seeds replay identically (full-match golden)', () {
      final logA = <BasketballEventType>[];
      final logB = <BasketballEventType>[];
      final a = playFullMatch(BasketballDifficulty.pro, 42, eventLog: logA);
      final b = playFullMatch(BasketballDifficulty.pro, 42, eventLog: logB);
      expect(logA, logB);
      expect(a.playerScore, b.playerScore);
      expect(a.cpuScore, b.cpuScore);
    });
  });

  group('model', () {
    test('NBA catalog has 180 rated athletes across 30 six-player teams', () {
      expect(basketballAthletes, hasLength(180));
      expect(
        basketballAthletes.map((athlete) => athlete.teamCode).toSet(),
        hasLength(30),
      );
      expect(
        basketballAthletes.map((athlete) => athlete.id).toSet(),
        hasLength(180),
      );

      final teamCounts = <String, int>{};
      for (final athlete in basketballAthletes) {
        teamCounts.update(
          athlete.teamCode,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final count in teamCounts.values) {
        expect(count, 6);
      }

      for (final athlete in basketballAthletes) {
        expect(athlete.ovr, inInclusiveRange(0, 99));
        expect(athlete.overall, athlete.ovr);
        expect(athlete.teamName, isNotEmpty);
        expect(athlete.teamCode, isNotEmpty);
        expect(athlete.position, isNotEmpty);

        final ratings = [
          athlete.speed,
          athlete.handling,
          athlete.inside,
          athlete.mid,
          athlete.three,
          athlete.dunk,
          athlete.defense,
          athlete.steal,
          athlete.block,
          athlete.rebound,
          athlete.stamina,
        ];
        for (final rating in ratings) {
          expect(rating, inInclusiveRange(0, 99));
        }
      }
    });

    test('basketball card rarities match the 12/36/60/72 distribution', () {
      expect(basketballPlayerCards, hasLength(basketballAthletes.length));

      final athleteIds = basketballAthletes
          .map((athlete) => athlete.id)
          .toSet();
      expect(
        basketballPlayerCards.every((card) => athleteIds.contains(card.id)),
        isTrue,
      );
      expect(
        basketballPlayerCards.map((card) => card.id).toSet(),
        hasLength(basketballPlayerCards.length),
      );

      final tierCounts = <CardTier, int>{
        for (final tier in CardTier.values) tier: 0,
      };
      for (final card in basketballPlayerCards) {
        tierCounts[card.tier] = tierCounts[card.tier]! + 1;
      }
      expect(tierCounts[CardTier.platinum], 12);
      expect(tierCounts[CardTier.gold], 36);
      expect(tierCounts[CardTier.silver], 60);
      expect(tierCounts[CardTier.bronze], 72);
    });

    test('every NBA team has enough basketball roles for deck building', () {
      final byTeam = <String, List<BasketballAthlete>>{};
      for (final athlete in basketballAthletes) {
        byTeam.putIfAbsent(athlete.teamCode, () => []).add(athlete);
      }

      for (final entry in byTeam.entries) {
        final roles = entry.value.map((athlete) => athlete.cardRole).toList();
        expect(
          roles.where((role) => role == BasketballCardRole.guard),
          hasLength(greaterThanOrEqualTo(2)),
          reason: '${entry.key} needs at least two guards',
        );
        expect(
          roles.where((role) => role == BasketballCardRole.wing),
          hasLength(greaterThanOrEqualTo(2)),
          reason: '${entry.key} needs at least two wings',
        );
        expect(
          roles.where((role) => role == BasketballCardRole.big),
          hasLength(greaterThanOrEqualTo(1)),
          reason: '${entry.key} needs at least one big',
        );
      }

      expect(
        basketballPlayerCards.any(
          (card) => card.role == PlayerRole.basketballGuard,
        ),
        isTrue,
      );
      expect(
        basketballPlayerCards.any(
          (card) => card.role == PlayerRole.basketballWing,
        ),
        isTrue,
      );
      expect(
        basketballPlayerCards.any(
          (card) => card.role == PlayerRole.basketballBig,
        ),
        isTrue,
      );
    });

    test(
      'old fictional Hoop Duel roster ids fall back to NBA defaults',
      () async {
        SharedPreferences.setMockInitialValues({
          'pd_basketball_stats_v1': jsonEncode(
            const BasketballStats(
              lastRosterIds: ['volt', 'blitz', 'titan'],
              lastStarterId: 'volt',
            ).toJson(),
          ),
        });

        final cubit = BasketballCubit(SecureGameStorage());
        await cubit.load();
        addTearDown(cubit.close);

        expect(cubit.state.rosterIds, [
          'okc-shai-gilgeous-alexander',
          'den-nikola-jokic',
          'sas-victor-wembanyama',
        ]);
        expect(cubit.state.starterId, 'okc-shai-gilgeous-alexander');
        expect(cubit.state.rosterReady, isTrue);
      },
    );

    test('stats json roundtrip and recordResult', () {
      const summary = BasketballMatchSummary(
        playerScore: 21,
        cpuScore: 14,
        overtime: false,
        difficulty: BasketballDifficulty.pro,
        box: BasketballBoxScore(
          attempts: 12,
          makes: 8,
          threesMade: 1,
          perfectReleases: 4,
          dunks: 2,
          blocks: 2,
          steals: 1,
          rebounds: 3,
          turnovers: 1,
          bestRun: 8,
        ),
      );
      final stats = const BasketballStats()
          .recordResult(summary)
          .copyWith(
            lastRosterIds: [
              'okc-shai-gilgeous-alexander',
              'den-nikola-jokic',
              'sas-victor-wembanyama',
            ],
            lastStarterId: 'okc-shai-gilgeous-alexander',
          );
      final revived = BasketballStats.fromJson(stats.toJson());
      expect(revived.wins, 1);
      expect(revived.games, 1);
      expect(revived.mostPoints, 21);
      expect(revived.bestMargin, 7);
      expect(revived.totalDunks, 2);
      expect(revived.lastRosterIds, [
        'okc-shai-gilgeous-alexander',
        'den-nikola-jokic',
        'sas-victor-wembanyama',
      ]);
      expect(revived.lastDifficulty, BasketballDifficulty.pro);
      expect(summary.grade, anyOf('A', 'S'));
    });

    test('grades reward all-round play, not just points', () {
      const grinder = BasketballMatchSummary(
        playerScore: 8,
        cpuScore: 12,
        overtime: false,
        difficulty: BasketballDifficulty.pro,
        box: BasketballBoxScore(attempts: 10, makes: 3, turnovers: 5),
      );
      expect(grinder.grade, anyOf('C', 'D'));
    });
  });
}
