import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/games/tennis/tennis_engine.dart';
import 'package:card_game/models/tennis.dart';

void main() {
  group('TennisScoring', () {
    test('scores a straight 6-0 set and rotates service each game', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var game = 0; game < 6; game++) {
        final serverBefore = scoring.state.currentServer;
        final results = _winGame(scoring, 0);
        expect(results.last.gameWon, isTrue);
        expect(scoring.state.currentServer, 1 - serverBefore);
      }
      expect(scoring.state.playerGames, 6);
      expect(scoring.state.opponentGames, 0);
      expect(scoring.state.setWinner, 0);
    });

    test('supports a 7-5 set', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 5; i++) {
        _winGame(scoring, 0);
        _winGame(scoring, 1);
      }
      _winGame(scoring, 0);
      final result = _winGame(scoring, 0).last;
      expect(result.setWon, isTrue);
      expect(scoring.state.playerGames, 7);
      expect(scoring.state.opponentGames, 5);
    });

    test('returns from advantage to deuce repeatedly', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 3; i++) {
        scoring.awardPoint(0);
        scoring.awardPoint(1);
      }
      expect(scoring.state.isDeuce, isTrue);
      scoring.awardPoint(0);
      expect(scoring.state.advantage, 0);
      scoring.awardPoint(1);
      expect(scoring.state.advantage, -1);
      expect(scoring.state.isDeuce, isTrue);
      scoring.awardPoint(1);
      expect(scoring.state.advantage, 1);
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      final result = scoring.awardPoint(0);
      expect(result.gameWon, isTrue);
      expect(scoring.state.playerGames, 1);
    });

    test('enters 6-6 and plays a long win-by-two tiebreak', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 6; i++) {
        _winGame(scoring, 0);
        _winGame(scoring, 1);
      }
      expect(scoring.state.tieBreak, isTrue);
      expect(scoring.state.currentServer, 0);

      final servers = <int>[];
      for (final winner in <int>[0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0]) {
        servers.add(scoring.state.currentServer);
        scoring.awardPoint(winner);
      }
      expect(servers.take(7), <int>[0, 1, 1, 0, 0, 1, 1]);
      expect(scoring.state.playerTieBreak, 6);
      expect(scoring.state.opponentTieBreak, 6);
      scoring.awardPoint(0);
      final result = scoring.awardPoint(0);
      expect(result.setWon, isTrue);
      expect(scoring.state.playerGames, 7);
      expect(scoring.state.opponentGames, 6);
    });

    test('reports break points, set points, and two-game end changes', () {
      final scoring = TennisScoring(firstServer: 0);
      scoring.awardPoint(1);
      scoring.awardPoint(1);
      scoring.awardPoint(1);
      expect(scoring.isBreakPointFor(1), isTrue);
      final saved = scoring.awardPoint(0);
      expect(saved.breakPointSaved, isTrue);

      _winGame(scoring, 0);
      expect(scoring.state.totalGames, 1);
      final secondGame = _winGame(scoring, 0).last;
      expect(secondGame.endChange, isTrue);

      while (scoring.state.playerGames < 5) {
        _winGame(scoring, 0);
      }
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      expect(scoring.isSetPointFor(0), isTrue);
    });
  });

  group('Court calls and serves', () {
    test('singles lines and service-box lines are inclusive', () {
      expect(
        tennisBallInsideSingles(tennisCourtHalfWidth, tennisCourtHalfLength),
        isTrue,
      );
      expect(tennisBallInsideSingles(tennisCourtHalfWidth + 0.01, 0), isFalse);
      expect(
        tennisServeInsideBox(
          x: tennisCourtHalfWidth,
          y: -tennisServiceLine,
          server: 0,
          rightServiceCourt: true,
        ),
        isTrue,
      );
      expect(
        tennisServeInsideBox(x: -1, y: -4, server: 0, rightServiceCourt: true),
        isFalse,
      );
    });

    test('keeps a let on the same serve and faults twice', () {
      final letEngine = TennisEngine(_config(seed: 2));
      _setServeBounce(letEngine, x: 1, y: -4, netTouched: true);
      final letEvents = letEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(
        letEvents.map((event) => event.type),
        contains(TennisEventType.let),
      );
      expect(letEngine.serveNumber, 1);
      expect(letEngine.score.playerPoints, 0);

      final faultEngine = TennisEngine(_config(seed: 2));
      _setServeBounce(faultEngine, x: -1, y: -4);
      final first = faultEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(first.map((event) => event.type), contains(TennisEventType.fault));
      expect(faultEngine.serveNumber, 2);

      faultEngine.phase = TennisMatchPhase.rally;
      _setServeBounce(faultEngine, x: -1, y: -4);
      faultEngine.serveNumber = 2;
      final second = faultEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(
        second.map((event) => event.type),
        contains(TennisEventType.doubleFault),
      );
      expect(faultEngine.score.opponentPoints, 1);
    });

    test('awards the hitter after a legal second bounce', () {
      final engine = TennisEngine(_config(seed: 2));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = 0
        ..y = -4
        ..z = 0.001
        ..vx = 0
        ..vy = 0
        ..vz = -1
        ..bounces = 1
        ..lastHitter = 0
        ..live = true
        ..serve = false;
      engine.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      expect(engine.score.playerPoints, 1);
    });

    test('dead net cord landing on the hitter side awards the receiver', () {
      final engine = TennisEngine(_config(seed: 2));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = 0
        ..y = 3
        ..z = 0.001
        ..vx = 0
        ..vy = 0
        ..vz = -1
        ..bounces = 0
        ..lastHitter = 0
        ..live = true
        ..serve = false
        ..netTouched = true;
      engine.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      expect(engine.score.opponentPoints, 1);
    });
  });

  group('Shots, stamina, focus, and snapshots', () {
    test('maps gesture intent to spin, lob, slice, drop, and power shots', () {
      expect(_contactShot(aimY: 0.3), TennisShotType.topspin);
      expect(_contactShot(aimY: 0.8), TennisShotType.lob);
      expect(_contactShot(aimY: -0.3), TennisShotType.slice);
      expect(_contactShot(aimY: -0.8), TennisShotType.dropShot);
      expect(_contactShot(hold: 0.4), TennisShotType.power);
    });

    test('prioritises volley, smash, and defensive returns by context', () {
      expect(
        _contactShot(playerY: 3.2, ballZ: 1.1, bounces: 0),
        TennisShotType.volley,
      );
      expect(
        _contactShot(playerY: 3.2, ballZ: 2.3, bounces: 0),
        TennisShotType.smash,
      );
      expect(
        _contactShot(ballOffsetX: 1.05, bounces: 1),
        TennisShotType.defensive,
      );
    });

    test('allows only one opponent contact per incoming ball', () {
      final engine = TennisEngine(_config(seed: 3));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = engine.opponent.x
        ..y = engine.opponent.y
        ..z = 1
        ..vx = 0
        ..vy = -1
        ..vz = 0
        ..bounces = 1
        ..lastHitter = 0
        ..live = true
        ..serve = false;

      var opponentContacts = 0;
      for (var i = 0; i < 30; i++) {
        final events = engine.step(
          TennisIntent.idle,
          const TennisIntent(shotReleased: true),
          1 / 120,
        );
        opponentContacts += events
            .where(
              (event) =>
                  event.type == TennisEventType.contact && event.team == 1,
            )
            .length;
      }

      expect(opponentContacts, 1);
      expect(engine.ball.lastHitter, 1);
      expect(engine.flightId, 1);
    });

    test('CPU return misses reflect rival ratings', () {
      final shakyMisses = _countOpponentMisses('jett-okafor');
      final eliteMisses = _countOpponentMisses('riven-cole');

      expect(shakyMisses, greaterThan(eliteMisses));
    });

    test('CPU miss consumes the incoming flight without instant retry', () {
      final seed = _firstOpponentMissSeed('jett-okafor');
      final engine = TennisEngine(
        _config(seed: seed, opponentId: 'jett-okafor'),
      );
      _setOpponentReturn(engine);

      final first = engine.step(
        TennisIntent.idle,
        const TennisIntent(shotReleased: true),
        1 / 120,
      );
      final second = engine.step(
        TennisIntent.idle,
        const TennisIntent(shotReleased: true),
        1 / 120,
      );
      final contacts = [...first, ...second].where(
        (event) => event.type == TennisEventType.contact && event.team == 1,
      );

      expect(contacts, isEmpty);
      expect(engine.ball.lastHitter, 0);
    });

    test('does not let the opponent intercept target-practice returns', () {
      final engine = TennisEngine(
        _config(seed: 2, mode: TennisMode.targetPractice),
      );
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = engine.opponent.x
        ..y = engine.opponent.y
        ..z = 1
        ..bounces = 0
        ..lastHitter = 0
        ..live = true;

      expect(engine.canHit(1), isFalse);
    });

    test('bounds movement and stamina even under continuous sprint', () {
      final engine = TennisEngine(_config(seed: 2));
      for (var i = 0; i < 120 * 30; i++) {
        engine.step(
          const TennisIntent(moveX: 1, moveY: 1, sprint: true),
          TennisIntent.idle,
          1 / 120,
        );
      }
      expect(engine.player.stamina, inInclusiveRange(0, 100));
      expect(
        engine.player.x,
        inInclusiveRange(
          -tennisCourtHalfWidth - 1.1,
          tennisCourtHalfWidth + 1.1,
        ),
      );
      expect(
        engine.player.y,
        inInclusiveRange(0.75, tennisCourtHalfLength + 1.1),
      );
      expect(engine.player.x.isFinite, isTrue);
      expect(engine.player.y.isFinite, isTrue);
    });

    test('restores an exact deterministic simulation and RNG state', () {
      final first = TennisEngine(_config(seed: 90210));
      for (var i = 0; i < 240; i++) {
        first.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      }
      final restored = TennisEngine(
        first.config,
        snapshot:
            jsonDecode(jsonEncode(first.snapshot())) as Map<String, dynamic>,
      );
      for (var i = 0; i < 360; i++) {
        first.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
        restored.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      }
      expect(jsonEncode(restored.snapshot()), jsonEncode(first.snapshot()));
    });
  });

  group('Seeded AI full-set soak', () {
    for (final difficulty in TennisDifficulty.values) {
      test(
        '${difficulty.name} completes with a deterministic legal replay',
        () {
          final a = _runAiSet(difficulty, seed: 4400 + difficulty.index);
          final b = _runAiSet(difficulty, seed: 4400 + difficulty.index);
          expect(a.summary.toJson(), b.summary.toJson());
          expect(a.snapshot, b.snapshot);
          expect(a.summary.playerGames, inInclusiveRange(0, 7));
          expect(a.summary.opponentGames, inInclusiveRange(0, 7));
          expect(a.summary.stats.durationSeconds, inInclusiveRange(20, 3600));
        },
      );
    }
  });
}

