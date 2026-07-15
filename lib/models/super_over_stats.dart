import 'dart:math' as math;

import '../data/super_over_jerseys.dart';
import 'super_over.dart';

const int superOverProfileSchemaVersion = 2;
const int superOverHistoryLimit = 12;
const int superOverSettlementIdLimit = 256;

/// Aggregate result data for a tactical sector or shot intent.
class SuperOverPerformanceStats {
  const SuperOverPerformanceStats({
    this.attempts = 0,
    this.scoringShots = 0,
    this.runs = 0,
    this.boundaries = 0,
    this.wickets = 0,
  });

  factory SuperOverPerformanceStats.fromJson(Map<String, dynamic> json) {
    return SuperOverPerformanceStats(
      attempts: _nonNegativeInt(json['attempts']),
      scoringShots: _nonNegativeInt(json['scoringShots']),
      runs: _nonNegativeInt(json['runs']),
      boundaries: _nonNegativeInt(json['boundaries']),
      wickets: _nonNegativeInt(json['wickets']),
    );
  }

  final int attempts;
  final int scoringShots;
  final int runs;
  final int boundaries;
  final int wickets;

  Map<String, dynamic> toJson() => {
    'attempts': attempts,
    'scoringShots': scoringShots,
    'runs': runs,
    'boundaries': boundaries,
    'wickets': wickets,
  };

  SuperOverPerformanceStats add({
    required int runs,
    required bool boundary,
    required bool wicket,
  }) {
    return SuperOverPerformanceStats(
      attempts: attempts + 1,
      scoringShots: scoringShots + (runs > 0 ? 1 : 0),
      runs: this.runs + math.max(0, runs),
      boundaries: boundaries + (boundary ? 1 : 0),
      wickets: wickets + (wicket ? 1 : 0),
    );
  }
}

/// A compact, typed ball record retained in the twelve-entry local archive.
class SuperOverHistoryBall {
  const SuperOverHistoryBall({
    required this.ballNumber,
    required this.strikerCardId,
    required this.outcome,
    required this.runs,
    this.timingTier,
    this.sector,
    this.intent,
    this.openSector = false,
  });

  factory SuperOverHistoryBall.fromJson(Map<String, dynamic> json) {
    final outcome = _enumByName(
      ShotOutcome.values,
      json['outcome'],
      ShotOutcome.dot,
    );
    return SuperOverHistoryBall(
      ballNumber: _nonNegativeInt(json['ballNumber']).clamp(1, 6),
      strikerCardId: _string(json['strikerCardId']),
      outcome: outcome,
      runs: _nonNegativeInt(
        json['runs'],
        fallback: SuperOverResolution.runsForOutcome(outcome),
      ).clamp(0, 6),
      timingTier: _nullableEnumByName(TimingTier.values, json['timingTier']),
      sector: _nullableEnumByName(ShotSector.values, json['sector']),
      intent: _nullableEnumByName(ShotStyle.values, json['intent']),
      openSector: _bool(json['openSector']),
    );
  }

  final int ballNumber;
  final String strikerCardId;
  final ShotOutcome outcome;
  final int runs;
  final TimingTier? timingTier;
  final ShotSector? sector;
  final ShotStyle? intent;
  final bool openSector;

  bool get isWicket =>
      outcome == ShotOutcome.bowled || outcome == ShotOutcome.caught;

  Map<String, dynamic> toJson() => {
    'ballNumber': ballNumber,
    'strikerCardId': strikerCardId,
    'outcome': outcome.name,
    'runs': runs,
    'timingTier': timingTier?.name,
    'sector': sector?.name,
    'intent': intent?.name,
    'openSector': openSector,
  };
}

/// One settled Super Over. Deliberately contains card IDs, never card identity
/// presentation, so the fictional adapter remains the only UI identity source.
class SuperOverHistoryEntry {
  const SuperOverHistoryEntry({
    required this.matchId,
    required this.playedAt,
    required this.mode,
    required this.score,
    required this.wickets,
    required this.ballsRemaining,
    required this.ballRecords,
    required this.battingCardIds,
    required this.difficulty,
    required this.grade,
    required this.xp,
    this.target,
    this.wonChase,
    this.newRecord = false,
  });

