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

/// `shieldSaved` fires when banked shields bridge missed days; `shieldEarned`
/// fires when a Daily Sweep forges a new shield.
enum StreakCelebrationType { daily, milestone, shieldSaved, shieldEarned }

enum StreakRewardType { coins, card, pack }

/// Most shields a player can bank. Shields only protect the overall streak.
const streakShieldCap = 2;

/// Local hour after which an unsecured live streak is flagged AT RISK.
const streakRiskHour = 18;

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
    this.shields,
    this.shieldsUsed,
  });

  factory StreakCelebration.fromJson(Map<String, dynamic> json) =>
      StreakCelebration(
        id: json['id'] as String,
        type: StreakCelebrationType.values.byName(json['type'] as String),
        streak: json['streak'] as int,
        activity: StreakActivity.values.byName(json['activity'] as String),
        milestoneDays: json['milestoneDays'] as int?,
        shields: json['shields'] as int?,
        shieldsUsed: json['shieldsUsed'] as int?,
      );

  final String id;
  final StreakCelebrationType type;
  final int streak;
  final StreakActivity activity;
  final int? milestoneDays;

  /// Shields banked once this moment resolves (shield moments only).
  final int? shields;

  /// Missed days a `shieldSaved` moment bridged.
  final int? shieldsUsed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'streak': streak,
    'activity': activity.name,
    'milestoneDays': milestoneDays,
    if (shields != null) 'shields': shields,
    if (shieldsUsed != null) 'shieldsUsed': shieldsUsed,
  };
}

class StreakSnapshot {
  const StreakSnapshot({
    required this.activeDays,
    required this.activitiesByDay,
    required this.claimedMilestones,
    required this.announcedMilestones,
    required this.celebrationQueue,
    this.shields = 0,
    this.shieldedDays = const [],
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
      shields: (json['shields'] as int? ?? 0).clamp(0, streakShieldCap).toInt(),
      shieldedDays: List<String>.from(
        json['shieldedDays'] as List? ?? const [],
      ),
    );
  }

  final Map<StreakCategory, List<String>> activeDays;
  final Map<String, List<StreakActivity>> activitiesByDay;
  final Set<int> claimedMilestones;
  final Set<int> announcedMilestones;
  final List<StreakCelebration> celebrationQueue;

  /// Banked shields (0..[streakShieldCap]).
  final int shields;

  /// Missed days a shield bridged. They keep the overall chain alive but never
  /// add to its count.
  final List<String> shieldedDays;

  Set<String> _bridgeFor(StreakCategory category) =>
      category == StreakCategory.overall ? shieldedDays.toSet() : const {};

  int current(StreakCategory category, {DateTime? now}) {
    final days = activeDays[category] ?? const [];
    if (days.isEmpty) return 0;
    final daySet = days.toSet();
    final bridge = _bridgeFor(category);
    bool inChain(DateTime day) {
      final key = streakDayKey(day);
      return daySet.contains(key) || bridge.contains(key);
    }

    final today = dateOnly(now ?? DateTime.now());
    var cursor = today;
    if (!inChain(cursor)) {
      cursor = _shiftDays(cursor, -1);
      if (!inChain(cursor)) return 0;
    }
    var count = 0;
    while (inChain(cursor)) {
      if (daySet.contains(streakDayKey(cursor))) count++;
      cursor = _shiftDays(cursor, -1);
    }
    return count;
  }

