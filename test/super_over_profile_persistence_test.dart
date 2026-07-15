import 'dart:convert';

import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/super_over_stats.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Super Over profile migration', () {
    test('preserves legacy records and deterministically migrates jerseys', () {
      final profile = SuperOverStats.fromJson({
        'highScore': 24,
        'scoreAttackHighScore': 31,
        'chaseWins': 7,
        'chaseLosses': 3,
        'totalSixes': 18,
        'totalRuns': 149,
        'currentStreak': 2,
        'bestStreak': 5,
        'perfectContacts': 11,
        'bestCombo': 4,
        'objectivesCompleted': 6,
        'batterMastery': {'shared-card-1': 245},
        'lastJersey': 'chennai',
      });

      expect(profile.schemaVersion, superOverProfileSchemaVersion);
      expect(profile.highScore, 24);
      expect(profile.scoreAttackHighScore, 31);
      expect(profile.chaseWins, 7);
      expect(profile.chaseLosses, 3);
      expect(profile.completions, 10);
      expect(profile.totalSixes, 18);
      expect(profile.totalRuns, 149);
      expect(profile.currentStreak, 2);
      expect(profile.bestStreak, 5);
      expect(profile.perfectContacts, 11);
      expect(profile.bestCombo, 4);
      expect(profile.objectivesCompleted, 6);
      expect(profile.batterMastery['shared-card-1'], 245);
      expect(profile.masteryLevelFor('shared-card-1'), 3);
      expect(profile.lastJersey, CricketJersey.goldStrike);
      expect(profile.difficulty, SuperOverDifficulty.pro);
      expect(profile.settings.difficulty, SuperOverDifficulty.pro);
      expect(profile.totalFours, 0);
      expect(profile.history, isEmpty);
      expect(profile.settledMatchIds, isEmpty);
    });

    test('v2 profile round trip retains new settings and tactical records', () {
      final history = List.generate(
        15,
        (index) => SuperOverHistoryEntry(
          matchId: 'match-$index',
          playedAt: DateTime.utc(2026, 1, index + 1),
          mode: index.isEven ? SuperOverMode.chase : SuperOverMode.scoreAttack,
          score: 10 + index,
          wickets: index % 3,
          target: index.isEven ? 14 : null,
          wonChase: index.isEven ? true : null,
          ballsRemaining: index % 6,
          ballRecords: const [],
          battingCardIds: const ['a', 'b', 'c'],
          difficulty: SuperOverDifficulty.allStar,
          grade: 'A',
          xp: 25,
          newRecord: index == 14,
        ),
      );
      final settled = {
        for (var index = 0; index < 300; index++) 'settled-$index',
      };
      final profile = SuperOverStats(
        scoreAttackHighScore: 42,
        completions: 110,
        totalFours: 28,
        highestChase: 22,
        finalBallWins: 4,
        wicketlessOvers: 9,
        openSectorScoringShots: 37,
        sectorStats: const {
          ShotSector.off: SuperOverPerformanceStats(
            attempts: 10,
            scoringShots: 7,
            runs: 24,
            boundaries: 4,
            wickets: 1,
          ),
        },
        intentStats: const {
          ShotStyle.ground: SuperOverPerformanceStats(
            attempts: 12,
            scoringShots: 9,
            runs: 30,
            boundaries: 5,
          ),
        },
        lastJersey: CricketJersey.tealVector,
        difficulty: SuperOverDifficulty.allStar,
        settings: const SuperOverSettings(
          difficulty: SuperOverDifficulty.allStar,
          soundEnabled: false,
          crowdEnabled: false,
          hapticsEnabled: false,
          reducedMotion: true,
          leftHandedControls: true,
          batButtonScale: 1.4,
          controlOpacity: .6,
          largerFieldRadar: true,
        ),
        tutorialCompleted: true,
        tutorialVersion: 1,
        unlockedAchievements: const {
          SuperOverAchievementId.firstFinish,
          SuperOverAchievementId.cleanOver,
        },
        achievementProgress: const {'masterFinisher': 110},
        unitChemistryWins: const {'a|b|c': 10},
        winningFinisherArchetypes: const {
          CricketBattingStyle.anchor,
          CricketBattingStyle.powerHitter,
        },
        history: history,
        settledMatchIds: settled,
      );

      final revived = SuperOverStats.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(profile.toJson())) as Map,
        ),
      );

      expect(revived.schemaVersion, superOverProfileSchemaVersion);
      expect(revived.scoreAttackHighScore, 42);
      expect(revived.completions, 110);
      expect(revived.totalFours, 28);
      expect(revived.highestChase, 22);
      expect(revived.finalBallWins, 4);
      expect(revived.wicketlessOvers, 9);
      expect(revived.openSectorScoringShots, 37);
      expect(revived.sectorStats[ShotSector.off]?.runs, 24);
      expect(revived.intentStats[ShotStyle.ground]?.boundaries, 5);
      expect(revived.lastJersey, CricketJersey.tealVector);
      expect(revived.difficulty, SuperOverDifficulty.allStar);
      expect(revived.settings.reducedMotion, isTrue);
      expect(revived.settings.leftHandedControls, isTrue);
      expect(revived.settings.batButtonScale, 1.4);
      expect(revived.settings.controlOpacity, .6);
      expect(revived.settings.largerFieldRadar, isTrue);
      expect(revived.tutorialCompleted, isTrue);
      expect(revived.unlockedAchievements, hasLength(2));
      expect(revived.history, hasLength(superOverHistoryLimit));
      expect(revived.history.first.matchId, 'match-3');
      expect(revived.history.last.matchId, 'match-14');
      expect(revived.settledMatchIds, hasLength(superOverSettlementIdLimit));
    });

    test(
      'secure storage upgrades v1 once and prefers the v2 profile',
      () async {
        SharedPreferences.setMockInitialValues({
          'pd_super_over_stats_v1': jsonEncode({
            'highScore': 19,
            'chaseWins': 2,
            'batterMastery': {'legacy-card': 120},
            'lastJersey': 'kolkata',
          }),
        });
        final storage = SecureGameStorage();

        final migrated = await storage.loadSuperOverStats();
        expect(migrated.highScore, 19);
        expect(migrated.batterMastery['legacy-card'], 120);
        expect(migrated.lastJersey, CricketJersey.violetPulse);

        final prefs = await SharedPreferences.getInstance();
        final upgradedRaw = prefs.getString('pd_super_over_profile_v2');
        expect(upgradedRaw, isNotNull);
        expect(
          (jsonDecode(upgradedRaw!) as Map)['schemaVersion'],
          superOverProfileSchemaVersion,
        );

        await storage.saveSuperOverStats(migrated.copyWith(highScore: 27));
        final revived = await storage.loadSuperOverProfile();
        expect(revived.highScore, 27);
      },
    );

    test('damaged preferences cannot erase readable progress', () async {
      final profile = SuperOverStats.fromJson({
        'highScore': 23,
        'totalRuns': 180,
        'lastJersey': 404,
        'difficulty': 'retired',
        'settings': {
          'soundEnabled': 'not-a-bool',
          'batButtonScale': double.infinity,
          'controlOpacity': -20,
        },
        'batterMastery': {'card': double.infinity, 'safe-card': 99},
      });
      expect(profile.highScore, 23);
      expect(profile.totalRuns, 180);
      expect(profile.lastJersey, CricketJersey.nightCyan);
      expect(profile.difficulty, SuperOverDifficulty.pro);
      expect(profile.settings.soundEnabled, isTrue);
      expect(profile.settings.batButtonScale, 1);
      expect(profile.settings.controlOpacity, .4);
      expect(profile.batterMastery, {'safe-card': 99});

      SharedPreferences.setMockInitialValues({
        'pd_super_over_profile_v2': '{broken-json',
        'pd_super_over_stats_v1': jsonEncode({
          'highScore': 17,
          'lastJersey': 'mumbai',
        }),
      });
      final migrated = await SecureGameStorage().loadSuperOverStats();
      expect(migrated.highScore, 17);
      expect(migrated.lastJersey, CricketJersey.nightCyan);
    });
  });

  group('Super Over exact-once profile settlement', () {
    test(
      'attributes mastery by contribution and ignores duplicate summaries',
      () {
        final records = [
          _ball(1, sector: ShotSector.off, outcome: ShotOutcome.six),
          _ball(2, sector: ShotSector.v, outcome: ShotOutcome.six),
          _ball(3, sector: ShotSector.leg, outcome: ShotOutcome.six),
        ];
        final summary = _summary(
          matchId: 'settle-once',
          records: records,
          score: 18,
          target: 17,
          wonChase: true,
          objectiveComplete: true,
          finishingBatterCardId: 'a',
        );

        final settled = const SuperOverStats().recordCompletedMatch(
          summary,
          battingArchetypes: const {
            'a': CricketBattingStyle.anchor,
            'b': CricketBattingStyle.powerHitter,
            'c': CricketBattingStyle.improviser,
          },
        );

        expect(settled.completions, 1);
        expect(settled.chaseWins, 1);
        expect(settled.totalRuns, 18);
        expect(settled.totalSixes, 3);
      expect(settled.highestChase, 18);
        expect(settled.objectivesCompleted, 1);
        expect(settled.batterMastery['a'], 45);
        expect(settled.batterMastery['b'], 10);
        expect(settled.batterMastery['c'], 7);
        expect(settled.winningFinisherArchetypes, {CricketBattingStyle.anchor});
        expect(settled.sectorStats[ShotSector.off]?.runs, 6);
        expect(settled.intentStats[ShotStyle.loft]?.runs, 18);
        expect(settled.history.single.matchId, 'settle-once');
        expect(settled.history.single.xp, summary.rewardBreakdown.totalXp);
        expect(settled.isSettled('settle-once'), isTrue);

        final duplicate = settled.recordCompletedMatch(summary);
        expect(identical(duplicate, settled), isTrue);
        expect(duplicate.completions, 1);
        expect(duplicate.totalRuns, 18);
        expect(duplicate.history, hasLength(1));
      },
    );

    test('all fifteen achievement predicates are represented', () {
      final groundRecords = [
        _ball(
          1,
          sector: ShotSector.off,
          outcome: ShotOutcome.four,
          style: ShotStyle.ground,
        ),
        _ball(
          2,
          sector: ShotSector.v,
          outcome: ShotOutcome.four,
          style: ShotStyle.ground,
        ),
        _ball(
          3,
          sector: ShotSector.leg,
          outcome: ShotOutcome.four,
          style: ShotStyle.ground,
        ),
        _ball(
          4,
          sector: ShotSector.off,
          outcome: ShotOutcome.dot,
          style: ShotStyle.ground,
        ),
        _ball(
          5,
          sector: ShotSector.v,
          outcome: ShotOutcome.dot,
          style: ShotStyle.ground,
        ),
        _ball(
          6,
          sector: ShotSector.leg,
          outcome: ShotOutcome.dot,
          style: ShotStyle.ground,
        ),
      ];
      final ground = _summary(
        matchId: 'ground',
        records: groundRecords,
        score: 12,
        target: 11,
        wonChase: true,
      );
      final aerialRecords = [
        _ball(1, sector: ShotSector.off, outcome: ShotOutcome.dot),
        _ball(2, sector: ShotSector.v, outcome: ShotOutcome.dot),
        _ball(3, sector: ShotSector.leg, outcome: ShotOutcome.dot),
        _ball(4, sector: ShotSector.off, outcome: ShotOutcome.six),
        _ball(5, sector: ShotSector.v, outcome: ShotOutcome.six),
        _ball(6, sector: ShotSector.leg, outcome: ShotOutcome.six),
      ];
      final aerial = _summary(
        matchId: 'aerial',
        records: aerialRecords,
        score: 18,
        target: 17,
        wonChase: true,
      );
      final rescue = _summary(
        matchId: 'rescue',
        records: [
          _ball(1, sector: ShotSector.v, outcome: ShotOutcome.caught),
          _ball(2, sector: ShotSector.off, outcome: ShotOutcome.six),
        ],
        score: 6,
        target: 5,
        wonChase: true,
        wickets: 1,
      );
      final recordBreaker = _summary(
        matchId: 'record',
        mode: SuperOverMode.scoreAttack,
        records: [_ball(1, sector: ShotSector.v, outcome: ShotOutcome.four)],
        score: 4,
        target: null,
        wonChase: null,
        isNewRecord: true,
      );

      final unlocked = <SuperOverAchievementId>{
        ...evaluateSuperOverAchievements(
          summary: ground,
          completionsAfter: 100,
          unitWinsAfter: 10,
          winningFinisherArchetypesAfter: CricketBattingStyle.values.toSet(),
        ),
        ...evaluateSuperOverAchievements(
          summary: aerial,
          completionsAfter: 2,
          unitWinsAfter: 2,
          winningFinisherArchetypesAfter: const {},
        ),
        ...evaluateSuperOverAchievements(
          summary: rescue,
          completionsAfter: 3,
          unitWinsAfter: 3,
          winningFinisherArchetypesAfter: const {},
        ),
        ...evaluateSuperOverAchievements(
          summary: recordBreaker,
          completionsAfter: 4,
          unitWinsAfter: 0,
          winningFinisherArchetypesAfter: const {},
        ),
      };

      expect(unlocked, containsAll(SuperOverAchievementId.values));
      expect(unlocked, hasLength(15));
    });

    test('tutorial summaries grant no profile progress', () {
      final profile = const SuperOverStats();
      final summary = _summary(
        matchId: 'tutorial',
        records: [_ball(1, sector: ShotSector.v, outcome: ShotOutcome.six)],
        score: 6,
        target: 5,
        wonChase: true,
        tutorial: true,
      );

      expect(identical(profile.recordCompletedMatch(summary), profile), isTrue);
    });
  });

  group('Super Over resume and settlement storage', () {
    test('dedupe IDs are bounded and survive a round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage();
      final ids = {for (var index = 0; index < 300; index++) 'match-$index'};

      await storage.saveSuperOverSettlementIds(ids);
      final revived = await storage.loadSuperOverSettlementIds();

      expect(revived, hasLength(superOverSettlementIdLimit));
      expect(revived, contains('match-299'));
      expect(revived, isNot(contains('match-0')));
    });

    test('snapshot resumes the committed ball from a safe boundary', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage();
      final snapshot = _snapshot(playPhase: SuperOverPlayPhase.contact);

      await storage.saveSuperOverMatchSnapshot(snapshot);
      final revived = await storage.loadSuperOverMatchSnapshot();

      expect(revived, isNotNull);
      expect(revived!.config.matchId, snapshot.config.matchId);
      expect(revived.committedBall.planningSeed, 77);
      expect(revived.ballRecords, isEmpty);
      expect(revived.playPhase, SuperOverPlayPhase.fieldReveal);

      await storage.clearSuperOverMatchSnapshot();
      expect(await storage.loadSuperOverMatchSnapshot(), isNull);
    });

    test('completed snapshots are never retained', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage();

      await storage.saveSuperOverMatchSnapshot(_snapshot(wickets: 2));
      expect(await storage.loadSuperOverMatchSnapshot(), isNull);
    });
  });
}