  factory SuperOverHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawBalls = json['ballRecords'];
    final rawCards = json['battingCardIds'];
    return SuperOverHistoryEntry(
      matchId: _string(json['matchId']),
      playedAt: _utcDateFromEpoch(json['playedAtMillis']),
      mode: _enumByName(
        SuperOverMode.values,
        json['mode'],
        SuperOverMode.chase,
      ),
      score: _nonNegativeInt(json['score']),
      wickets: _nonNegativeInt(json['wickets']).clamp(0, 2),
      target: json['target'] == null ? null : _nonNegativeInt(json['target']),
      ballsRemaining: _nonNegativeInt(json['ballsRemaining']).clamp(0, 6),
      ballRecords: rawBalls is List
          ? rawBalls
                .whereType<Map>()
                .map(
                  (item) => SuperOverHistoryBall.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .take(6)
                .toList(growable: false)
          : const [],
      battingCardIds: rawCards is List
          ? rawCards.whereType<String>().take(3).toList(growable: false)
          : const [],
      difficulty: _enumByName(
        SuperOverDifficulty.values,
        json['difficulty'],
        SuperOverDifficulty.pro,
      ),
      grade: _string(json['grade'], fallback: 'C'),
      xp: _nonNegativeInt(json['xp']),
      wonChase: json['wonChase'] is bool ? json['wonChase'] as bool : null,
      newRecord: _bool(json['newRecord']),
    );
  }

  factory SuperOverHistoryEntry.fromSummary(SuperOverMatchSummary summary) {
    final completedAt = summary.completedAtEpochMs > 0
        ? summary.completedAtEpochMs
        : DateTime.now().toUtc().millisecondsSinceEpoch;
    return SuperOverHistoryEntry(
      matchId: summary.matchId,
      playedAt: DateTime.fromMillisecondsSinceEpoch(completedAt, isUtc: true),
      mode: summary.mode,
      score: summary.score,
      wickets: summary.wickets,
      target: summary.target,
      wonChase: summary.wonChase,
      ballsRemaining: summary.ballsRemaining,
      ballRecords: [
        for (final ball in summary.ballRecords)
          SuperOverHistoryBall(
            ballNumber: ball.ballNumber,
            strikerCardId: ball.strikerCardId,
            outcome: ball.outcome,
            runs: ball.runs,
            timingTier: ball.timingTier,
            sector: ball.resolvedSector,
            intent: ball.intent?.style,
            openSector: ball.scoredInOpenSector,
          ),
      ],
      battingCardIds: summary.battingCardIds,
      difficulty: summary.difficulty,
      grade: summary.grade.name.toUpperCase(),
      xp: summary.rewardBreakdown.totalXp,
      newRecord: summary.isNewRecord,
    );
  }

  final String matchId;
  final DateTime playedAt;
  final SuperOverMode mode;
  final int score;
  final int wickets;
  final int? target;
  final bool? wonChase;
  final int ballsRemaining;
  final List<SuperOverHistoryBall> ballRecords;
  final List<String> battingCardIds;
  final SuperOverDifficulty difficulty;
  final String grade;
  final int xp;
  final bool newRecord;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'playedAtMillis': playedAt.toUtc().millisecondsSinceEpoch,
    'mode': mode.name,
    'score': score,
    'wickets': wickets,
    'target': target,
    'wonChase': wonChase,
    'ballsRemaining': ballsRemaining,
    'ballRecords': ballRecords.map((ball) => ball.toJson()).toList(),
    'battingCardIds': battingCardIds.take(3).toList(),
    'difficulty': difficulty.name,
    'grade': grade,
    'xp': xp,
    'newRecord': newRecord,
  };
}

enum SuperOverAchievementId {
  firstFinish,
  iceCold,
  oneBatterJob,
  threeWayAttack,
  groundControl,
  airRaid,
  cleanOver,
  openField,
  perfectTiming,
  rescueAct,
  impossibleFinish,
  recordBreaker,
  masterFinisher,
  unitChemistry,
  allArchetypes,
}

extension SuperOverAchievementDetails on SuperOverAchievementId {
  String get label => switch (this) {
    SuperOverAchievementId.firstFinish => 'First Finish',
    SuperOverAchievementId.iceCold => 'Ice Cold',
    SuperOverAchievementId.oneBatterJob => 'One Batter Job',
    SuperOverAchievementId.threeWayAttack => 'Three-Way Attack',
    SuperOverAchievementId.groundControl => 'Ground Control',
    SuperOverAchievementId.airRaid => 'Air Raid',
    SuperOverAchievementId.cleanOver => 'Clean Over',
    SuperOverAchievementId.openField => 'Open Field',
    SuperOverAchievementId.perfectTiming => 'Perfect Timing',
    SuperOverAchievementId.rescueAct => 'Rescue Act',
    SuperOverAchievementId.impossibleFinish => 'Impossible Finish',
    SuperOverAchievementId.recordBreaker => 'Record Breaker',
    SuperOverAchievementId.masterFinisher => 'Master Finisher',
    SuperOverAchievementId.unitChemistry => 'Unit Chemistry',
    SuperOverAchievementId.allArchetypes => 'All Archetypes',
  };

