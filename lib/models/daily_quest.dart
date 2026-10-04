import 'streak.dart';

enum DailyQuestActivity {
  pitchDuel,
  penaltyShootout,
  guessPlayer,
  prediction,
  pick,

  /// Any other finished GAMES-tab mode (Final Over, Hoop Duel, quizzes…), so
  /// a non-football home sport can still clear its daily game quests.
  arcadeGame;

  bool get isGame => this != prediction && this != pick;
}

enum DailyQuestId { kickOff, makeYourCall, backYourPlay, dailySweep }

/// Fixed v1 economy. Earned amounts are snapshotted, so later balancing does
/// not change a player's unclaimed rewards.
abstract final class DailyQuestConfig {
  static const rewards = <DailyQuestId, int>{
    DailyQuestId.kickOff: 10,
    DailyQuestId.makeYourCall: 10,
    DailyQuestId.backYourPlay: 10,
    DailyQuestId.dailySweep: 20,
  };
  static int get dailyMaximum => rewards.values.fold(0, (a, b) => a + b);
}

class DailyQuestDay {
  const DailyQuestDay({
    this.games = 0,
    this.predicted = false,
    this.picked = false,
  });
  final int games;
  final bool predicted;
  final bool picked;

  bool completed(DailyQuestId id) => switch (id) {
    DailyQuestId.kickOff => games >= 1,
    DailyQuestId.makeYourCall => predicted || games >= 2,
    DailyQuestId.backYourPlay => picked || games >= 3,
    DailyQuestId.dailySweep => completedCount == 3,
  };
  int get completedCount => DailyQuestId.values.take(3).where(completed).length;
  double progress(DailyQuestId id) => completed(id)
      ? 1
      : switch (id) {
          DailyQuestId.kickOff => 0,
          DailyQuestId.makeYourCall => games / 2,
          DailyQuestId.backYourPlay => games / 3,
          DailyQuestId.dailySweep => completedCount / 3,
        };
  DailyQuestDay record(DailyQuestActivity activity) => DailyQuestDay(
    games: (games + (activity.isGame ? 1 : 0)).clamp(0, 3),
    predicted: predicted || activity == DailyQuestActivity.prediction,
    picked: picked || activity == DailyQuestActivity.pick,
  );
  Map<String, dynamic> toJson() => {
    'games': games,
    'predicted': predicted,
    'picked': picked,
  };
  factory DailyQuestDay.fromJson(Map<String, dynamic> json) => DailyQuestDay(
    games: json['games'] as int,
    predicted: json['predicted'] as bool,
    picked: json['picked'] as bool,
  );
}

class DailyQuestSnapshot {
  const DailyQuestSnapshot({
    this.dayKey = '',
    this.days = const {},
    this.processedIds = const {},
    this.earned = const {},
    this.claimed = const {},
  });
  final String dayKey;
  final Map<String, DailyQuestDay> days;
  final Set<String> processedIds;
  final Map<String, int> earned;
  final Set<String> claimed;
  DailyQuestDay get today => days[dayKey] ?? const DailyQuestDay();
  String rewardId(DailyQuestId id) => 'quest-$dayKey-${id.name}';
  Map<String, int> get claimable => {
    for (final e in earned.entries)
      if (!claimed.contains(e.key)) e.key: e.value,
  };
  int get claimableCoins => claimable.values.fold(0, (a, b) => a + b);

  DailyQuestSnapshot refresh(DateTime now) {
    final key = streakDayKey(now);
    return key == dayKey
        ? this
        : DailyQuestSnapshot(
            dayKey: key,
            days: days,
            processedIds: processedIds,
            earned: earned,
            claimed: claimed,
          );
  }

  DailyQuestSnapshot record(
    DailyQuestActivity activity,
    String sourceId,
    DateTime occurredAt, {
    required DateTime now,
  }) {
    final current = refresh(now);
    final identity = '${activity.name}:$sourceId';
    // Late/replayed events cannot finish an expired day or a future day.
    if (sourceId.isEmpty ||
        current.processedIds.contains(identity) ||
        streakDayKey(occurredAt) != current.dayKey) {
      return current;
    }
    final nextDay = current.today.record(activity);
    final rewards = Map<String, int>.from(earned);
    for (final id in DailyQuestId.values) {
      if (nextDay.completed(id)) {
        rewards.putIfAbsent(
          current.rewardId(id),
          () => DailyQuestConfig.rewards[id]!,
        );
      }
    }
    return DailyQuestSnapshot(
      dayKey: current.dayKey,
      days: {...days, current.dayKey: nextDay},
      processedIds: {...processedIds, identity},
      earned: rewards,
      claimed: claimed,
    );
  }

  DailyQuestSnapshot claimAll() => DailyQuestSnapshot(
    dayKey: dayKey,
    days: days,
    processedIds: processedIds,
    earned: earned,
    claimed: {...claimed, ...earned.keys},
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'dayKey': dayKey,
    'days': {for (final e in days.entries) e.key: e.value.toJson()},
    'processedIds': processedIds.toList(),
    'earned': earned,
    'claimed': claimed.toList(),
  };
  factory DailyQuestSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported quest version');
    }
    return DailyQuestSnapshot(
      dayKey: json['dayKey'] as String,
      days: (json['days'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          k,
          DailyQuestDay.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      processedIds: Set<String>.from(json['processedIds'] as List),
      earned: Map<String, int>.from(json['earned'] as Map),
      claimed: Set<String>.from(json['claimed'] as List),
    );
  }
}
