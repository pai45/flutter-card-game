import 'dart:convert';
import 'package:card_game/models/daily_quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 14, 12);
  DailyQuestSnapshot record(
    DailyQuestSnapshot state,
    DailyQuestActivity activity,
    String id,
  ) => state.record(activity, id, today, now: today);

  test(
    'three cumulative games award 10 + 10 + 10 + 20, regardless of mode',
    () {
      var state = const DailyQuestSnapshot();
      for (final activity in DailyQuestActivity.values.take(3)) {
        state = record(state, activity, activity.name);
        expect(state.today.games, activity.index + 1);
        expect(state.today.completedCount, activity.index + 1);
      }
      expect(state.claimableCoins, DailyQuestConfig.dailyMaximum);
      expect(state.claimable, hasLength(4));
      state = record(state, DailyQuestActivity.pitchDuel, 'fourth-game');
      expect(state.claimableCoins, 50);
      expect(state.today.games, 3);
    },
  );

  test('one game, one prediction and one pick unlock the daily sweep', () {
    var state = record(
      const DailyQuestSnapshot(),
      DailyQuestActivity.prediction,
      'prediction',
    );
    state = record(state, DailyQuestActivity.pick, 'position');
    expect(state.today.completedCount, 2);
    expect(state.claimableCoins, 20);
    state = record(state, DailyQuestActivity.guessPlayer, 'mystery');
    expect(state.claimableCoins, 50);
  });

  test(
    'activity identity survives serialization; edits and replay cannot add games',
    () {
      var state = record(
        const DailyQuestSnapshot(),
        DailyQuestActivity.pitchDuel,
        'session',
      );
      state = DailyQuestSnapshot.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      state = record(state, DailyQuestActivity.pitchDuel, 'session');
      expect(state.today.games, 1);
      expect(state.claimableCoins, 10);
      final claimed = state.claimAll();
      expect(claimed.claimableCoins, 0);
      expect(
        record(claimed, DailyQuestActivity.pitchDuel, 'session').claimableCoins,
        0,
      );
    },
  );

  test('midnight resets progress and keeps earned unclaimed rewards', () {
    var state = record(
      const DailyQuestSnapshot(),
      DailyQuestActivity.pitchDuel,
      'session',
    );
    final tomorrow = DateTime(2026, 9, 15);
    state = state.refresh(tomorrow);
    expect(state.today.games, 0);
    expect(state.claimableCoins, 10);
    state = state.record(
      DailyQuestActivity.pitchDuel,
      'new-session',
      tomorrow,
      now: tomorrow,
    );
    expect(state.claimableCoins, 20);
    expect(state.claimAll().claimableCoins, 0);
  });

  test(
    'expired and future events do not finish quests; returning to a date cannot repay it',
    () {
      var state = record(
        const DailyQuestSnapshot(),
        DailyQuestActivity.pitchDuel,
        'session',
      ).claimAll();
      final tomorrow = DateTime(2026, 9, 15);
      state = state.record(
        DailyQuestActivity.pitchDuel,
        'late',
        today,
        now: tomorrow,
      );
      expect(state.today.games, 0);
      state = state.record(
        DailyQuestActivity.pitchDuel,
        'future',
        tomorrow,
        now: today,
      );
      expect(state.today.games, 1);
      expect(state.claimableCoins, 0);
      expect(state.claimed, contains('quest-2026-09-14-kickOff'));
    },
  );
}