List<TennisPointResult> _winGame(TennisScoring scoring, int winner) => [
  for (var i = 0; i < 4; i++) scoring.awardPoint(winner),
];

TennisMatchConfig _config({
  int seed = 1,
  TennisDifficulty difficulty = TennisDifficulty.pro,
  TennisMode mode = TennisMode.quickMatch,
  String opponentId = 'jett-okafor',
}) => TennisMatchConfig(
  matchId: 'test-$seed-${difficulty.name}',
  mode: mode,
  playerId: 'nova-reyes',
  opponentId: opponentId,
  difficulty: difficulty,
  seed: seed,
);

int _countOpponentMisses(String opponentId) {
  var misses = 0;
  for (var seed = 1; seed <= 800; seed++) {
    final engine = TennisEngine(_config(seed: seed, opponentId: opponentId));
    _setOpponentReturn(engine);
    final events = engine.step(
      TennisIntent.idle,
      const TennisIntent(shotReleased: true),
      1 / 120,
    );
    final contacted = events.any(
      (event) => event.type == TennisEventType.contact && event.team == 1,
    );
    if (!contacted) misses++;
  }
  return misses;
}

int _firstOpponentMissSeed(String opponentId) {
  for (var seed = 1; seed <= 2000; seed++) {
    final engine = TennisEngine(_config(seed: seed, opponentId: opponentId));
    _setOpponentReturn(engine);
    final events = engine.step(
      TennisIntent.idle,
      const TennisIntent(shotReleased: true),
      1 / 120,
    );
    final contacted = events.any(
      (event) => event.type == TennisEventType.contact && event.team == 1,
    );
    if (!contacted) return seed;
  }
  throw StateError('No opponent miss seed found.');
}

