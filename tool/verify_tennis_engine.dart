import 'dart:convert';
import 'dart:io';

import 'package:card_game/games/tennis/tennis_engine.dart';
import 'package:card_game/models/tennis.dart';

void main() {
  _verifyScoring();
  _verifyCourtCalls();
  _verifySnapshot();
  _verifyRewardsAndProfile();
  for (final difficulty in TennisDifficulty.values) {
    final first = _runSet(difficulty, 8800 + difficulty.index);
    final replay = _runSet(difficulty, 8800 + difficulty.index);
    _check(first.snapshot == replay.snapshot, 'Seeded replay diverged.');
    _check(
      first.summary.toJson().toString() == replay.summary.toJson().toString(),
      'Summary diverged.',
    );
    stdout.writeln(
      '${difficulty.label}: ${first.summary.playerGames}-'
      '${first.summary.opponentGames} in '
      '${first.summary.stats.durationSeconds}s',
    );
  }
  stdout.writeln('Tennis engine verification passed.');
}

void _verifyRewardsAndProfile() {
  const summary = TennisMatchSummary(
    matchId: 'farm-check',
    mode: TennisMode.quickMatch,
    playerId: 'nova-reyes',
    opponentId: 'jett-okafor',
    difficulty: TennisDifficulty.rookie,
    playerGames: 6,
    opponentGames: 2,
    won: true,
    stats: TennisMatchStats(
      winners: 9,
      perfectContacts: 4,
      longestRally: 20,
      shotTypesUsed: {
        TennisShotType.normal,
        TennisShotType.power,
        TennisShotType.topspin,
      },
    ),
  );
  const farmedProfile = TennisProfile(
    lastQuickSignature: 'nova-reyes:jett-okafor:rookie',
    quickRepeatCount: 3,
  );
  final reward = calculateTennisReward(summary, farmedProfile);
  _check(
    reward.farmed && reward.xp == 22 && reward.coins == 10,
    'Anti-farm reward was incorrect.',
  );

  final profile = TennisProfile.fromJson(
    jsonDecode(
          jsonEncode(
            const TennisProfile(
              selectedPlayerId: 'mira-chen',
              completedLessons: {1, 2, 3, 4, 5, 6, 7, 8},
              achievements: {'clean-hold'},
              trophies: {'rookie': 1},
            ).toJson(),
          ),
        )
        as Map<String, dynamic>,
  );
  _check(
    profile.isPlayerUnlocked('sora-malik'),
    'Training athlete did not unlock.',
  );
  _check(
    profile.isPlayerUnlocked('kaia-brooks'),
    'Trophy athlete did not unlock.',
  );
  _check(
    profile.achievements.contains('clean-hold'),
    'Profile JSON lost achievements.',
  );
}

void _verifyScoring() {
  final straight = TennisScoring(firstServer: 0);
  for (var game = 0; game < 6; game++) {
    for (var point = 0; point < 4; point++) {
      straight.awardPoint(0);
    }
  }
  _check(straight.state.setWinner == 0, 'Straight set did not finish.');

  final deuce = TennisScoring(firstServer: 0);
  for (var i = 0; i < 3; i++) {
    deuce.awardPoint(0);
    deuce.awardPoint(1);
  }
  deuce.awardPoint(0);
  deuce.awardPoint(1);
  _check(deuce.state.isDeuce, 'Advantage did not return to deuce.');

  final tieBreak = TennisScoring(firstServer: 0);
  for (var game = 0; game < 6; game++) {
    for (var point = 0; point < 4; point++) {
      tieBreak.awardPoint(0);
    }
    for (var point = 0; point < 4; point++) {
      tieBreak.awardPoint(1);
    }
  }
  _check(tieBreak.state.tieBreak, 'Tiebreak did not start at 6-6.');
  for (final winner in <int>[0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0]) {
    tieBreak.awardPoint(winner);
  }
  _check(tieBreak.state.setWinner == 0, 'Long tiebreak did not finish 8-6.');
}

