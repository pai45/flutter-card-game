import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnlockProgress', () {
    test('unmanaged and grandfathered snapshots keep everything open', () {
      for (final progress in const [
        UnlockProgress(),
        UnlockProgress.grandfathered(),
      ]) {
        expect(progress.gated, isFalse);
        for (final game in ArcadeGame.values) {
          expect(progress.isGameUnlocked(game), isTrue, reason: game.name);
        }
        for (final sport in Sport.values) {
          expect(progress.isSportUnlocked(sport), isTrue);
          expect(progress.isQuestActive(sport), isFalse);
        }
      }
    });

    test('a fresh player opens only the home sport and its first game', () {
      final progress = UnlockProgress.fresh(Sport.cricket);
      expect(progress.gated, isTrue);
      expect(progress.isSportUnlocked(Sport.cricket), isTrue);
      expect(progress.isSportUnlocked(Sport.football), isFalse);
      expect(progress.isGameUnlocked(ArcadeGame.finalOver), isTrue);
      expect(progress.isGameUnlocked(ArcadeGame.cricketQuiz), isFalse);
      expect(progress.isGameUnlocked(ArcadeGame.pitchDuel), isFalse);
      expect(progress.currentStep(Sport.cricket), ArcadeGame.finalOver);
      expect(progress.orderedUnlockedSports, [Sport.cricket]);
      expect(progress.lockedSports, hasLength(Sport.values.length - 1));
    });

    test('finishing the current step unlocks the next game, once', () {
      final start = UnlockProgress.fresh(Sport.cricket);
      final first = start.recordPlay(ArcadeGame.finalOver, 'm1');
      expect(first.stepCleared, isTrue);
      expect(first.unlockedGame, ArcadeGame.cricketQuiz);
      expect(first.progress.isGameUnlocked(ArcadeGame.cricketQuiz), isTrue);
      expect(first.progress.pendingReveals.single.game, ArcadeGame.cricketQuiz);

      // Replaying the same session, or an earlier game, never double-steps.
      final replay = first.progress.recordPlay(ArcadeGame.finalOver, 'm1');
      expect(replay.stepCleared, isFalse);
      final earlier = first.progress.recordPlay(ArcadeGame.finalOver, 'm2');
      expect(earlier.stepCleared, isFalse);
      // A locked game can't be "played" into the ladder either.
      final skip = start.recordPlay(ArcadeGame.cricketGuessPlayer, 'x');
      expect(skip.stepCleared, isFalse);
    });

    test('clearing the last step completes the quest', () {
      var progress = UnlockProgress.fresh(Sport.basketball);
      final ladder = sportGameLadder[Sport.basketball]!;
      var completions = 0;
      for (var i = 0; i < ladder.length; i++) {
        final result = progress.recordPlay(ladder[i], 's$i');
        expect(result.stepCleared, isTrue);
        if (result.questCompleted) completions++;
        progress = result.progress;
      }
      expect(completions, 1);
      expect(progress.isQuestActive(Sport.basketball), isFalse);
      expect(progress.currentStep(Sport.basketball), isNull);
      expect(progress.stepsCleared(Sport.basketball), ladder.length);
      for (final game in ladder) {
        expect(progress.isGameUnlocked(game), isTrue);
      }
      expect(
        progress.pendingReveals.last.kind,
        UnlockRevealKind.questComplete,
      );
    });

    test('unlocking a sport opens its first game and queues a reveal', () {
      final progress = UnlockProgress.fresh(
        Sport.football,
      ).unlockSport(Sport.tennis);
      expect(progress.isSportUnlocked(Sport.tennis), isTrue);
      expect(progress.isGameUnlocked(ArcadeGame.tennisRally), isTrue);
      expect(progress.isGameUnlocked(ArcadeGame.tennisQuiz), isFalse);
      expect(progress.orderedUnlockedSports.first, Sport.football);
      expect(progress.pendingReveals.single.kind, UnlockRevealKind.sport);
      expect(progress.consumeReveal().pendingReveals, isEmpty);
    });

    test('rookie ticket is offered only when the quiz is the step', () {
      var progress = UnlockProgress.fresh(Sport.cricket);
      expect(progress.hasRookieTicket(Sport.cricket), isFalse);
      progress = progress.recordPlay(ArcadeGame.finalOver, 'm1').progress;
      expect(progress.hasRookieTicket(Sport.cricket), isTrue);
      progress = progress.useRookieTicket(Sport.cricket);
      expect(progress.hasRookieTicket(Sport.cricket), isFalse);
    });

    test('re-onboarding keeps what was earned', () {
      final earned = UnlockProgress.fresh(
        Sport.cricket,
      ).recordPlay(ArcadeGame.finalOver, 'm1').progress;
      final again = earned.chooseHomeSport(Sport.cricket);
      expect(again.reachedFor(Sport.cricket), 2);
      final grandfathered = const UnlockProgress.grandfathered()
          .chooseHomeSport(Sport.tennis);
      expect(grandfathered.gated, isFalse);
    });

    test('JSON round-trips and rejects unknown versions', () {
      final progress = UnlockProgress.fresh(Sport.football)
          .recordPlay(ArcadeGame.pitchDuel, 'p1')
          .progress
          .unlockSport(Sport.cricket)
          .useRookieTicket(Sport.football);
      final restored = UnlockProgress.fromJson(progress.toJson());
      expect(restored.homeSport, Sport.football);
      expect(restored.unlockedSports, {Sport.football, Sport.cricket});
      expect(restored.reachedFor(Sport.football), 2);
      expect(restored.processedIds, progress.processedIds);
      expect(restored.rookieTicketsUsed, {Sport.football});
      expect(restored.pendingReveals.map((r) => r.kind), [
        UnlockRevealKind.game,
        UnlockRevealKind.sport,
      ]);
      expect(
        () => UnlockProgress.fromJson({'version': 2}),
        throwsFormatException,
      );
    });

    test('every ladder covers its sport and every game sits on one', () {
      for (final game in ArcadeGame.values) {
        expect(sportGameLadder[game.sport], contains(game));
      }
      for (final sport in Sport.values) {
        expect(sportGameLadder[sport]!.where((g) => g.isQuiz), hasLength(1));
      }
    });
  });
}
