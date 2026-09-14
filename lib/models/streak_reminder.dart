import 'streak.dart';

/// Escalating in-app streak reminders: a gentle `nudge` on the first open of
/// the day, then an `atRisk` warning from [streakRiskHour]. At most one of each
/// per local day.
enum StreakReminderKind { nudge, atRisk }

/// Which reminders were already shown, keyed by local day.
class StreakReminderLog {
  const StreakReminderLog({this.nudgeDayKey, this.atRiskDayKey});

  /// Tolerant of missing or malformed data — anything unexpected is an empty
  /// log, so a bad write can only cause one extra reminder, never a crash.
  factory StreakReminderLog.fromJson(Object? json) {
    if (json is! Map) return const StreakReminderLog();
    String? read(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return StreakReminderLog(
      nudgeDayKey: read('nudge'),
      atRiskDayKey: read('atRisk'),
    );
  }

  final String? nudgeDayKey;
  final String? atRiskDayKey;

  StreakReminderLog markShown(StreakReminderKind kind, DateTime now) {
    final key = streakDayKey(now);
    return switch (kind) {
      StreakReminderKind.nudge => StreakReminderLog(
        nudgeDayKey: key,
        atRiskDayKey: atRiskDayKey,
      ),
      StreakReminderKind.atRisk => StreakReminderLog(
        nudgeDayKey: nudgeDayKey,
        atRiskDayKey: key,
      ),
    };
  }

  Map<String, dynamic> toJson() => {
    if (nudgeDayKey != null) 'nudge': nudgeDayKey,
    if (atRiskDayKey != null) 'atRisk': atRiskDayKey,
  };
}

/// The reminder to show right now, or null. Nothing shows when today is
/// already secured or there is no live run to lose. After [streakRiskHour] a
/// missed nudge is skipped — only the AT RISK warning escalates.
StreakReminderKind? streakReminderDue({
  required StreakSnapshot streak,
  required DateTime now,
  required StreakReminderLog log,
}) {
  if (streak.activeOn(StreakCategory.overall, now)) return null;
  if (streak.current(StreakCategory.overall, now: now) == 0) return null;
  final today = streakDayKey(now);
  if (streak.atRisk(now)) {
    return log.atRiskDayKey == today ? null : StreakReminderKind.atRisk;
  }
  if (now.hour < streakRiskHour && log.nudgeDayKey != today) {
    return StreakReminderKind.nudge;
  }
  return null;
}