void _verifyCourtCalls() {
  _check(
    tennisBallInsideSingles(tennisCourtHalfWidth, tennisCourtHalfLength),
    'Court lines must be in.',
  );
  _check(
    tennisServeInsideBox(
      x: tennisCourtHalfWidth,
      y: -tennisServiceLine,
      server: 0,
      rightServiceCourt: true,
    ),
    'Service-box lines must be in.',
  );
  _check(
    !tennisServeInsideBox(x: -1, y: -4, server: 0, rightServiceCourt: true),
    'Wrong service box was accepted.',
  );
}

void _verifySnapshot() {
  final config = _config(TennisDifficulty.pro, 7123);
  final engine = TennisEngine(config);
  final ai0 = TennisAI(difficulty: config.difficulty, seed: 1, team: 0);
  final ai1 = TennisAI(difficulty: config.difficulty, seed: 2, team: 1);
  for (var i = 0; i < 2400; i++) {
    engine.step(
      ai0.think(engine, 1 / 120),
      ai1.think(engine, 1 / 120),
      1 / 120,
    );
  }
  final restored = TennisEngine(
    config,
    snapshot: jsonDecode(jsonEncode(engine.snapshot())) as Map<String, dynamic>,
  );
  final restoredAi0 = TennisAI(difficulty: config.difficulty, seed: 1, team: 0)
    ..restore(ai0.snapshot());
  final restoredAi1 = TennisAI(difficulty: config.difficulty, seed: 2, team: 1)
    ..restore(ai1.snapshot());
  for (var i = 0; i < 2400; i++) {
    engine.step(
      ai0.think(engine, 1 / 120),
      ai1.think(engine, 1 / 120),
      1 / 120,
    );
    restored.step(
      restoredAi0.think(restored, 1 / 120),
      restoredAi1.think(restored, 1 / 120),
      1 / 120,
    );
  }
  _check(
    jsonEncode(engine.snapshot()) == jsonEncode(restored.snapshot()),
    'Restored engine did not continue exactly.',
  );
}

({TennisMatchSummary summary, String snapshot}) _runSet(
  TennisDifficulty difficulty,
  int seed,
) {
  final config = _config(difficulty, seed);
  final engine = TennisEngine(config);
  final ai0 = TennisAI(difficulty: difficulty, seed: seed ^ 0x101, team: 0);
  final ai1 = TennisAI(difficulty: difficulty, seed: seed ^ 0x202, team: 1);
  const maxSteps = 120 * 60 * 40;
  for (var i = 0; i < maxSteps && !engine.complete; i++) {
    engine.step(
      ai0.think(engine, 1 / 120),
      ai1.think(engine, 1 / 120),
      1 / 120,
    );
    _check(
      engine.player.stamina >= 0 && engine.player.stamina <= 100,
      'Player stamina escaped bounds.',
    );
    _check(
      engine.opponent.stamina >= 0 && engine.opponent.stamina <= 100,
      'AI stamina escaped bounds.',
    );
    _check(
      engine.ball.x.isFinite &&
          engine.ball.y.isFinite &&
          engine.ball.z.isFinite,
      'Ball became non-finite.',
    );
  }
  _check(engine.complete, '${difficulty.label} set failed to finish.');
  return (
    summary: engine.summary(),
    snapshot: jsonEncode(<String, dynamic>{
      'engine': engine.snapshot(),
      'ai0': ai0.snapshot(),
      'ai1': ai1.snapshot(),
    }),
  );
}

TennisMatchConfig _config(TennisDifficulty difficulty, int seed) =>
    TennisMatchConfig(
      matchId: 'verify-$seed',
      mode: TennisMode.quickMatch,
      playerId: 'nova-reyes',
      opponentId: 'jett-okafor',
      difficulty: difficulty,
      seed: seed,
    );

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