  String get requirement => switch (this) {
    SuperOverAchievementId.firstFinish => 'Win the first chase',
    SuperOverAchievementId.iceCold => 'Win a chase on the final ball',
    SuperOverAchievementId.oneBatterJob =>
      'Complete a chase without changing striker',
    SuperOverAchievementId.threeWayAttack =>
      'Score in OFF, STRAIGHT and LEG in one over',
    SuperOverAchievementId.groundControl =>
      'Score 12+ using only Ground intent',
    SuperOverAchievementId.airRaid => 'Hit three sixes in one over',
    SuperOverAchievementId.cleanOver => 'Finish without losing a wicket',
    SuperOverAchievementId.openField => 'Score in the Open sector three times',
    SuperOverAchievementId.perfectTiming =>
      'Record three Perfect contacts in one over',
    SuperOverAchievementId.rescueAct =>
      'Win after losing a wicket in the first two balls',
    SuperOverAchievementId.impossibleFinish =>
      'Score 18+ from the final three balls',
    SuperOverAchievementId.recordBreaker => 'Beat the Score Attack record',
    SuperOverAchievementId.masterFinisher => 'Complete 100 Super Overs',
    SuperOverAchievementId.unitChemistry =>
      'Win with the same three-batter unit ten times',
    SuperOverAchievementId.allArchetypes =>
      'Win with each base archetype as the finishing batter',
  };
}

/// Versioned, on-device Super Over profile.
///
/// The legacy name remains to avoid breaking current callers while the JSON
/// schema is migrated from `pd_super_over_stats_v1` to the v2 profile key.
class SuperOverStats {
  const SuperOverStats({
    this.schemaVersion = superOverProfileSchemaVersion,
    this.highScore = 0,
    this.scoreAttackHighScore = 0,
    this.chaseWins = 0,
    this.chaseLosses = 0,
    this.completions = 0,
    this.totalSixes = 0,
    this.totalFours = 0,
    this.totalRuns = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.perfectContacts = 0,
    this.bestCombo = 0,
    this.objectivesCompleted = 0,
    this.highestChase = 0,
    this.finalBallWins = 0,
    this.wicketlessOvers = 0,
    this.openSectorScoringShots = 0,
    this.sectorStats = const {},
    this.intentStats = const {},
    this.batterMastery = const {},
    this.lastJersey = CricketJersey.nightCyan,
    this.difficulty = SuperOverDifficulty.pro,
    this.settings = const SuperOverSettings(),
    this.tutorialCompleted = false,
    this.tutorialVersion = 0,
    this.unlockedAchievements = const {},
    this.achievementProgress = const {},
    this.unitChemistryWins = const {},
    this.winningFinisherArchetypes = const {},
    this.history = const [],
    this.settledMatchIds = const {},
  });

