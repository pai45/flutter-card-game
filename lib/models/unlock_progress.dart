import '../config/game_ladder.dart';
import '../config/sport_modules.dart';
import 'sport_match.dart';

enum UnlockRevealKind {
  game,
  sport,
  questComplete,
  graduation,
  missionComplete,
}

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
  const UnlockReveal.graduation(ArcadeGame this.game)
    : kind = UnlockRevealKind.graduation,
      sport = null;
  const UnlockReveal.missionComplete(ArcadeGame this.game)
    : kind = UnlockRevealKind.missionComplete,
      sport = null;

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
      UnlockRevealKind.graduation when game != null => UnlockReveal.graduation(
        game,
      ),
      UnlockRevealKind.missionComplete when game != null =>
        UnlockReveal.missionComplete(game),
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
  bool graduated,
});

/// A session-scoped receipt. Never restored as a fresh reward on relaunch.
class QuestCompletionReceipt {
  const QuestCompletionReceipt({
    required this.game,
    required this.sourceId,
    required this.completed,
    required this.total,
    required this.graduated,
    required this.questCompleted,
    this.nextGame,
  });
  final ArcadeGame game;
  final String sourceId;
  final int completed;
  final int total;
  final bool graduated;
  final bool questCompleted;
  final ArcadeGame? nextGame;
  String get id => '${game.name}:$sourceId';
}

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
    this.completedGames = const {},
    this.activeGames = const {},
    this.completedQuests = const {},
    this.processedIds = const {},
    this.rookieTicketsUsed = const {},
    this.pendingReveals = const [],
  });

  const UnlockProgress.grandfathered() : this(grandfathered: true);

  /// A brand-new player chooses the first mission after entering Games.
  factory UnlockProgress.fresh(Sport sport) =>
      UnlockProgress(homeSport: sport, unlockedSports: {sport});

  final bool grandfathered;
  final Sport? homeSport;
  final Set<Sport> unlockedSports;

  /// Compatibility input for older in-memory presets. New saves use identities.
  final Map<Sport, int> ladderReached;
  final Map<Sport, List<ArcadeGame>> completedGames;
  final Map<Sport, ArcadeGame> activeGames;
  final Set<Sport> completedQuests;

  /// `game:sourceId` identities already counted, so replays never double-step.
  final Set<String> processedIds;

  /// Sports whose free first quiz entry (ROOKIE TICKET) has been spent.
  final Set<Sport> rookieTicketsUsed;
  final List<UnlockReveal> pendingReveals;

  bool get gated => homeSport != null && !grandfathered;

  /// The one-time rookie phase is owned by the home sport. Unlocking another
  /// sport early never skips it, and later sport quests never re-enter it.
  bool get initialQuestActive =>
      gated &&
      homeSport != null &&
      stepsCleared(homeSport!) < beginnerChapterLength;

  bool get dailyQuestsUnlocked => !initialQuestActive;

  /// Only progression-managed careers get the combined quest board. Legacy
  /// grandfathered profiles keep the familiar TODAY tab.
  bool get questListEnabled => gated && dailyQuestsUnlocked;

  String chapterLabel(Sport sport) =>
      stepsCleared(sport) >= beginnerChapterLength ? 'EXPLORER' : 'BEGINNER';

  String missionLabel(Sport sport) {
    final cleared = stepsCleared(sport);
    final explorer = cleared >= beginnerChapterLength;
    final offset = explorer ? beginnerChapterLength : 0;
    final total = explorer
        ? sportGameLadder[sport]!.length - offset
        : beginnerChapterLength;
    return '${chapterLabel(sport)} · MISSION ${cleared - offset + 1} OF $total';
  }

  /// Active Beginner's Quests in the same order as the sport hub.
  List<Sport> get activeQuestSports => [
    for (final sport in orderedUnlockedSports)
      if (isQuestActive(sport)) sport,
  ];

  bool isSportUnlocked(Sport sport) => !gated || unlockedSports.contains(sport);

  int reachedFor(Sport sport) {
    final ladder = sportGameLadder[sport]!;
    if (!gated) return ladder.length;
    return (stepsCleared(sport) + 1).clamp(1, ladder.length);
  }

  List<ArcadeGame> completedFor(Sport sport) {
    final ladder = sportGameLadder[sport]!;
    if (!gated) return ladder;
    if (completedQuests.contains(sport)) {
      return completedGames[sport]?.length == ladder.length
          ? completedGames[sport]!
          : ladder;
    }
    return completedGames[sport] ??
        ladder
            .take(((ladderReached[sport] ?? 1) - 1).clamp(0, ladder.length))
            .toList();
  }

  List<ArcadeGame> remainingFor(Sport sport) => [
    for (final game in sportGameLadder[sport]!)
      if (!completedFor(sport).contains(game)) game,
  ];

  bool needsSelection(Sport sport) =>
      isQuestActive(sport) && currentStep(sport) == null;

  bool canSelect(ArcadeGame game) =>
      needsSelection(game.sport) && !completedFor(game.sport).contains(game);

  UnlockProgress selectGame(ArcadeGame game) => canSelect(game)
      ? copyWith(activeGames: {...resolvedActiveGames, game.sport: game})
      : this;

  Map<Sport, ArcadeGame> get resolvedActiveGames => {
    for (final sport in Sport.values)
      if (currentStep(sport) case final ArcadeGame game) sport: game,
  };

  List<ArcadeGame> routeFor(Sport sport) => [
    ...completedFor(sport),
    if (currentStep(sport) case final ArcadeGame game) game,
    for (final game in remainingFor(sport))
      if (game != currentStep(sport)) game,
  ];

  bool isGameUnlocked(ArcadeGame game) =>
      !gated ||
      (isSportUnlocked(game.sport) &&
          (completedFor(game.sport).contains(game) ||
              currentStep(game.sport) == game));

  bool isQuestActive(Sport sport) =>
      gated && isSportUnlocked(sport) && !completedQuests.contains(sport);

  /// The game the Beginner's Quest currently asks the player to finish.
  ArcadeGame? currentStep(Sport sport) {
    if (!isQuestActive(sport)) return null;
    final active = activeGames[sport];
    if (active != null) return active;
    final reached = ladderReached[sport] ?? 1;
    return reached > 1
        ? sportGameLadder[sport]![(reached - 1).clamp(
            0,
            sportGameLadder[sport]!.length - 1,
          )]
        : null;
  }

  /// Steps cleared so far on [sport]'s ladder.
  int stepsCleared(Sport sport) {
    final ladder = sportGameLadder[sport]!;
    if (!gated || completedQuests.contains(sport)) return ladder.length;
    return completedFor(sport).length;
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
  bool hasRookieTicket(Sport sport) => currentStep(sport)?.isQuiz == true;

  UnlockProgress copyWith({
    bool? grandfathered,
    Sport? homeSport,
    Set<Sport>? unlockedSports,
    Map<Sport, int>? ladderReached,
    Map<Sport, List<ArcadeGame>>? completedGames,
    Map<Sport, ArcadeGame>? activeGames,
    Set<Sport>? completedQuests,
    Set<String>? processedIds,
    Set<Sport>? rookieTicketsUsed,
    List<UnlockReveal>? pendingReveals,
  }) => UnlockProgress(
    grandfathered: grandfathered ?? this.grandfathered,
    homeSport: homeSport ?? this.homeSport,
    unlockedSports: unlockedSports ?? this.unlockedSports,
    ladderReached: ladderReached ?? const {},
    completedGames:
        completedGames ??
        {
          for (final sport in Sport.values)
            sport: gated
                ? completedFor(sport)
                : this.completedGames[sport] ?? const [],
        },
    activeGames: activeGames ?? resolvedActiveGames,
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
    );
  }

  UnlockProgress unlockSport(Sport sport) {
    if (isSportUnlocked(sport)) return this;
    return copyWith(
      unlockedSports: {...unlockedSports, sport},
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
      graduated: false,
    );
    final identity = '${game.name}:$sourceId';
    if (sourceId.isEmpty ||
        processedIds.contains(identity) ||
        currentStep(game.sport) != game) {
      return none;
    }
    final ladder = sportGameLadder[game.sport]!;
    final completed = [...completedFor(game.sport), game];
    final active = {...resolvedActiveGames}..remove(game.sport);
    final processed = {...processedIds, identity};
    final graduated =
        initialQuestActive &&
        game.sport == homeSport &&
        completed.length == beginnerChapterLength;
    if (completed.length < ladder.length) {
      return (
        progress: copyWith(
          processedIds: processed,
          completedGames: {
            ...completedGames,
            for (final sport in Sport.values)
              sport: sport == game.sport ? completed : completedFor(sport),
          },
          activeGames: active,
          pendingReveals: [
            ...pendingReveals,
            graduated
                ? UnlockReveal.graduation(game)
                : UnlockReveal.missionComplete(game),
          ],
        ),
        stepCleared: true,
        unlockedGame: null,
        questCompleted: false,
        graduated: graduated,
      );
    }
    return (
      progress: copyWith(
        processedIds: processed,
        completedQuests: {...completedQuests, game.sport},
        completedGames: {
          for (final sport in Sport.values)
            sport: sport == game.sport ? completed : completedFor(sport),
        },
        activeGames: active,
        pendingReveals: [
          ...pendingReveals,
          UnlockReveal.questComplete(game.sport),
        ],
      ),
      stepCleared: true,
      unlockedGame: null,
      questCompleted: true,
      graduated: graduated,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'grandfathered': grandfathered,
    if (homeSport != null) 'homeSport': homeSport!.name,
    'unlockedSports': [for (final s in unlockedSports) s.name],
    'completedGames': {
      for (final sport in unlockedSports)
        sport.name: [for (final game in completedFor(sport)) game.name],
    },
    'activeGames': {
      for (final e in resolvedActiveGames.entries) e.key.name: e.value.name,
    },
    'completedQuests': [for (final s in completedQuests) s.name],
    'processedIds': processedIds.toList(),
    'rookieTicketsUsed': [for (final s in rookieTicketsUsed) s.name],
    'pendingReveals': [for (final r in pendingReveals) r.toJson()],
  };

  factory UnlockProgress.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Unsupported unlock progress version');
    }
    Sport? sportNamed(Object? name) =>
        Sport.values.where((s) => s.name == name).firstOrNull;
    Set<Sport> sports(Object? raw) => {
      for (final name in (raw as List? ?? const [])) ?sportNamed(name),
    };
    ArcadeGame? gameNamed(Object? name) =>
        ArcadeGame.values.where((g) => g.name == name).firstOrNull;
    final completedQuests = sports(json['completedQuests']);
    final completed = <Sport, List<ArcadeGame>>{};
    final active = <Sport, ArcadeGame>{};
    for (final sport in sports(json['unlockedSports'])) {
      final ladder = sportGameLadder[sport]!;
      if (json['version'] == 1) {
        final reached =
            ((json['ladderReached'] as Map? ?? const {})[sport.name] as int? ??
                    1)
                .clamp(1, ladder.length);
        completed[sport] = completedQuests.contains(sport)
            ? ladder.toList()
            : ladder.take(reached - 1).toList();
        if (!completedQuests.contains(sport) && reached > 1) {
          active[sport] = ladder[reached - 1];
        }
      } else {
        completed[sport] = {
          for (final name
              in ((json['completedGames'] as Map? ?? const {})[sport.name]
                      as List? ??
                  const []))
            if (gameNamed(name) case final ArcadeGame game
                when game.sport == sport)
              game,
        }.toList();
        final game = gameNamed(
          (json['activeGames'] as Map? ?? const {})[sport.name],
        );
        if (game != null &&
            game.sport == sport &&
            !completed[sport]!.contains(game) &&
            !completedQuests.contains(sport)) {
          active[sport] = game;
        }
        if (completed[sport]!.length == ladder.length) {
          completedQuests.add(sport);
        }
      }
    }
    return UnlockProgress(
      grandfathered: json['grandfathered'] as bool? ?? false,
      homeSport: sportNamed(json['homeSport']),
      unlockedSports: sports(json['unlockedSports']),
      completedGames: completed,
      activeGames: active,
      completedQuests: completedQuests,
      processedIds: Set<String>.from(json['processedIds'] as List? ?? const []),
      rookieTicketsUsed: sports(json['rookieTicketsUsed']),
      pendingReveals: [
        for (final raw in (json['pendingReveals'] as List? ?? const []))
          ?UnlockReveal.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }
}
