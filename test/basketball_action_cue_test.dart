import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/basketball/basketball_tuning.dart';
import 'package:card_game/models/basketball.dart';
import 'package:flutter_test/flutter_test.dart';

BasketballEngine _engine() {
  final roster = basketballAthletes.take(6).toList();
  final engine = BasketballEngine(
    BasketballMatchConfig(
      playerRoster: roster.take(3).toList(),
      playerStarterIndex: 0,
      cpuRoster: roster.skip(3).take(3).toList(),
      cpuStarterIndex: 0,
      difficulty: BasketballDifficulty.pro,
      seed: 7,
    ),
  )..startHalf(0);

  engine
    ..possession = 0
    ..ball.phase = BallPhase.held
    ..ball.holder = 0;
  return engine;
}

void main() {
  group('BasketballActionCue', () {
    test('shoot is the default cue while holding the ball', () {
      final engine = _engine();

      expect(engine.playerActionCue, BasketballActionCue.shoot);
    });

    test('finish appears inside the layup window while moving', () {
      final engine = _engine();
      engine.playerBody
        ..x = kBbRimX - 1
        ..enter(BodyState.run);

      expect(engine.playerActionCue, BasketballActionCue.finish);
    });

    test('release appears while a jump shot is gathering', () {
      final engine = _engine();
      engine.playerBody
        ..jumpPurpose = JumpPurpose.shot
        ..enter(BodyState.gather);

      expect(engine.playerActionCue, BasketballActionCue.release);
    });

    test('defend appears while the opponent controls the ball', () {
      final engine = _engine();
      engine
        ..possession = 1
        ..ball.holder = 1;

      expect(engine.playerActionCue, BasketballActionCue.defend);
    });

    test('block appears for a shooter threat when stamina allows it', () {
      final engine = _engine();
      engine
        ..possession = 1
        ..ball.holder = 1;
      engine.cpuBody
        ..jumpPurpose = JumpPurpose.shot
        ..enter(BodyState.gather);

      expect(engine.playerActionCue, BasketballActionCue.block);

      engine.playerBody.stamina = kBbDrainBlockJump - 0.1;
      expect(engine.playerActionCue, BasketballActionCue.defend);
    });

    test('rebound appears when a tap can launch a rebound jump', () {
      final engine = _engine();
      engine.ball
        ..phase = BallPhase.loose
        ..holder = -1;
      expect(engine.playerActionCue, isNot(BasketballActionCue.rebound));

      engine.ball.prediction = const ReboundPrediction(8, 0.5);

      expect(engine.playerActionCue, BasketballActionCue.rebound);
    });
  });
}