  factory SuperOverStats.fromJson(Map<String, dynamic> json) {
    final chaseWins = _nonNegativeInt(json['chaseWins']);
    final chaseLosses = _nonNegativeInt(json['chaseLosses']);
    final storedSettings = _settings(json['settings']);
    final difficulty = _enumByName(
      SuperOverDifficulty.values,
      json['difficulty'],
      storedSettings.difficulty,
    );
    final rawHistory = json['history'];
    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map(
                (item) => SuperOverHistoryEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((entry) => entry.matchId.isNotEmpty)
              .toList(growable: false)
        : const <SuperOverHistoryEntry>[];
    return SuperOverStats(
      highScore: _nonNegativeInt(json['highScore']),
      scoreAttackHighScore: _nonNegativeInt(json['scoreAttackHighScore']),
      chaseWins: chaseWins,
      chaseLosses: chaseLosses,
      completions: _nonNegativeInt(
        json['completions'],
        fallback: chaseWins + chaseLosses,
      ),
      totalSixes: _nonNegativeInt(json['totalSixes']),
      totalFours: _nonNegativeInt(json['totalFours']),
      totalRuns: _nonNegativeInt(json['totalRuns']),
      currentStreak: _nonNegativeInt(json['currentStreak']),
      bestStreak: _nonNegativeInt(json['bestStreak']),
      perfectContacts: _nonNegativeInt(json['perfectContacts']),
      bestCombo: _nonNegativeInt(json['bestCombo']),
      objectivesCompleted: _nonNegativeInt(json['objectivesCompleted']),
      highestChase: _nonNegativeInt(json['highestChase']),
      finalBallWins: _nonNegativeInt(json['finalBallWins']),
      wicketlessOvers: _nonNegativeInt(json['wicketlessOvers']),
      openSectorScoringShots: _nonNegativeInt(json['openSectorScoringShots']),
      sectorStats: _sectorStats(json['sectorStats']),
      intentStats: _intentStats(json['intentStats']),
      batterMastery: _intMap(json['batterMastery']),
      lastJersey: superOverJerseyFromStoredId(
        _nullableString(json['lastJersey']) ?? _nullableString(json['jersey']),
      ),
      difficulty: difficulty,
      settings: storedSettings.copyWith(difficulty: difficulty),
      tutorialCompleted: _bool(
        json['tutorialCompleted'] ?? json['tutorialSeen'],
      ),
      tutorialVersion: _nonNegativeInt(json['tutorialVersion']),
      unlockedAchievements: _achievementSet(json['unlockedAchievements']),
      achievementProgress: _intMap(json['achievementProgress']),
      unitChemistryWins: _intMap(json['unitChemistryWins']),
      winningFinisherArchetypes: _archetypeSet(
        json['winningFinisherArchetypes'],
      ),
      history: _takeLast(history, superOverHistoryLimit),
      settledMatchIds: _takeLast(
        _stringSet(json['settledMatchIds']),
        superOverSettlementIdLimit,
      ).toSet(),
    );
  }

  final int schemaVersion;
  final int highScore;
  final int scoreAttackHighScore;
  final int chaseWins;
  final int chaseLosses;
  final int completions;
  final int totalSixes;
  final int totalFours;
  final int totalRuns;
  final int currentStreak;
  final int bestStreak;
  final int perfectContacts;
  final int bestCombo;
  final int objectivesCompleted;
  final int highestChase;
  final int finalBallWins;
  final int wicketlessOvers;
  final int openSectorScoringShots;
  final Map<ShotSector, SuperOverPerformanceStats> sectorStats;
  final Map<ShotStyle, SuperOverPerformanceStats> intentStats;
  final Map<String, int> batterMastery;
  final CricketJersey lastJersey;
  final SuperOverDifficulty difficulty;
  final SuperOverSettings settings;
  final bool tutorialCompleted;
  final int tutorialVersion;
  final Set<SuperOverAchievementId> unlockedAchievements;
  final Map<String, int> achievementProgress;

  /// Keyed by a canonical, sorted three-card unit key.
  final Map<String, int> unitChemistryWins;
  final Set<CricketBattingStyle> winningFinisherArchetypes;
  final List<SuperOverHistoryEntry> history;

  /// Durable match IDs that have completed all local settlement steps.
  final Set<String> settledMatchIds;

  int masteryLevelFor(String cardId) =>
      1 + math.max(0, batterMastery[cardId] ?? 0) ~/ 100;

  bool isSettled(String matchId) => settledMatchIds.contains(matchId);

  Map<String, dynamic> toJson() => {
    'schemaVersion': superOverProfileSchemaVersion,
    'highScore': highScore,
    'scoreAttackHighScore': scoreAttackHighScore,
    'chaseWins': chaseWins,
    'chaseLosses': chaseLosses,
    'completions': completions,
    'totalSixes': totalSixes,
    'totalFours': totalFours,
    'totalRuns': totalRuns,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'perfectContacts': perfectContacts,
    'bestCombo': bestCombo,
    'objectivesCompleted': objectivesCompleted,
    'highestChase': highestChase,
    'finalBallWins': finalBallWins,
    'wicketlessOvers': wicketlessOvers,
    'openSectorScoringShots': openSectorScoringShots,
    'sectorStats': {
      for (final entry in sectorStats.entries)
        entry.key.name: entry.value.toJson(),
    },
    'intentStats': {
      for (final entry in intentStats.entries)
        entry.key.name: entry.value.toJson(),
    },
    'batterMastery': batterMastery,
    'lastJersey': lastJersey.name,
    'difficulty': difficulty.name,
    'settings': settings.toJson(),
    'tutorialCompleted': tutorialCompleted,
    'tutorialVersion': tutorialVersion,
    'unlockedAchievements':
        unlockedAchievements.map((achievement) => achievement.name).toList()
          ..sort(),
    'achievementProgress': achievementProgress,
    'unitChemistryWins': unitChemistryWins,
    'winningFinisherArchetypes':
        winningFinisherArchetypes.map((style) => style.name).toList()..sort(),
    'history': _takeLast(
      history,
      superOverHistoryLimit,
    ).map((entry) => entry.toJson()).toList(),
    'settledMatchIds': _takeLast(
      settledMatchIds,
      superOverSettlementIdLimit,
    ).toList(),
  };

  SuperOverStats copyWith({
    int? highScore,
    int? scoreAttackHighScore,
    int? chaseWins,
    int? chaseLosses,
    int? completions,
    int? totalSixes,
    int? totalFours,
    int? totalRuns,
    int? currentStreak,
    int? bestStreak,
    int? perfectContacts,
    int? bestCombo,
    int? objectivesCompleted,
    int? highestChase,
    int? finalBallWins,
    int? wicketlessOvers,
    int? openSectorScoringShots,
    Map<ShotSector, SuperOverPerformanceStats>? sectorStats,
    Map<ShotStyle, SuperOverPerformanceStats>? intentStats,
    Map<String, int>? batterMastery,
    CricketJersey? lastJersey,
    SuperOverDifficulty? difficulty,
    SuperOverSettings? settings,
    bool? tutorialCompleted,
    int? tutorialVersion,
    Set<SuperOverAchievementId>? unlockedAchievements,
    Map<String, int>? achievementProgress,
    Map<String, int>? unitChemistryWins,
    Set<CricketBattingStyle>? winningFinisherArchetypes,
    List<SuperOverHistoryEntry>? history,
    Set<String>? settledMatchIds,
  }) {
    final resolvedDifficulty =
        difficulty ?? settings?.difficulty ?? this.difficulty;
    final resolvedSettings = (settings ?? this.settings).copyWith(
      difficulty: resolvedDifficulty,
    );
    return SuperOverStats(
      highScore: highScore ?? this.highScore,
      scoreAttackHighScore: scoreAttackHighScore ?? this.scoreAttackHighScore,
      chaseWins: chaseWins ?? this.chaseWins,
      chaseLosses: chaseLosses ?? this.chaseLosses,
      completions: completions ?? this.completions,
      totalSixes: totalSixes ?? this.totalSixes,
      totalFours: totalFours ?? this.totalFours,
      totalRuns: totalRuns ?? this.totalRuns,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      perfectContacts: perfectContacts ?? this.perfectContacts,
      bestCombo: bestCombo ?? this.bestCombo,
      objectivesCompleted: objectivesCompleted ?? this.objectivesCompleted,
      highestChase: highestChase ?? this.highestChase,
      finalBallWins: finalBallWins ?? this.finalBallWins,
      wicketlessOvers: wicketlessOvers ?? this.wicketlessOvers,
      openSectorScoringShots:
          openSectorScoringShots ?? this.openSectorScoringShots,
      sectorStats: sectorStats ?? this.sectorStats,
      intentStats: intentStats ?? this.intentStats,
      batterMastery: batterMastery ?? this.batterMastery,
      lastJersey: lastJersey ?? this.lastJersey,
      difficulty: resolvedDifficulty,
      settings: resolvedSettings,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      tutorialVersion: tutorialVersion ?? this.tutorialVersion,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      achievementProgress: achievementProgress ?? this.achievementProgress,
      unitChemistryWins: unitChemistryWins ?? this.unitChemistryWins,
      winningFinisherArchetypes:
          winningFinisherArchetypes ?? this.winningFinisherArchetypes,
      history: _takeLast(history ?? this.history, superOverHistoryLimit),
      settledMatchIds: _takeLast(
        settledMatchIds ?? this.settledMatchIds,
        superOverSettlementIdLimit,
      ).toSet(),
    );
  }

  SuperOverStats addHistoryEntry(SuperOverHistoryEntry entry) {
    final next =
        history.where((existing) => existing.matchId != entry.matchId).toList()
          ..add(entry);
    return copyWith(history: next);
  }

  SuperOverStats markSettled(String matchId) {
    if (matchId.isEmpty || settledMatchIds.contains(matchId)) return this;
    return copyWith(settledMatchIds: {...settledMatchIds, matchId});
  }

  /// Applies one complete match exactly once, including contribution-weighted
  /// mastery, lifetime records, achievements and the bounded history archive.
  /// Account XP remains owned by `GameBloc` and is intentionally not written
  /// here.
  SuperOverStats recordCompletedMatch(
    SuperOverMatchSummary summary, {
    Map<String, CricketBattingStyle> battingArchetypes = const {},
  }) {
    if (summary.tutorial ||
        summary.matchId.isEmpty ||
        settledMatchIds.contains(summary.matchId)) {
      return this;
    }

    final chaseWon =
        summary.mode == SuperOverMode.chase && summary.wonChase == true;
    final chaseLost =
        summary.mode == SuperOverMode.chase && summary.wonChase == false;
    final completionsAfter = completions + 1;
    final foursAfter = totalFours + summary.fours;
    final sixesAfter = totalSixes + summary.sixes;
    final perfectAfter = perfectContacts + summary.perfectContacts;
    final wicketlessAfter = wicketlessOvers + (summary.wickets == 0 ? 1 : 0);
    final finalBallWin = chaseWon && summary.ballsFaced == 6;

    final sectorsAfter = Map<ShotSector, SuperOverPerformanceStats>.of(
      sectorStats,
    );
    final intentsAfter = Map<ShotStyle, SuperOverPerformanceStats>.of(
      intentStats,
    );
    for (final ball in summary.ballRecords) {
      sectorsAfter[ball.resolvedSector] =
          (sectorsAfter[ball.resolvedSector] ??
                  const SuperOverPerformanceStats())
              .add(
                runs: ball.runs,
                boundary: ball.isBoundary,
                wicket: ball.isWicket,
              );
      final intent = ball.intent?.style;
      if (intent != null) {
        intentsAfter[intent] =
            (intentsAfter[intent] ?? const SuperOverPerformanceStats()).add(
              runs: ball.runs,
              boundary: ball.isBoundary,
              wicket: ball.isWicket,
            );
      }
    }

    final masteryAfter = Map<String, int>.of(batterMastery);
    final dismissed = {
      for (final ball in summary.ballRecords)
        if (ball.isWicket) ball.strikerCardId,
    };
    final involved = {
      for (final ball in summary.ballRecords) ...[
        ball.strikerCardId,
        ball.nonStrikerCardId,
      ],
    };
    for (final cardId in summary.battingCardIds) {
      final balls = summary.ballRecords
          .where((ball) => ball.strikerCardId == cardId)
          .toList(growable: false);
      var gain = 5 + (summary.objectiveComplete ? 2 : 0);
      gain += balls.fold<int>(0, (runs, ball) => runs + ball.runs);
      gain +=
          balls.where((ball) => ball.timingTier == TimingTier.perfect).length *
          2;
      gain += balls.where((ball) => ball.isBoundary).length * 2;
      if (chaseWon && summary.finishingBatterCardId == cardId) gain += 5;
      if (involved.contains(cardId) && !dismissed.contains(cardId)) gain += 3;
      masteryAfter[cardId] = (masteryAfter[cardId] ?? 0) + gain;
    }

    final unitWinsAfter = Map<String, int>.of(unitChemistryWins);
    final unitKey = superOverUnitKey(summary.battingCardIds);
    if (chaseWon && unitKey.isNotEmpty) {
      unitWinsAfter[unitKey] = (unitWinsAfter[unitKey] ?? 0) + 1;
    }

    final finisherArchetypesAfter = Set<CricketBattingStyle>.of(
      winningFinisherArchetypes,
    );
    if (chaseWon && summary.finishingBatterCardId != null) {
      final style = battingArchetypes[summary.finishingBatterCardId!];
      if (style != null) finisherArchetypesAfter.add(style);
    }

    final unlockedAfter = Set<SuperOverAchievementId>.of(unlockedAchievements)
      ..addAll(
        evaluateSuperOverAchievements(
          summary: summary,
          completionsAfter: completionsAfter,
          unitWinsAfter: unitKey.isEmpty ? 0 : unitWinsAfter[unitKey] ?? 0,
          winningFinisherArchetypesAfter: finisherArchetypesAfter,
        ),
      );
    final progressAfter = Map<String, int>.of(achievementProgress);
    void keepBest(SuperOverAchievementId id, int value) {
      progressAfter[id.name] = math.max(progressAfter[id.name] ?? 0, value);
    }

    final scoringSectors = {
      for (final ball in summary.ballRecords)
        if (ball.runs > 0) ball.resolvedSector,
    };
    final finalThreeRuns = summary.ballRecords
        .where((ball) => ball.ballNumber >= 4)
        .fold<int>(0, (runs, ball) => runs + ball.runs);
    keepBest(
      SuperOverAchievementId.firstFinish,
      chaseWins + (chaseWon ? 1 : 0),
    );
    keepBest(
      SuperOverAchievementId.iceCold,
      finalBallWins + (finalBallWin ? 1 : 0),
    );
    keepBest(
      SuperOverAchievementId.oneBatterJob,
      summary.ballRecords.map((ball) => ball.strikerCardId).toSet().length == 1
          ? 1
          : 0,
    );
    keepBest(SuperOverAchievementId.threeWayAttack, scoringSectors.length);
    keepBest(SuperOverAchievementId.groundControl, _groundOnlyRuns(summary));
    keepBest(SuperOverAchievementId.airRaid, summary.sixes);
    keepBest(SuperOverAchievementId.cleanOver, wicketlessAfter);
    keepBest(SuperOverAchievementId.openField, summary.openSectorHits);
    keepBest(SuperOverAchievementId.perfectTiming, summary.perfectContacts);
    keepBest(
      SuperOverAchievementId.rescueAct,
      chaseWon &&
              summary.ballRecords.any(
                (ball) => ball.ballNumber <= 2 && ball.isWicket,
              )
          ? 1
          : 0,
    );
    keepBest(SuperOverAchievementId.impossibleFinish, finalThreeRuns);
    keepBest(
      SuperOverAchievementId.recordBreaker,
      summary.mode == SuperOverMode.scoreAttack && summary.isNewRecord ? 1 : 0,
    );
    keepBest(SuperOverAchievementId.masterFinisher, completionsAfter);
    keepBest(
      SuperOverAchievementId.unitChemistry,
      unitKey.isEmpty ? 0 : unitWinsAfter[unitKey] ?? 0,
    );
    keepBest(
      SuperOverAchievementId.allArchetypes,
      finisherArchetypesAfter.length,
    );

    var currentStreakAfter = currentStreak;
    var bestStreakAfter = bestStreak;
    if (chaseWon) {
      currentStreakAfter++;
      bestStreakAfter = math.max(bestStreakAfter, currentStreakAfter);
    } else if (chaseLost) {
      currentStreakAfter = 0;
    }

    return copyWith(
          highScore: summary.mode == SuperOverMode.chase
              ? math.max(highScore, summary.score)
              : highScore,
          scoreAttackHighScore: summary.mode == SuperOverMode.scoreAttack
              ? math.max(scoreAttackHighScore, summary.score)
              : scoreAttackHighScore,
          chaseWins: chaseWins + (chaseWon ? 1 : 0),
          chaseLosses: chaseLosses + (chaseLost ? 1 : 0),
          completions: completionsAfter,
          totalSixes: sixesAfter,
          totalFours: foursAfter,
          totalRuns: totalRuns + summary.score,
          currentStreak: currentStreakAfter,
          bestStreak: bestStreakAfter,
          perfectContacts: perfectAfter,
          bestCombo: math.max(bestCombo, _bestCombo(summary.ballRecords)),
          objectivesCompleted:
              objectivesCompleted + (summary.objectiveComplete ? 1 : 0),
          highestChase: chaseWon
              ? math.max(highestChase, summary.requiredChaseScore)
              : highestChase,
          finalBallWins: finalBallWins + (finalBallWin ? 1 : 0),
          wicketlessOvers: wicketlessAfter,
          openSectorScoringShots:
              openSectorScoringShots + summary.openSectorHits,
          sectorStats: sectorsAfter,
          intentStats: intentsAfter,
          batterMastery: masteryAfter,
          difficulty: summary.difficulty,
          unlockedAchievements: unlockedAfter,
          achievementProgress: progressAfter,
          unitChemistryWins: unitWinsAfter,
          winningFinisherArchetypes: finisherArchetypesAfter,
        )
        .addHistoryEntry(SuperOverHistoryEntry.fromSummary(summary))
        .markSettled(summary.matchId);
  }
}

/// New code may use the profile terminology without breaking older screens.
typedef SuperOverProfile = SuperOverStats;

String superOverUnitKey(Iterable<String> cardIds) {
  final sorted = cardIds.where((id) => id.isNotEmpty).take(3).toList()..sort();
  return sorted.join('|');
}

/// Evaluates the fifteen permanent achievement predicates against a stable
/// match summary and the relevant post-settlement lifetime counters.
Set<SuperOverAchievementId> evaluateSuperOverAchievements({
  required SuperOverMatchSummary summary,
  required int completionsAfter,
  required int unitWinsAfter,
  required Set<CricketBattingStyle> winningFinisherArchetypesAfter,
}) {
  if (summary.tutorial) return const {};
  final chaseWon =
      summary.mode == SuperOverMode.chase && summary.wonChase == true;
  final strikerIds = summary.ballRecords
      .map((ball) => ball.strikerCardId)
      .toSet();
  final scoringSectors = {
    for (final ball in summary.ballRecords)
      if (ball.runs > 0) ball.resolvedSector,
  };
  final finalThreeRuns = summary.ballRecords
      .where((ball) => ball.ballNumber >= 4)
      .fold<int>(0, (runs, ball) => runs + ball.runs);
  return {
    if (chaseWon) SuperOverAchievementId.firstFinish,
    if (chaseWon && summary.ballsFaced == 6) SuperOverAchievementId.iceCold,
    if (chaseWon && strikerIds.length == 1) SuperOverAchievementId.oneBatterJob,
    if (scoringSectors.length == ShotSector.values.length)
      SuperOverAchievementId.threeWayAttack,
    if (_groundOnlyRuns(summary) >= 12) SuperOverAchievementId.groundControl,
    if (summary.sixes >= 3) SuperOverAchievementId.airRaid,
    if (summary.wickets == 0) SuperOverAchievementId.cleanOver,
    if (summary.openSectorHits >= 3) SuperOverAchievementId.openField,
    if (summary.perfectContacts >= 3) SuperOverAchievementId.perfectTiming,
    if (chaseWon &&
        summary.ballRecords.any(
          (ball) => ball.ballNumber <= 2 && ball.isWicket,
        ))
      SuperOverAchievementId.rescueAct,
    if (finalThreeRuns >= 18) SuperOverAchievementId.impossibleFinish,
    if (summary.mode == SuperOverMode.scoreAttack && summary.isNewRecord)
      SuperOverAchievementId.recordBreaker,
    if (completionsAfter >= 100) SuperOverAchievementId.masterFinisher,
    if (chaseWon && unitWinsAfter >= 10) SuperOverAchievementId.unitChemistry,
    if (winningFinisherArchetypesAfter.length ==
        CricketBattingStyle.values.length)
      SuperOverAchievementId.allArchetypes,
  };
}

int _groundOnlyRuns(SuperOverMatchSummary summary) {
  if (summary.ballRecords.any((ball) => ball.intent?.style == ShotStyle.loft)) {
    return 0;
  }
  return summary.ballRecords
      .where((ball) => ball.intent?.style == ShotStyle.ground)
      .fold<int>(0, (runs, ball) => runs + ball.runs);
}

int _bestCombo(Iterable<SuperOverBallRecord> records) {
  var current = 0;
  var best = 0;
  for (final ball in records) {
    if (ball.runs > 0 && !ball.isWicket) {
      current++;
      best = math.max(best, current);
    } else {
      current = 0;
    }
  }
  return best;
}

Map<String, int> _intMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String &&
          entry.value is num &&
          (entry.value as num).isFinite)
        entry.key as String: math.max(0, (entry.value as num).toInt()),
  };
}