  int best(StreakCategory category) {
    final active = (activeDays[category] ?? const []).toSet();
    final sorted =
        {...active, ..._bridgeFor(category)}
            .map(parseStreakDayKey)
            .whereType<DateTime>()
            .toList()
          ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      if (previous == null || _daysBetween(previous, day) != 1) run = 0;
      if (active.contains(streakDayKey(day))) run++;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  bool activeOn(StreakCategory category, DateTime day) =>
      (activeDays[category] ?? const []).contains(streakDayKey(day));

  bool shieldedOn(DateTime day) => shieldedDays.contains(streakDayKey(day));

  /// A live overall streak that today's activity hasn't secured yet, late
  /// enough in the local day that missing it is a real threat.
  bool atRisk(DateTime now) =>
      now.hour >= streakRiskHour &&
      !activeOn(StreakCategory.overall, now) &&
      current(StreakCategory.overall, now: now) > 0;

  /// Bridges the missed days between the last chain day and [now] when the
  /// banked shields cover the whole gap, queueing a `shieldSaved` moment.
  /// Returns `this` when there is no gap or the gap is too wide — shields
  /// are never spent on a streak they cannot save.
  StreakSnapshot applyShields(DateTime now) {
    if (shields <= 0) return this;
    final today = dateOnly(now);
    DateTime? last;
    for (final key in {
      ...activeDays[StreakCategory.overall] ?? const <String>[],
      ...shieldedDays,
    }) {
      final day = parseStreakDayKey(key);
      if (day == null || !day.isBefore(today)) continue;
      if (last == null || day.isAfter(last)) last = day;
    }
    if (last == null) return this;
    final gap = _daysBetween(last, today) - 1;
    if (gap <= 0 || gap > shields) return this;
    final bridged = [
      for (var offset = 1; offset <= gap; offset++)
        streakDayKey(_shiftDays(last, offset)),
    ];
    final remaining = shields - gap;
    final next = copyWith(
      shields: remaining,
      shieldedDays: [...shieldedDays, ...bridged]..sort(),
    );
    final lastActivities = activitiesByDay[streakDayKey(last)];
    return next.copyWith(
      celebrationQueue: [
        ...celebrationQueue,
        StreakCelebration(
          id: 'shield-saved-${streakDayKey(today)}',
          type: StreakCelebrationType.shieldSaved,
          streak: next.current(StreakCategory.overall, now: _shiftDays(last, gap)),
          activity: lastActivities?.firstOrNull ?? StreakActivity.predict,
          shields: remaining,
          shieldsUsed: gap,
        ),
      ],
    );
  }

  /// Forges one shield (capped) and queues a `shieldEarned` moment. Returns
  /// `this` at the cap so a full bank never produces a hollow celebration.
  StreakSnapshot grantShield(DateTime now) {
    if (shields >= streakShieldCap) return this;
    final banked = shields + 1;
    return copyWith(
      shields: banked,
      celebrationQueue: [
        ...celebrationQueue,
        StreakCelebration(
          id: 'shield-earned-${streakDayKey(now)}',
          type: StreakCelebrationType.shieldEarned,
          streak: current(StreakCategory.overall, now: now),
          activity: StreakActivity.predict,
          shields: banked,
        ),
      ],
    );
  }

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
    // A banked shield must bridge yesterday's miss before today's activity is
    // counted, otherwise the new day would start a fresh run of 1.
    final shielded = applyShields(occurredAt);
    if (!identical(shielded, this)) {
      return shielded._recordDay(activity, occurredAt);
    }
    return _recordDay(activity, occurredAt);
  }

  StreakSnapshot _recordDay(StreakActivity activity, DateTime occurredAt) {
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
    int? shields,
    List<String>? shieldedDays,
  }) => StreakSnapshot(
    activeDays: activeDays ?? this.activeDays,
    activitiesByDay: activitiesByDay ?? this.activitiesByDay,
    claimedMilestones: claimedMilestones ?? this.claimedMilestones,
    announcedMilestones: announcedMilestones ?? this.announcedMilestones,
    celebrationQueue: celebrationQueue ?? this.celebrationQueue,
    shields: shields ?? this.shields,
    shieldedDays: shieldedDays ?? this.shieldedDays,
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
    'shields': shields,
    'shieldedDays': shieldedDays,
  };
}

// Calendar-day arithmetic via DateTime(y, m, d ± n) so DST transitions (23h
// or 25h days) never skew day counts.
DateTime _shiftDays(DateTime day, int delta) =>
    DateTime(day.year, day.month, day.day + delta);

int _daysBetween(DateTime from, DateTime to) =>
    (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

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
