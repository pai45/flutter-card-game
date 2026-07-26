import 'package:card_game/config/enums.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/grand_prix/grand_prix_game.dart';
import 'package:card_game/games/tennis/tennis_engine.dart';
import 'package:card_game/models/football_chess.dart';
import 'package:card_game/utils/game_audio_mappings.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:final_over/final_over.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basketball events have a complete semantic cue map', () {
    final mapped = {
      for (final event in BasketballEventType.values)
        event: basketballSoundForEvent(event),
    };
    expect(mapped, hasLength(BasketballEventType.values.length));
    expect(
      mapped[BasketballEventType.shotClockViolation],
      SoundEffect.bbShotClock,
    );
    expect(mapped[BasketballEventType.block], SoundEffect.bbBlock);
    expect(
      mapped[BasketballEventType.perfectRelease],
      SoundEffect.bbPerfectRelease,
    );
    expect(mapped[BasketballEventType.matchEnded], isNull);
  });

  test('Tennis events have a complete tennis-specific cue map', () {
    final mapped = {
      for (final event in TennisEventType.values)
        event: tennisSoundForEvent(event),
    };
    expect(mapped, hasLength(TennisEventType.values.length));
    expect(mapped.values, isNot(contains(SoundEffect.goal)));
    expect(mapped.values, isNot(contains(SoundEffect.redCard)));
    expect(mapped[TennisEventType.ace], SoundEffect.tennisAce);
    expect(mapped[TennisEventType.doubleFault], SoundEffect.tennisDoubleFault);
  });

  test('Final Over events and timing grades map without football reuse', () {
    final mapped = {
      for (final event in GameplayEventType.values)
        event: finalOverSoundForEvent(event),
    };
    expect(mapped, hasLength(GameplayEventType.values.length));
    expect(
      finalOverSoundForEvent(
        GameplayEventType.contactResolved,
        timing: TimingGrade.perfect,
      ),
      SoundEffect.cricketPerfect,
    );
    expect(
      finalOverSoundForEvent(GameplayEventType.boundary, six: true),
      SoundEffect.cricketSix,
    );
    expect(
      finalOverSoundForEvent(GameplayEventType.runOut),
      SoundEffect.cricketRunOut,
    );
    expect(mapped.values, isNot(contains(SoundEffect.redCard)));
  });

  test('Pitch Duel outcomes preserve distinct result semantics', () {
    expect(
      {
        for (final outcome in RoundOutcome.values)
          pitchDuelSoundForOutcome(outcome),
      },
      {
        SoundEffect.goal,
        SoundEffect.save,
        SoundEffect.block,
        SoundEffect.miss,
        SoundEffect.foul,
        SoundEffect.redCard,
      },
    );
  });

  test('Football Chess actions and resolution events are complete', () {
    final actions = {
      for (final action in BoardActionType.values) chessActionSound(action),
    };
    expect(actions, hasLength(BoardActionType.values.length));
    expect(chessEventSound(BoardEvent.turnover), SoundEffect.chessTurnover);
    expect(chessEventSound(BoardEvent.advanced), SoundEffect.chessAdvanced);
    expect(chessEventSound(BoardEvent.none), isNull);
  });

  test('Shootout and Grand Prix bridges use dedicated catalogs', () {
    expect(
      shootoutCommitSound(ShootoutTurnRole.shooting),
      SoundEffect.penaltyKick,
    );
    expect(
      shootoutCommitSound(ShootoutTurnRole.defending),
      SoundEffect.penaltyDive,
    );
    expect(shootoutImpactSound(goal: true), SoundEffect.penaltyGoal);
    expect(shootoutImpactSound(goal: false), SoundEffect.penaltySave);
    expect(
      {
        for (final event in GrandPrixAudioEvent.values)
          grandPrixEventSound(event),
      },
      {
        SoundEffect.gpTireScrub,
        SoundEffect.gpWallImpact,
        SoundEffect.gpCarImpact,
      },
    );
  });
}
