import 'package:card_game/models/streak.dart';
import 'package:card_game/models/streak_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Seeded run: six active days ending the day before `morning`.
  final morning = DateTime(2026, 6, 19, 10);
  final evening = DateTime(2026, 6, 19, 19);
  final streak = StreakSnapshot.seeded(morning);
  const empty = StreakReminderLog();

  StreakReminderKind? due(StreakSnapshot s, DateTime now, StreakReminderLog log) =>
      streakReminderDue(streak: s, now: now, log: log);

  test('no reminder once today is secured', () {
    final secured = streak.record(StreakActivity.predict, morning);
    expect(due(secured, morning, empty), isNull);
    expect(due(secured, evening, empty), isNull);
  });

  test('no reminder without a live run to lose', () {
    expect(due(StreakSnapshot.fromJson(const {}), morning, empty), isNull);
  });

  test('first open of the day nudges once', () {
    expect(due(streak, morning, empty), StreakReminderKind.nudge);
    final shown = empty.markShown(StreakReminderKind.nudge, morning);
    expect(due(streak, DateTime(2026, 6, 19, 14), shown), isNull);
  });

  test('after 18:00 the AT RISK warning escalates once, even after a nudge', () {
    final nudged = empty.markShown(StreakReminderKind.nudge, morning);
    expect(due(streak, evening, nudged), StreakReminderKind.atRisk);
    final warned = nudged.markShown(StreakReminderKind.atRisk, evening);
    expect(due(streak, DateTime(2026, 6, 19, 22), warned), isNull);
  });

  test('a missed nudge is skipped after 18:00 — only AT RISK shows', () {
    expect(due(streak, evening, empty), StreakReminderKind.atRisk);
    final warned = empty.markShown(StreakReminderKind.atRisk, evening);
    expect(due(streak, DateTime(2026, 6, 19, 20), warned), isNull);
  });

  test('yesterday\'s log does not silence today', () {
    final played = streak.record(StreakActivity.pick, morning);
    final tomorrow = DateTime(2026, 6, 20, 9);
    final yesterdayLog = empty
        .markShown(StreakReminderKind.nudge, morning)
        .markShown(StreakReminderKind.atRisk, evening);
    expect(due(played, tomorrow, yesterdayLog), StreakReminderKind.nudge);
  });

  test('log serializes and tolerates garbage', () {
    final log = empty
        .markShown(StreakReminderKind.nudge, morning)
        .markShown(StreakReminderKind.atRisk, evening);
    final restored = StreakReminderLog.fromJson(log.toJson());
    expect(restored.nudgeDayKey, '2026-06-19');
    expect(restored.atRiskDayKey, '2026-06-19');
    expect(StreakReminderLog.fromJson('nope').nudgeDayKey, isNull);
    expect(StreakReminderLog.fromJson({'nudge': 5}).nudgeDayKey, isNull);
  });
}
