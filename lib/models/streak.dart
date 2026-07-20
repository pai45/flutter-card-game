import '../config/enums.dart';

enum StreakActivity {
  predict,
  pick,
  pitchDuel,
  penaltyShootout,
  guessPlayer,
}

enum StreakCategory {
  overall,
  predict,
  pick,
  games,
  pitchDuel,
  penaltyShootout,
}

enum StreakCelebrationType { daily, milestone }

enum StreakRewardType { coins, card, pack }

class StreakMilestone {
  const StreakMilestone({
    required this.days,
    required this.rewardType,
    required this.rewardLabel,
    this.coins,
    this.cardTier,
    this.packId,
  });

  final int days;
  final StreakRewardType rewardType;
  final String rewardLabel;
  final int? coins;
  final CardTier? cardTier;
  final String? packId;
}

const streakMilestones = <StreakMilestone>[
  StreakMilestone(
    days: 7,
    rewardType: StreakRewardType.coins,
    rewardLabel: '250 OZ COINS',
    coins: 250,
  ),
  StreakMilestone(
    days: 25,
    rewardType: StreakRewardType.coins,
    rewardLabel: '750 OZ COINS',
    coins: 750,
  ),
  StreakMilestone(
    days: 50,
    rewardType: StreakRewardType.card,
    rewardLabel: 'GOLD CARD',
    cardTier: CardTier.gold,
  ),
  StreakMilestone(
    days: 100,
    rewardType: StreakRewardType.card,
    rewardLabel: 'PLATINUM CARD',
    cardTier: CardTier.platinum,
  ),
  StreakMilestone(
    days: 250,
    rewardType: StreakRewardType.pack,
    rewardLabel: 'GOLD PACK',
    packId: 'gold',
  ),
  StreakMilestone(
    days: 365,
    rewardType: StreakRewardType.pack,
    rewardLabel: 'ELITE PACK',
    packId: 'elite',
  ),
];

class StreakCelebration {
  const StreakCelebration({
    required this.id,
    required this.type,
    required this.streak,
    required this.activity,
    this.milestoneDays,
  });

  factory StreakCelebration.fromJson(Map<String, dynamic> json) =>
      StreakCelebration(
        id: json['id'] as String,
        type: StreakCelebrationType.values.byName(json['type'] as String),
        streak: json['streak'] as int,
        activity: StreakActivity.values.byName(json['activity'] as String),
        milestoneDays: json['milestoneDays'] as int?,
      );

  final String id;
  final StreakCelebrationType type;
  final int streak;
  final StreakActivity activity;
  final int? milestoneDays;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'streak': streak,
    'activity': activity.name,
    'milestoneDays': milestoneDays,
  };
}

class StreakSnapshot {
  const StreakSnapshot({
    required this.activeDays,
    required this.activitiesByDay,
    required this.claimedMilestones,
    required this.announcedMilestones,
    required this.celebrationQueue,
  });

  factory StreakSnapshot.seeded(DateTime now) {
    final today = dateOnly(now);
    List<String> trailingDays(int count) => [
      for (var offset = count; offset >= 1; offset--)
        streakDayKey(today.subtract(Duration(days: offset))),
    ];

    final overall = trailingDays(6);
    final predict = trailingDays(5);
    final games = trailingDays(3);
    final pitchDuel = trailingDays(2);
    final penalty = trailingDays(3);
    final pick = [overall.first];
    final activities = <String, List<StreakActivity>>{};

    void addActivities(List<String> days, StreakActivity activity) {
      for (final day in days) {
        final current = activities.putIfAbsent(day, () => []);
        if (!current.contains(activity)) current.add(activity);
      }
    }

    addActivities(predict, StreakActivity.predict);
    addActivities(pick, StreakActivity.pick);
    addActivities(pitchDuel, StreakActivity.pitchDuel);
    addActivities(penalty, StreakActivity.penaltyShootout);

    return StreakSnapshot(
      activeDays: {
        StreakCategory.overall: overall,
        StreakCategory.predict: predict,
        StreakCategory.pick: pick,
        StreakCategory.games: games,
        StreakCategory.pitchDuel: pitchDuel,
        StreakCategory.penaltyShootout: penalty,
      },
      activitiesByDay: activities,
      claimedMilestones: const {},
      announcedMilestones: const {},
      celebrationQueue: const [],
    );
  }