void _setOpponentReturn(TennisEngine engine) {
  engine.phase = TennisMatchPhase.rally;
  engine.opponent
    ..x = 0
    ..y = -8.5
    ..stamina = 18;
  engine.ball
    ..x = 0.92
    ..y = -8.5
    ..z = 1.1
    ..vx = 0
    ..vy = -3.2
    ..vz = 0
    ..bounces = 1
    ..lastHitter = 0
    ..live = true
    ..serve = false
    ..netTouched = false
    ..shot = TennisShotType.power;
}

void _setServeBounce(
  TennisEngine engine, {
  required double x,
  required double y,
  bool netTouched = false,
}) {
  engine.phase = TennisMatchPhase.rally;
  engine.ball
    ..x = x
    ..y = y
    ..z = 0.001
    ..vx = 0
    ..vy = 0
    ..vz = -1
    ..bounces = 0
    ..lastHitter = 0
    ..live = true
    ..serve = true
    ..netTouched = netTouched
    ..shot = TennisShotType.serve;
}

TennisShotType _contactShot({
  double aimY = 0,
  double hold = 0,
  double playerY = 9,
  double ballZ = 1,
  double ballOffsetX = 0,
  int bounces = 1,
}) {
  final engine = TennisEngine(_config(seed: 2));
  engine.phase = TennisMatchPhase.rally;
  engine.player
    ..x = 0
    ..y = playerY;
  engine.ball
    ..x = ballOffsetX
    ..y = playerY
    ..z = ballZ
    ..vx = 0
    ..vy = 2
    ..vz = 0
    ..bounces = bounces
    ..lastHitter = 1
    ..live = true
    ..serve = false;
  engine.step(
    TennisIntent(shotReleased: true, holdSeconds: hold, aimY: aimY),
    TennisIntent.idle,
    1 / 120,
  );
  return engine.ball.shot;
}