SuperOverMatchSummary _summary({
  required String matchId,
  required List<SuperOverBallRecord> records,
  required int score,
  required int? target,
  required bool? wonChase,
  SuperOverMode mode = SuperOverMode.chase,
  int wickets = 0,
  bool objectiveComplete = false,
  String? finishingBatterCardId = 'a',
  bool isNewRecord = false,
  bool tutorial = false,
}) {
  return SuperOverMatchSummary(
    matchId: matchId,
    seed: 42,
    mode: mode,
    difficulty: SuperOverDifficulty.pro,
    target: target,
    score: score,
    wickets: wickets,
    ballsFaced: records.length,
    wonChase: wonChase,
    objective: const SuperOverObjective(
      type: SuperOverObjectiveType.runs,
      target: 12,
    ),
    objectiveComplete: objectiveComplete,
    battingCardIds: const ['a', 'b', 'c'],
    ballRecords: records,
    finishingBatterCardId: finishingBatterCardId,
    grade: SuperOverPerformanceGrade.a,
    isNewRecord: isNewRecord,
    completedAtEpochMs: DateTime.utc(2026, 7, 11).millisecondsSinceEpoch,
    tutorial: tutorial,
  );
}

SuperOverBallRecord _ball(
  int number, {
  required ShotSector sector,
  required ShotOutcome outcome,
  ShotStyle style = ShotStyle.loft,
}) {
  final counts = switch (sector) {
    ShotSector.off => const [1, 4, 4],
    ShotSector.v => const [4, 1, 4],
    ShotSector.leg => const [4, 4, 1],
  };
  final runs = SuperOverResolution.runsForOutcome(outcome);
  return SuperOverBallRecord(
    ballNumber: number,
    strikerCardId: 'a',
    nonStrikerCardId: 'b',
    committedBall: SuperOverCommittedBall(
      ballNumber: number,
      planningSeed: 100 + number,
      fieldPlan: SuperOverFieldPlan.fromCounts(counts),
      delivery: const DeliveryPlan(),
    ),
    intent: ShotIntent(sector: sector, style: style, timingErrorMs: 0),
    contactType: outcome == ShotOutcome.bowled
        ? SuperOverContactType.missed
        : SuperOverContactType.played,
    timingErrorMs: 0,
    normalizedTimingError: 0,
    timingTier: TimingTier.perfect,
    drift: TimingDrift.none,
    resolvedSector: sector,
    outcome: outcome,
    runs: runs,
    usedFinisherMode: false,
    rhythmBefore: 0,
    rhythmAfter: 25,
    scoreAfter: runs,
    wicketsAfter: outcome == ShotOutcome.caught || outcome == ShotOutcome.bowled
        ? 1
        : 0,
  );
}

SuperOverMatchSnapshot _snapshot({
  SuperOverPlayPhase playPhase = SuperOverPlayPhase.fieldReveal,
  int wickets = 0,
}) {
  return SuperOverMatchSnapshot(
    config: SuperOverMatchConfig(
      matchId: 'resume-me',
      seed: 91,
      mode: SuperOverMode.chase,
      difficulty: SuperOverDifficulty.pro,
      level: 4,
      battingCardIds: const ['a', 'b', 'c'],
      jerseyId: 'nightCyan',
    ),
    target: 12,
    objective: const SuperOverObjective(
      type: SuperOverObjectiveType.attackGap,
      target: 2,
    ),
    wickets: wickets,
    committedBall: SuperOverCommittedBall(
      ballNumber: 1,
      planningSeed: 77,
      fieldPlan: SuperOverFieldPlan.fromCounts(const [2, 4, 3]),
      delivery: const DeliveryPlan(),
    ),
    playPhase: playPhase,
  );
}