SuperOverSettings _settings(Object? raw) {
  if (raw is! Map) return const SuperOverSettings();
  final json = Map<String, dynamic>.from(raw);
  return SuperOverSettings(
    difficulty: _enumByName(
      SuperOverDifficulty.values,
      json['difficulty'],
      SuperOverDifficulty.pro,
    ),
    soundEnabled: _bool(json['soundEnabled'], fallback: true),
    musicEnabled: _bool(json['musicEnabled'], fallback: true),
    crowdEnabled: _bool(json['crowdEnabled'], fallback: true),
    hapticsEnabled: _bool(json['hapticsEnabled'], fallback: true),
    reducedMotion: _bool(json['reducedMotion']),
    leftHandedControls: _bool(json['leftHandedControls']),
    batButtonScale: _finiteDouble(
      json['batButtonScale'],
      fallback: 1,
    ).clamp(.75, 1.5),
    controlOpacity: _finiteDouble(
      json['controlOpacity'],
      fallback: 1,
    ).clamp(.4, 1),
    largerFieldRadar: _bool(json['largerFieldRadar']),
  );
}

Map<ShotSector, SuperOverPerformanceStats> _sectorStats(Object? raw) {
  if (raw is! Map) return const {};
  final result = <ShotSector, SuperOverPerformanceStats>{};
  for (final entry in raw.entries) {
    final sector = _nullableEnumByName(ShotSector.values, entry.key);
    if (sector == null || entry.value is! Map) continue;
    result[sector] = SuperOverPerformanceStats.fromJson(
      Map<String, dynamic>.from(entry.value as Map),
    );
  }
  return result;
}

