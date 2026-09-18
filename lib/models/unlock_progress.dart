import '../config/game_ladder.dart';
import '../config/sport_modules.dart';
import 'sport_match.dart';

enum UnlockRevealKind { game, sport, questComplete }

/// A queued "moment" the app root plays once the player is free
/// (NEW GAME UNLOCKED / SPORT UNLOCKED / BEGINNER'S QUEST COMPLETE).
class UnlockReveal {
  const UnlockReveal.game(ArcadeGame this.game)
    : kind = UnlockRevealKind.game,
      sport = null;
  const UnlockReveal.sport(Sport this.sport)
    : kind = UnlockRevealKind.sport,
      game = null;
  const UnlockReveal.questComplete(Sport this.sport)
    : kind = UnlockRevealKind.questComplete,
      game = null;

  final UnlockRevealKind kind;
  final ArcadeGame? game;
  final Sport? sport;

  Sport get targetSport => game?.sport ?? sport!;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (game != null) 'game': game!.name,
    if (sport != null) 'sport': sport!.name,
  };

  static UnlockReveal? fromJson(Map<String, dynamic> json) {
    final kind = UnlockRevealKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final game = ArcadeGame.values
        .where((g) => g.name == json['game'])
        .firstOrNull;
    final sport = Sport.values
        .where((s) => s.name == json['sport'])
        .firstOrNull;
    return switch (kind) {
      UnlockRevealKind.game when game != null => UnlockReveal.game(game),
      UnlockRevealKind.sport when sport != null => UnlockReveal.sport(sport),
      UnlockRevealKind.questComplete when sport != null =>
        UnlockReveal.questComplete(sport),
      _ => null,
    };
  }
}

/// Result of recording a finished game against the Beginner's Quest.
typedef UnlockPlayResult = ({
  UnlockProgress progress,
  bool stepCleared,
  ArcadeGame? unlockedGame,
  bool questCompleted,
});

/// Which sports and games a player can open, plus their Beginner's Quest
/// position per sport.
///
/// Gating is only active once onboarding has chosen a [homeSport]. An
/// unmanaged snapshot (no home sport) and a [grandfathered] one (profile that
/// existed before unlocks shipped) keep everything open.
class UnlockProgress {
  const UnlockProgress({
    this.grandfathered = false,
    this.homeSport,
    this.unlockedSports = const {},
    this.ladderReached = const {},
    this.completedQuests = const {},
    this.processedIds = const {},
    this.rookieTicketsUsed = const {},
    this.pendingReveals = const [],
  });

  const UnlockProgress.grandfathered() : this(grandfathered: true);

  /// A brand-new player: only [sport] and its first game are open.
  factory UnlockProgress.fresh(Sport sport) => UnlockProgress(
    homeSport: sport,
    unlockedSports: {sport},
    ladderReached: {sport: 1},
  );

  final bool grandfathered;
  final Sport? homeSport;
  final Set<Sport> unlockedSports;

  /// How many games of each sport's ladder are open (at least 1).
  final Map<Sport, int> ladderReached;
  final Set<Sport> completedQuests;

  /// `game:sourceId` identities already counted, so replays never double-step.
  final Set<String> processedIds;

  /// Sports whose free first quiz entry (ROOKIE TICKET) has been spent.
  final Set<Sport> rookieTicketsUsed;
  final List<UnlockReveal> pendingReveals;

  bool get gated => homeSport != null && !grandfathered;

  bool isSportUnlocked(Sport sport) => !gated || unlockedSports.contains(sport);

  int reachedFor(Sport sport) {
    final ladder = sportGameLadder[sport]!;
    if (!gated) return ladder.length;
    return (ladderReached[sport] ?? 1).clamp(1, ladder.length);
  }

  bool isGameUnlocked(ArcadeGame game) =>
      !gated ||
      (isSportUnlocked(game.sport) &&
          game.ladderIndex < reachedFor(game.sport));

  bool isQuestActive(Sport sport) =>
      gated && isSportUnlocked(sport) && !completedQuests.contains(sport);

  /// The game the Beginner's Quest currently asks the player to finish.
  ArcadeGame? currentStep(Sport sport) {
    if (!isQuestActive(sport)) return null;
    return sportGameLadder[sport]![reachedFor(sport) - 1];
  }

  /// Steps cleared so far on [sport]'s ladder.
  int stepsCleared(Sport sport) {
    final ladder = sportGameLadder[sport]!;
    if (!gated || completedQuests.contains(sport)) return ladder.length;
    return reachedFor(sport) - 1;
  }

  /// Sports in hub order: unlocked (home sport first), then locked teasers.
  List<Sport> get orderedUnlockedSports => [
    if (gated && homeSport != null) homeSport!,
    for (final sport in sportTabOrder)
      if (isSportUnlocked(sport) && !(gated && sport == homeSport)) sport,
  ];

  List<Sport> get lockedSports => [
    for (final sport in sportTabOrder)
      if (!isSportUnlocked(sport)) sport,
  ];