({TennisMatchSummary summary, String snapshot}) _runAiSet(
  TennisDifficulty difficulty, {
  required int seed,
}) {
  final config = _config(seed: seed, difficulty: difficulty);
  final engine = TennisEngine(config);
  final playerAi = TennisAI(
    difficulty: difficulty,
    seed: seed ^ 0x101,
    team: 0,
  );
  final opponentAi = TennisAI(
    difficulty: difficulty,
    seed: seed ^ 0x202,
    team: 1,
  );
  const maxSteps = 120 * 60 * 60;
  for (var i = 0; i < maxSteps && !engine.complete; i++) {
    engine.step(
      playerAi.think(engine, 1 / 120),
      opponentAi.think(engine, 1 / 120),
      1 / 120,
    );
    expect(engine.player.stamina, inInclusiveRange(0, 100));
    expect(engine.opponent.stamina, inInclusiveRange(0, 100));
    expect(engine.ball.x.isFinite, isTrue);
    expect(engine.ball.y.isFinite, isTrue);
    expect(engine.ball.z.isFinite, isTrue);
  }
  expect(
    engine.complete,
    isTrue,
    reason: '${difficulty.name} set did not finish',
  );
  return (
    summary: engine.summary(),
    snapshot: jsonEncode(<String, dynamic>{
      'engine': engine.snapshot(),
      'playerAi': playerAi.snapshot(),
      'opponentAi': opponentAi.snapshot(),
    }),
  );
}