  factory StreakSnapshot.fromJson(Map<String, dynamic> json) {
    final rawActive = Map<String, dynamic>.from(
      json['activeDays'] as Map? ?? const {},
    );
    final rawActivities = Map<String, dynamic>.from(
      json['activitiesByDay'] as Map? ?? const {},
    );
    return StreakSnapshot(
      activeDays: {
        for (final category in StreakCategory.values)
          category: List<String>.from(
            rawActive[category.name] as List? ?? const [],
          ),
      },
      activitiesByDay: {
        for (final entry in rawActivities.entries)
          entry.key: (entry.value as List)
              .map((item) => StreakActivity.values.byName(item as String))
              .toList(),
      },
      claimedMilestones: Set<int>.from(
        json['claimedMilestones'] as List? ?? const [],
      ),
      announcedMilestones: Set<int>.from(
        json['announcedMilestones'] as List? ?? const [],
      ),
      celebrationQueue: (json['celebrationQueue'] as List? ?? const [])
          .map(
            (item) => StreakCelebration.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final Map<StreakCategory, List<String>> activeDays;
  final Map<String, List<StreakActivity>> activitiesByDay;
  final Set<int> claimedMilestones;
  final Set<int> announcedMilestones;
  final List<StreakCelebration> celebrationQueue;

  int current(StreakCategory category, {DateTime? now}) {
    final days = activeDays[category] ?? const [];
    if (days.isEmpty) return 0;
    final daySet = days.toSet();
    final today = dateOnly(now ?? DateTime.now());
    var cursor = today;
    if (!daySet.contains(streakDayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!daySet.contains(streakDayKey(cursor))) return 0;
    }
    var count = 0;
    while (daySet.contains(streakDayKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int best(StreakCategory category) {
    final sorted =
        (activeDays[category] ?? const [])
            .map(parseStreakDayKey)
            .whereType<DateTime>()
            .toList()
          ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      run = previous != null && day.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  bool activeOn(StreakCategory category, DateTime day) =>
      (activeDays[category] ?? const []).contains(streakDayKey(day));

  List<StreakActivity> activitiesOn(DateTime day) =>
      activitiesByDay[streakDayKey(day)] ?? const [];

  StreakMilestone? get nextMilestone {
    final value = current(StreakCategory.overall);
    for (final milestone in streakMilestones) {
      if (milestone.days > value) return milestone;
    }
    return null;
  }

  List<StreakMilestone> get claimableMilestones {
    return [
      for (final milestone in streakMilestones)
        if (announcedMilestones.contains(milestone.days) &&
            !claimedMilestones.contains(milestone.days))
          milestone,
    ];
  }

  StreakSnapshot record(StreakActivity activity, DateTime occurredAt) {
    final key = streakDayKey(occurredAt);
    final nextActive = {
      for (final entry in activeDays.entries)
        entry.key: List<String>.from(entry.value),
    };
    final nextActivities = {
      for (final entry in activitiesByDay.entries)
        entry.key: List<StreakActivity>.from(entry.value),
    };
    final categories = <StreakCategory>[
      StreakCategory.overall,
      switch (activity) {
        StreakActivity.predict => StreakCategory.predict,
        StreakActivity.pick => StreakCategory.pick,
        StreakActivity.pitchDuel => StreakCategory.pitchDuel,
        StreakActivity.penaltyShootout => StreakCategory.penaltyShootout,
        StreakActivity.guessPlayer => StreakCategory.games,
      },
      if (activity == StreakActivity.pitchDuel ||
          activity == StreakActivity.penaltyShootout)
        StreakCategory.games,
    ];
    for (final category in categories) {
      final days = nextActive.putIfAbsent(category, () => []);
      if (!days.contains(key)) {
        days.add(key);
        days.sort();
      }
    }
    final activities = nextActivities.putIfAbsent(key, () => []);
    if (!activities.contains(activity)) activities.add(activity);

    var next = copyWith(
      activeDays: nextActive,
      activitiesByDay: nextActivities,
    );
    final wasOverallActive = activeOn(StreakCategory.overall, occurredAt);
    if (wasOverallActive) return next;

    final streak = next.current(StreakCategory.overall, now: occurredAt);
    final queue = List<StreakCelebration>.from(next.celebrationQueue)
      ..add(
        StreakCelebration(
          id: 'daily-$key',
          type: StreakCelebrationType.daily,
          streak: streak,
          activity: activity,
        ),
      );
    final announced = Set<int>.from(next.announcedMilestones);
    for (final milestone in streakMilestones) {
      if (milestone.days <= streak && !announced.contains(milestone.days)) {
        announced.add(milestone.days);
        queue.add(
          StreakCelebration(
            id: 'milestone-${milestone.days}-$key',
            type: StreakCelebrationType.milestone,
            streak: streak,
            activity: activity,
            milestoneDays: milestone.days,
          ),
        );
      }
    }
    return next.copyWith(
      celebrationQueue: queue,
      announcedMilestones: announced,
    );
  }

  StreakSnapshot copyWith({
    Map<StreakCategory, List<String>>? activeDays,
    Map<String, List<StreakActivity>>? activitiesByDay,
    Set<int>? claimedMilestones,
    Set<int>? announcedMilestones,
    List<StreakCelebration>? celebrationQueue,
  }) => StreakSnapshot(
    activeDays: activeDays ?? this.activeDays,
    activitiesByDay: activitiesByDay ?? this.activitiesByDay,
    claimedMilestones: claimedMilestones ?? this.claimedMilestones,
    announcedMilestones: announcedMilestones ?? this.announcedMilestones,
    celebrationQueue: celebrationQueue ?? this.celebrationQueue,
  );

  Map<String, dynamic> toJson() => {
    'activeDays': {
      for (final entry in activeDays.entries) entry.key.name: entry.value,
    },
    'activitiesByDay': {
      for (final entry in activitiesByDay.entries)
        entry.key: entry.value.map((activity) => activity.name).toList(),
    },
    'claimedMilestones': claimedMilestones.toList(),
    'announcedMilestones': announcedMilestones.toList(),
    'celebrationQueue': celebrationQueue
        .map((celebration) => celebration.toJson())
        .toList(),
  };
}

DateTime dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String streakDayKey(DateTime value) {
  final day = dateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

DateTime? parseStreakDayKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String streakActivityLabel(StreakActivity activity) => switch (activity) {
  StreakActivity.predict => 'Prediction submitted',
  StreakActivity.pick => 'Pick confirmed',
  StreakActivity.pitchDuel => 'Pitch Duel completed',
  StreakActivity.penaltyShootout => 'Penalty Shootout completed',
  StreakActivity.guessPlayer => 'Daily mystery completed',
};

String streakCategoryLabel(StreakCategory category) => switch (category) {
  StreakCategory.overall => 'Overall',
  StreakCategory.predict => 'Predict',
  StreakCategory.pick => 'Pick',
  StreakCategory.games => 'Games',
  StreakCategory.pitchDuel => 'Pitch Duel',
  StreakCategory.penaltyShootout => 'Penalty Shootout',
};
