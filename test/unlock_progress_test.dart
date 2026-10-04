import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unmanaged and grandfathered careers keep all games open', () {
    for (final progress in const [
      UnlockProgress(),
      UnlockProgress.grandfathered(),
    ]) {
      for (final game in ArcadeGame.values) {
        expect(progress.isGameUnlocked(game), isTrue);
        expect(progress.canSelect(game), isFalse);
      }
      expect(progress.dailyQuestsUnlocked, isTrue);
      expect(progress.activeQuestSports, isEmpty);
    }
  });

  for (final starter in ArcadeGame.values) {
    test('${starter.name} can start an arbitrary mission route', () {
      var progress = UnlockProgress.fresh(starter.sport);
      expect(progress.needsSelection(starter.sport), isTrue);
      expect(progress.currentStep(starter.sport), isNull);
      expect(
        progress.remainingFor(starter.sport),
        sportGameLadder[starter.sport],
      );
      expect(progress.isGameUnlocked(starter), isFalse);
      expect(progress.recordPlay(starter, 'unselected').stepCleared, isFalse);
      progress = progress.selectGame(starter);
      expect(progress.currentStep(starter.sport), starter);
      expect(progress.isGameUnlocked(starter), isTrue);
      final route = [
        starter,
        ...sportGameLadder[starter.sport]!.reversed.where((g) => g != starter),
      ];
      expect(progress.selectGame(route[1]), same(progress));
      expect(progress.isGameUnlocked(route[1]), isFalse);
      for (var index = 0; index < route.length; index++) {
        final game = route[index];
        if (index > 0) progress = progress.selectGame(game);
        final restored = UnlockProgress.fromJson(progress.toJson());
        expect(restored.currentStep(game.sport), game);
        final result = restored.recordPlay(game, 'run-$index');
        expect(result.stepCleared, isTrue);
        expect(result.graduated, index == 2);
        expect(result.questCompleted, index == route.length - 1);
        progress = result.progress;
        expect(
          progress.completedFor(game.sport),
          route.take(index + 1).toList(),
        );
        expect(progress.recordPlay(game, 'run-$index').stepCleared, isFalse);
        expect(progress.recordPlay(game, 'replay-$index').stepCleared, isFalse);
        expect(progress.isGameUnlocked(game), isTrue);
        expect(progress.currentStep(game.sport), isNull);
        expect(progress.needsSelection(game.sport), index < route.length - 1);
      }
      expect(progress.pendingReveals.last.kind, UnlockRevealKind.questComplete);
      expect(progress.selectGame(starter), same(progress));
      expect(progress.dailyQuestsUnlocked, isTrue);
    });
  }

  test(
    'sport progress is independent and re-onboarding keeps earned missions',
    () {
      var progress = UnlockProgress.fresh(Sport.football);
      expect(progress.canSelect(ArcadeGame.cricketQuiz), isFalse);
      progress = progress
          .unlockSport(Sport.cricket)
          .selectGame(ArcadeGame.cricketQuiz);
      expect(progress.hasRookieTicket(Sport.cricket), isTrue);
      expect(progress.isGameUnlocked(ArcadeGame.finalOver), isFalse);
      progress = progress
          .selectGame(ArcadeGame.footballChess)
          .recordPlay(ArcadeGame.cricketQuiz, 'quiz')
          .progress;
      expect(progress.currentStep(Sport.football), ArcadeGame.footballChess);
      expect(progress.needsSelection(Sport.cricket), isTrue);
      expect(progress.initialQuestActive, isTrue);
      expect(progress.hasRookieTicket(Sport.cricket), isFalse);
      expect(
        progress.chooseHomeSport(Sport.football).currentStep(Sport.football),
        ArcadeGame.footballChess,
      );
      expect(progress.orderedUnlockedSports, [Sport.football, Sport.cricket]);
      expect(progress.unlockSport(Sport.cricket), same(progress));
    },
  );

  test('quiz entry remains free until its chosen mission clears', () {
    var progress = UnlockProgress.fresh(
      Sport.cricket,
    ).selectGame(ArcadeGame.cricketQuiz).useRookieTicket(Sport.cricket);
    progress = UnlockProgress.fromJson(progress.toJson());
    expect(progress.hasRookieTicket(Sport.cricket), isTrue);
    expect(progress.rookieTicketsUsed, {Sport.cricket});
    expect(
      progress
          .recordPlay(ArcadeGame.cricketQuiz, 'set')
          .progress
          .hasRookieTicket(Sport.cricket),
      isFalse,
    );
  });

  test(
    'v1 unstarted quests offer choice; progressed quests retain their active game',
    () {
      for (final sport in Sport.values) {
        final ladder = sportGameLadder[sport]!;
        for (var reached = 1; reached <= ladder.length; reached++) {
          final progress = UnlockProgress.fromJson({
            'version': 1,
            'homeSport': sport.name,
            'unlockedSports': [sport.name],
            'ladderReached': {sport.name: reached},
            'processedIds': ['old-id'],
            'rookieTicketsUsed': [sport.name],
            'pendingReveals': [UnlockReveal.game(ladder.last).toJson()],
          });
          expect(
            progress.completedFor(sport),
            ladder.take(reached - 1).toList(),
          );
          expect(
            progress.currentStep(sport),
            reached == 1 ? null : ladder[reached - 1],
          );
          expect(progress.needsSelection(sport), reached == 1);
          expect(progress.processedIds, {'old-id'});
          expect(progress.rookieTicketsUsed, {sport});
          expect(progress.pendingReveals.single.game, ladder.last);
          expect(progress.toJson()['version'], 2);
          expect(
            UnlockProgress.fromJson(progress.toJson()).currentStep(sport),
            progress.currentStep(sport),
          );
        }
      }
    },
  );

  test(
    'completed v1 careers and grandfathered careers retain access without rewards',
    () {
      final progress = UnlockProgress.fromJson({
        'version': 1,
        'homeSport': 'football',
        'unlockedSports': [for (final sport in Sport.values) sport.name],
        'completedQuests': [for (final sport in Sport.values) sport.name],
        'ladderReached': {
          for (final sport in Sport.values)
            sport.name: sportGameLadder[sport]!.length,
        },
      });
      for (final game in ArcadeGame.values) {
        expect(progress.isGameUnlocked(game), isTrue);
      }
      expect(progress.activeQuestSports, isEmpty);
      expect(progress.pendingReveals, isEmpty);
      expect(progress.dailyQuestsUnlocked, isTrue);
      expect(
        UnlockProgress.fromJson(
          const UnlockProgress.grandfathered().toJson(),
        ).grandfathered,
        isTrue,
      );
    },
  );

  test(
    'v2 reload preserves chosen order, active mission and graduation moments',
    () {
      var progress = UnlockProgress.fresh(Sport.football);
      for (final game in [
        ArcadeGame.footballChess,
        ArcadeGame.footballBingo,
        ArcadeGame.footballQuiz,
      ]) {
        progress = progress
            .selectGame(game)
            .recordPlay(game, game.name)
            .progress;
      }
      expect(progress.chapterLabel(Sport.football), 'EXPLORER');
      expect(
        progress.missionLabel(Sport.football),
        'EXPLORER · MISSION 1 OF 3',
      );
      expect(progress.pendingReveals.last.kind, UnlockRevealKind.graduation);
      progress = progress
          .unlockSport(Sport.tennis)
          .selectGame(ArcadeGame.penaltyShootout);
      final restored = UnlockProgress.fromJson(progress.toJson());
      expect(restored.completedFor(Sport.football), [
        ArcadeGame.footballChess,
        ArcadeGame.footballBingo,
        ArcadeGame.footballQuiz,
      ]);
      expect(restored.currentStep(Sport.football), ArcadeGame.penaltyShootout);
      expect(restored.needsSelection(Sport.tennis), isTrue);
      expect(restored.dailyQuestsUnlocked, isTrue);
      expect(
        restored.pendingReveals.map((r) => r.kind),
        progress.pendingReveals.map((r) => r.kind),
      );
      expect(
        restored.consumeReveal().pendingReveals.length,
        restored.pendingReveals.length - 1,
      );
      expect(
        () => UnlockProgress.fromJson({'version': 99}),
        throwsFormatException,
      );
    },
  );

  test('v2 ignores foreign games and duplicate completion entries', () {
    final progress = UnlockProgress.fromJson({
      'version': 2,
      'homeSport': 'cricket',
      'unlockedSports': ['cricket'],
      'completedGames': {
        'cricket': ['cricketQuiz', 'cricketQuiz', 'footballChess', 'unknown'],
      },
      'activeGames': {'cricket': 'cricketQuiz'},
    });
    expect(progress.completedFor(Sport.cricket), [ArcadeGame.cricketQuiz]);
    expect(progress.needsSelection(Sport.cricket), isTrue);
  });
}
