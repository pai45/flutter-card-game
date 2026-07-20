import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/models/tennis.dart';

void main() {
  test('ships the real Top 100 with unique ascii ids', () {
    expect(tennisPlayers, hasLength(100));
    expect(
      tennisPlayers.map((player) => player.id).toSet(),
      hasLength(100),
      reason: 'ids are persisted as card ids, so they must be unique',
    );
    for (final player in tennisPlayers) {
      expect(player.id.codeUnits.every((unit) => unit < 128), isTrue,
          reason: '${player.id} must be ascii-safe');
    }
    expect(tennisPlayerById('jannik-sinner').name, 'Jannik Sinner');
    expect(tennisPlayerById('frances-tiafoe').overallRating, 85);
  });

  test('sub-ratings average out to the athletes overall rating', () {
    for (final player in tennisPlayers) {
      expect(
        player.ratings.overall,
        player.overallRating,
        reason: '${player.id} would otherwise desync tier from rally physics',
      );
    }
  });

  test(
    'profile JSON round trip preserves valid records and safe fallbacks',
    () {
      final original = TennisProfile(
        starterPackClaimed: true,
        ownedPlayerIds: const ['casper-ruud'],
        selectedPlayerId: 'casper-ruud',
        difficulty: TennisDifficulty.allStar,
        completedLessons: const {1, 2, 3},
        masteryXp: const {'casper-ruud': 420},
        achievements: const {'clean-hold', 'ace-high'},
        trophies: const {'rookie': 1},
        settings: const TennisSettings(
          leftHanded: true,
          controlScale: 1.2,
          reducedMotion: true,
        ),
      );
      final restored = TennisProfile.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.starterPackClaimed, isTrue);
      expect(restored.ownedPlayerIds, ['casper-ruud']);
      expect(restored.selectedPlayerId, 'casper-ruud');
      expect(restored.difficulty, TennisDifficulty.allStar);
      expect(restored.completedLessons, {1, 2, 3});
      expect(restored.masteryFor('casper-ruud'), 420);
      expect(restored.achievements, contains('ace-high'));
      expect(restored.settings.leftHanded, isTrue);

      final fallback = TennisProfile.fromJson(<String, dynamic>{
        'difficulty': 'futureDifficulty',
        'settings': <String, dynamic>{'controlScale': 99},
        'setsWon': 7,
      });
      expect(fallback.difficulty, TennisDifficulty.pro);
      expect(fallback.settings.controlScale, 1.25);
      expect(fallback.setsWon, 7);
    },
  );

  test(
    'legacy profile JSON migrates selected athlete into tennis ownership',
    () {
      final restored = TennisProfile.fromJson(<String, dynamic>{
        'selectedPlayerId': 'luca-vale',
        'lastOpponentId': 'taylor-fritz',
        'setsWon': 3,
      });

      expect(restored.starterPackClaimed, isTrue);
      expect(restored.ownedPlayerIds, ['luca-vale']);
      expect(restored.selectedPlayerId, 'luca-vale');
      expect(restored.setsWon, 3);
    },
  );

  test('snapshot JSON round trip retains schema, config, and engine state', () {
    final snapshot = TennisMatchSnapshot(
      config: const TennisMatchConfig(
        matchId: 'resume-1',
        mode: TennisMode.targetPractice,
        playerId: 'frances-tiafoe',
        opponentId: 'taylor-fritz',
        difficulty: TennisDifficulty.pro,
        seed: 12,
      ),
      engine: const <String, dynamic>{
        'rng': 99,
        'ball': <String, dynamic>{'x': 1.25, 'z': 2.1},
      },
      savedAtMillis: 12345,
    );
    final restored = TennisMatchSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );
    expect(restored.schemaVersion, 1);
    expect(restored.config.matchId, 'resume-1');
    expect(restored.config.mode, TennisMode.targetPractice);
    expect(restored.engine['rng'], 99);
    expect(restored.savedAtMillis, 12345);
  });

  test('mastery levels rise with xp and availability follows ownership', () {
    const base = TennisProfile();
    expect(base.masteryLevel('frances-tiafoe'), 1);
    expect(base.isPlayerUnlocked('frances-tiafoe'), isFalse);

    final progressed = base.copyWith(
      ownedPlayerIds: const ['frances-tiafoe'],
      masteryXp: const {'frances-tiafoe': 310},
    );
    expect(progressed.masteryLevel('frances-tiafoe'), 3);
    expect(progressed.isPlayerUnlocked('frances-tiafoe'), isTrue);
    expect(progressed.isPlayerUnlocked('jannik-sinner'), isFalse);
  });

  test('fourth identical Rookie quick match suppresses farm bonuses', () {
    const stats = TennisMatchStats(
      aces: 3,
      winners: 12,
      firstServesIn: 8,
      firstServesAttempted: 10,
      perfectContacts: 6,
      longestRally: 22,
      breakPointsSaved: 3,
      shotTypesUsed: {
        TennisShotType.normal,
        TennisShotType.power,
        TennisShotType.topspin,
        TennisShotType.slice,
        TennisShotType.volley,
      },
    );
    const summary = TennisMatchSummary(
      matchId: 'farm-4',
      mode: TennisMode.quickMatch,
      playerId: 'frances-tiafoe',
      opponentId: 'taylor-fritz',
      difficulty: TennisDifficulty.rookie,
      playerGames: 6,
      opponentGames: 0,
      won: true,
      stats: stats,
    );
    const profile = TennisProfile(
      lastQuickSignature: 'frances-tiafoe:taylor-fritz:rookie',
      quickRepeatCount: 3,
    );
    final reward = calculateTennisReward(summary, profile);
    expect(reward.farmed, isTrue);
    expect(reward.xp, 22);
    expect(reward.coins, 10);

    final fresh = calculateTennisReward(summary, const TennisProfile());
    expect(fresh.farmed, isFalse);
    expect(fresh.xp, greaterThan(reward.xp));
    expect(fresh.coins, 20);
  });

  test(
    'training is first-completion only and tournament title is multiplied',
    () {
      const training = TennisMatchSummary(
        matchId: 'lesson',
        mode: TennisMode.training,
        playerId: 'frances-tiafoe',
        opponentId: 'taylor-fritz',
        difficulty: TennisDifficulty.pro,
        playerGames: 0,
        opponentGames: 0,
        won: true,
        stats: TennisMatchStats(),
        trainingLesson: 1,
      );
      expect(calculateTennisReward(training, const TennisProfile()).xp, 5);
      expect(
        calculateTennisReward(
          training,
          const TennisProfile(completedLessons: {1}),
        ).xp,
        0,
      );

      const title = TennisMatchSummary(
        matchId: 'title',
        mode: TennisMode.tournament,
        playerId: 'frances-tiafoe',
        opponentId: 'riven-cole',
        difficulty: TennisDifficulty.allStar,
        playerGames: 7,
        opponentGames: 6,
        won: true,
        stats: TennisMatchStats(),
        tournamentChampion: true,
      );
      final reward = calculateTennisReward(title, const TennisProfile());
      expect(reward.coins, 125);
      expect(reward.xp, greaterThanOrEqualTo(60));
    },
  );
}