  /// The first quiz entry of an active quest is free when the quiz is the step.
  bool hasRookieTicket(Sport sport) =>
      currentStep(sport)?.isQuiz == true && !rookieTicketsUsed.contains(sport);

  UnlockProgress copyWith({
    bool? grandfathered,
    Sport? homeSport,
    Set<Sport>? unlockedSports,
    Map<Sport, int>? ladderReached,
    Set<Sport>? completedQuests,
    Set<String>? processedIds,
    Set<Sport>? rookieTicketsUsed,
    List<UnlockReveal>? pendingReveals,
  }) => UnlockProgress(
    grandfathered: grandfathered ?? this.grandfathered,
    homeSport: homeSport ?? this.homeSport,
    unlockedSports: unlockedSports ?? this.unlockedSports,
    ladderReached: ladderReached ?? this.ladderReached,
    completedQuests: completedQuests ?? this.completedQuests,
    processedIds: processedIds ?? this.processedIds,
    rookieTicketsUsed: rookieTicketsUsed ?? this.rookieTicketsUsed,
    pendingReveals: pendingReveals ?? this.pendingReveals,
  );

  /// Onboarding picked [sport] as home. A grandfathered profile only records
  /// the choice; an active one also opens that sport (re-onboarding after a
  /// logout never re-locks what was already earned).
  UnlockProgress chooseHomeSport(Sport sport) {
    if (grandfathered) return copyWith(homeSport: sport);
    return copyWith(
      homeSport: sport,
      unlockedSports: {...unlockedSports, sport},
      ladderReached: {sport: 1, ...ladderReached},
    );
  }

  UnlockProgress unlockSport(Sport sport) {
    if (isSportUnlocked(sport)) return this;
    return copyWith(
      unlockedSports: {...unlockedSports, sport},
      ladderReached: {...ladderReached, sport: 1},
      pendingReveals: [...pendingReveals, UnlockReveal.sport(sport)],
    );
  }

  UnlockProgress useRookieTicket(Sport sport) =>
      copyWith(rookieTicketsUsed: {...rookieTicketsUsed, sport});

  UnlockProgress consumeReveal() => pendingReveals.isEmpty
      ? this
      : copyWith(pendingReveals: pendingReveals.sublist(1));

  /// Counts a finished [game]. Only the quest's current step advances the
  /// ladder; replays of earlier games (and repeated [sourceId]s) are no-ops.
  UnlockPlayResult recordPlay(ArcadeGame game, String sourceId) {
    final none = (
      progress: this,
      stepCleared: false,
      unlockedGame: null,
      questCompleted: false,
    );
    final identity = '${game.name}:$sourceId';
    if (sourceId.isEmpty ||
        processedIds.contains(identity) ||
        currentStep(game.sport) != game) {
      return none;
    }
    final ladder = sportGameLadder[game.sport]!;
    final index = game.ladderIndex;
    final processed = {...processedIds, identity};
    if (index < ladder.length - 1) {
      final next = ladder[index + 1];
      return (
        progress: copyWith(
          processedIds: processed,
          ladderReached: {...ladderReached, game.sport: index + 2},
          pendingReveals: [...pendingReveals, UnlockReveal.game(next)],
        ),
        stepCleared: true,
        unlockedGame: next,
        questCompleted: false,
      );
    }
    return (
      progress: copyWith(
        processedIds: processed,
        completedQuests: {...completedQuests, game.sport},
        pendingReveals: [
          ...pendingReveals,
          UnlockReveal.questComplete(game.sport),
        ],
      ),
      stepCleared: true,
      unlockedGame: null,
      questCompleted: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'grandfathered': grandfathered,
    if (homeSport != null) 'homeSport': homeSport!.name,
    'unlockedSports': [for (final s in unlockedSports) s.name],
    'ladderReached': {
      for (final e in ladderReached.entries) e.key.name: e.value,
    },
    'completedQuests': [for (final s in completedQuests) s.name],
    'processedIds': processedIds.toList(),
    'rookieTicketsUsed': [for (final s in rookieTicketsUsed) s.name],
    'pendingReveals': [for (final r in pendingReveals) r.toJson()],
  };

  factory UnlockProgress.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported unlock progress version');
    }
    Sport? sportNamed(Object? name) =>
        Sport.values.where((s) => s.name == name).firstOrNull;
    Set<Sport> sports(Object? raw) => {
      for (final name in (raw as List? ?? const [])) ?sportNamed(name),
    };
    return UnlockProgress(
      grandfathered: json['grandfathered'] as bool? ?? false,
      homeSport: sportNamed(json['homeSport']),
      unlockedSports: sports(json['unlockedSports']),
      ladderReached: {
        for (final e in (json['ladderReached'] as Map? ?? const {}).entries)
          ?sportNamed(e.key): e.value as int,
      },
      completedQuests: sports(json['completedQuests']),
      processedIds: Set<String>.from(json['processedIds'] as List? ?? const []),
      rookieTicketsUsed: sports(json['rookieTicketsUsed']),
      pendingReveals: [
        for (final raw in (json['pendingReveals'] as List? ?? const []))
          ?UnlockReveal.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }
}
