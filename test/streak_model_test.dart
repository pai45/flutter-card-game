import 'package:card_game/models/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 19, 12);

  test('testing seed exposes the requested current streaks', () {
    final streak = StreakSnapshot.seeded(now);

    expect(streak.current(StreakCategory.overall, now: now), 6);
    expect(streak.current(StreakCategory.predict, now: now), 5);
    expect(streak.current(StreakCategory.pick, now: now), 0);
    expect(streak.current(StreakCategory.games, now: now), 3);
    expect(streak.current(StreakCategory.pitchDuel, now: now), 2);
    expect(streak.current(StreakCategory.penaltyShootout, now: now), 3);
  });

  test(
    'first activity today advances overall and queues daily then milestone',
    () {
      final streak = StreakSnapshot.seeded(
        now,
      ).record(StreakActivity.predict, now);

      expect(streak.current(StreakCategory.overall, now: now), 7);
      expect(streak.current(StreakCategory.predict, now: now), 6);
      expect(streak.celebrationQueue.map((item) => item.type), [
        StreakCelebrationType.daily,
        StreakCelebrationType.milestone,
      ]);
      expect(streak.announcedMilestones, contains(7));
    },
  );

  test('repeated same-day activity is idempotent', () {
    final once = StreakSnapshot.seeded(now).record(StreakActivity.predict, now);
    final twice = once.record(StreakActivity.predict, now);

    expect(twice.current(StreakCategory.overall, now: now), 7);
    expect(twice.current(StreakCategory.predict, now: now), 6);
    expect(twice.celebrationQueue, hasLength(2));
    expect(
      twice
          .activitiesOn(now)
          .where((activity) => activity == StreakActivity.predict),
      hasLength(1),
    );
  });

  test('game activity updates games and the matching subtype', () {
    final streak = StreakSnapshot.seeded(
      now,
    ).record(StreakActivity.pitchDuel, now);

    expect(streak.current(StreakCategory.games, now: now), 4);
    expect(streak.current(StreakCategory.pitchDuel, now: now), 3);
    expect(streak.current(StreakCategory.penaltyShootout, now: now), 3);
  });

  test('a missed day resets the current run while preserving best', () {
    final streak = StreakSnapshot.seeded(now);
    final afterGap = streak.record(
      StreakActivity.predict,
      now.add(const Duration(days: 1)),
    );

    expect(
      afterGap.current(
        StreakCategory.overall,
        now: now.add(const Duration(days: 1)),
      ),
      1,
    );
    expect(afterGap.best(StreakCategory.overall), 6);
  });

  test('snapshot serialization preserves claims and queued celebrations', () {
    final original = StreakSnapshot.seeded(now)
        .record(StreakActivity.predict, now)
        .copyWith(claimedMilestones: const {7});
    final restored = StreakSnapshot.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
  });
}
