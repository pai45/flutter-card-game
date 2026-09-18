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

  test('a banked shield bridges a missed day without adding to the count', () {
    final returnDay = now.add(const Duration(days: 1));
    final armed = StreakSnapshot.seeded(now).copyWith(shields: 1);

    final saved = armed.applyShields(returnDay);
    expect(saved.shields, 0);
    expect(saved.shieldedOn(now), isTrue);
    expect(saved.current(StreakCategory.overall, now: returnDay), 6);
    final moment = saved.celebrationQueue.last;
    expect(moment.type, StreakCelebrationType.shieldSaved);
    expect(moment.shieldsUsed, 1);
    expect(moment.shields, 0);

    // Playing on the return day continues the run instead of restarting it.
    final played = armed.record(StreakActivity.predict, returnDay);
    expect(played.current(StreakCategory.overall, now: returnDay), 7);
    expect(played.best(StreakCategory.overall), 7);
    expect(played.shields, 0);
  });

  test('shields are kept when the gap is wider than the bank', () {
    final later = now.add(const Duration(days: 3));
    final armed = StreakSnapshot.seeded(now).copyWith(shields: 2);

    expect(identical(armed.applyShields(later), armed), isTrue);
    final restarted = armed.record(StreakActivity.pick, later);
    expect(restarted.current(StreakCategory.overall, now: later), 1);
    expect(restarted.shields, 2);
  });

  test('forged shields cap at the bank limit and serialize', () {
    final streak = StreakSnapshot.seeded(now).grantShield(now).grantShield(now);

    expect(streak.shields, streakShieldCap);
    expect(identical(streak.grantShield(now), streak), isTrue);
    expect(
      streak.celebrationQueue.where(
        (item) => item.type == StreakCelebrationType.shieldEarned,
      ),
      hasLength(2),
    );
    expect(StreakSnapshot.fromJson(streak.toJson()).toJson(), streak.toJson());
    expect(StreakSnapshot.fromJson(const {}).shields, 0);
  });

  test('an unsecured live streak is only at risk late in the day', () {
    final streak = StreakSnapshot.seeded(now);

    expect(streak.atRisk(DateTime(2026, 6, 19, 12)), isFalse);
    expect(streak.atRisk(DateTime(2026, 6, 19, 20)), isTrue);
    final secured = streak.record(
      StreakActivity.predict,
      DateTime(2026, 6, 19, 20),
    );
    expect(secured.atRisk(DateTime(2026, 6, 19, 21)), isFalse);
  });

  test('snapshot serialization preserves claims and queued celebrations', () {
    final original = StreakSnapshot.seeded(now)
        .record(StreakActivity.predict, now)
        .copyWith(claimedMilestones: const {7});
    final restored = StreakSnapshot.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
  });
}