Map<ShotStyle, SuperOverPerformanceStats> _intentStats(Object? raw) {
  if (raw is! Map) return const {};
  final result = <ShotStyle, SuperOverPerformanceStats>{};
  for (final entry in raw.entries) {
    final intent = _nullableEnumByName(ShotStyle.values, entry.key);
    if (intent == null || entry.value is! Map) continue;
    result[intent] = SuperOverPerformanceStats.fromJson(
      Map<String, dynamic>.from(entry.value as Map),
    );
  }
  return result;
}

Set<SuperOverAchievementId> _achievementSet(Object? raw) {
  if (raw is! List) return const {};
  return raw
      .map((value) => _nullableEnumByName(SuperOverAchievementId.values, value))
      .whereType<SuperOverAchievementId>()
      .toSet();
}

Set<CricketBattingStyle> _archetypeSet(Object? raw) {
  if (raw is! List) return const {};
  return raw
      .map((value) => _nullableEnumByName(CricketBattingStyle.values, value))
      .whereType<CricketBattingStyle>()
      .toSet();
}

Set<String> _stringSet(Object? raw) {
  if (raw is! List) return const {};
  return raw.whereType<String>().where((value) => value.isNotEmpty).toSet();
}

List<T> _takeLast<T>(Iterable<T> values, int limit) {
  final list = values.toList(growable: false);
  if (list.length <= limit) return list;
  return list.sublist(list.length - limit);
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  return _nullableEnumByName(values, raw) ?? fallback;
}

T? _nullableEnumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

int _nonNegativeInt(Object? raw, {int fallback = 0}) {
  if (raw is! num || !raw.isFinite) return fallback;
  return math.max(0, raw.toInt());
}

double _finiteDouble(Object? raw, {required double fallback}) {
  if (raw is! num || !raw.isFinite) return fallback;
  return raw.toDouble();
}

DateTime _utcDateFromEpoch(Object? raw) {
  try {
    return DateTime.fromMillisecondsSinceEpoch(
      _nonNegativeInt(raw),
      isUtc: true,
    );
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

bool _bool(Object? raw, {bool fallback = false}) =>
    raw is bool ? raw : fallback;

String _string(Object? raw, {String fallback = ''}) =>
    raw is String ? raw : fallback;

String? _nullableString(Object? raw) => raw is String ? raw : null;
