import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/models/tennis.dart';

void main() {
  test('ships the eight specified athletes and exact headline ratings', () {
    expect(tennisPlayers, hasLength(8));
    expect(tennisPlayerById('nova-reyes').ratings.speed, 80);
    expect(tennisPlayerById('jett-okafor').ratings.power, 92);
    expect(tennisPlayerById('mira-chen').ratings.stamina, 94);
    expect(tennisPlayerById('luca-vale').ratings.volley, 93);
    expect(tennisPlayerById('sora-malik').ratings.spin, 94);
    expect(tennisPlayerById('kaia-brooks').ratings.serve, 86);
    expect(tennisPlayerById('theo-laurent').ratings.reach, 89);
    expect(tennisPlayerById('riven-cole').ratings.control, 87);
  });

  test(
    'profile JSON round trip preserves valid records and safe fallbacks',
    () {
      final original = TennisProfile(
        starterPackClaimed: true,
        ownedPlayerIds: const ['mira-chen'],
        selectedPlayerId: 'mira-chen',
        difficulty: TennisDifficulty.allStar,
        completedLessons: const {1, 2, 3},
        masteryXp: const {'mira-chen': 420},
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
      expect(restored.ownedPlayerIds, ['mira-chen']);
      expect(restored.selectedPlayerId, 'mira-chen');
      expect(restored.difficulty, TennisDifficulty.allStar);
      expect(restored.completedLessons, {1, 2, 3});
      expect(restored.masteryFor('mira-chen'), 420);
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
        'lastOpponentId': 'jett-okafor',
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
        playerId: 'nova-reyes',
        opponentId: 'jett-okafor',
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

  test('mastery levels and athlete availability follow progression gates', () {
    const base = TennisProfile();
    expect(base.masteryLevel('nova-reyes'), 1);
    expect(base.isPlayerUnlocked('nova-reyes'), isTrue);
    expect(base.isPlayerUnlocked('sora-malik'), isFalse);

    final progressed = base.copyWith(
      masteryXp: const {'nova-reyes': 310},
      completedLessons: const {1, 2, 3, 4, 5, 6, 7, 8},
      trophies: const {'rookie': 1, 'pro': 1, 'allStar': 1},
    );
    expect(progressed.masteryLevel('nova-reyes'), 3);
    expect(progressed.isPlayerUnlocked('sora-malik'), isTrue);
    expect(progressed.isPlayerUnlocked('kaia-brooks'), isTrue);
    expect(progressed.isPlayerUnlocked('theo-laurent'), isTrue);
    expect(progressed.isPlayerUnlocked('riven-cole'), isTrue);
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
      playerId: 'nova-reyes',
      opponentId: 'jett-okafor',
      difficulty: TennisDifficulty.rookie,
      playerGames: 6,
      opponentGames: 0,
      won: true,
      stats: stats,
    );
    const profile = TennisProfile(
      lastQuickSignature: 'nova-reyes:jett-okafor:rookie',
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
        playerId: 'nova-reyes',
        opponentId: 'jett-okafor',
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
        playerId: 'nova-reyes',
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
