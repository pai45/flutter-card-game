import 'dart:convert';

import 'package:card_game/models/grand_prix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recordResult folds wins, podiums, streaks, and best position', () {
    var stats = const GrandPrixStats();

    stats = stats.recordResult(
      position: 5,
      lapTimeMs: 92000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    expect(stats.races, 1);
    expect(stats.wins, 0);
    expect(stats.podiums, 0);
    expect(stats.bestPosition, 5);
    expect(stats.currentStreak, 0);

    stats = stats.recordResult(
      position: 1,
      lapTimeMs: 90000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    stats = stats.recordResult(
      position: 1,
      lapTimeMs: 91000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    expect(stats.wins, 2);
    expect(stats.podiums, 2);
    expect(stats.bestPosition, 1);
    expect(stats.currentStreak, 2);
    expect(stats.bestStreak, 2);

    // A podium that is not a win still counts as a podium but ends the streak.
    stats = stats.recordResult(
      position: 3,
      lapTimeMs: 95000,
      circuit: GrandPrixCircuitId.desertMile,
    );
    expect(stats.podiums, 3);
    expect(stats.currentStreak, 0);
    expect(stats.bestStreak, 2);
    // Best position never worsens.
    expect(stats.bestPosition, 1);
    // Last-used circuit follows the race just run.
    expect(stats.lastCircuit, GrandPrixCircuitId.desertMile);
  });

  test('per-circuit best lap only improves and flags PBs', () {
    var stats = const GrandPrixStats();
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark), isNull);
    expect(stats.isPersonalBest(GrandPrixCircuitId.emeraldPark, 92000), isTrue);

    stats = stats.recordResult(
      position: 8,
      lapTimeMs: 92000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark), 92000);
    expect(
      stats.isPersonalBest(GrandPrixCircuitId.emeraldPark, 93000),
      isFalse,
    );

    // A slower lap never overwrites the best.
    stats = stats.recordResult(
      position: 2,
      lapTimeMs: 99000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark), 92000);

    // Other circuits track their own record.
    expect(stats.bestLapMs(GrandPrixCircuitId.harbourStreet), isNull);
  });

  test('race distances keep separate bests and remember the last laps', () {
    var stats = const GrandPrixStats();
    expect(stats.lastLaps, 1);

    // A 3-lap total time never competes with the 1-lap record.
    stats = stats.recordResult(
      position: 4,
      lapTimeMs: 92000,
      circuit: GrandPrixCircuitId.emeraldPark,
    );
    stats = stats.recordResult(
      position: 4,
      lapTimeMs: 280000,
      circuit: GrandPrixCircuitId.emeraldPark,
      laps: 3,
    );
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark), 92000);
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark, laps: 3), 280000);
    expect(stats.bestLapMs(GrandPrixCircuitId.emeraldPark, laps: 5), isNull);
    expect(
      stats.isPersonalBest(GrandPrixCircuitId.emeraldPark, 279000, laps: 3),
      isTrue,
    );
    expect(stats.lastLaps, 3);

    // The distance selection survives a JSON round-trip.
    final revived = GrandPrixStats.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(stats.toJson())) as Map),
    );
    expect(revived.lastLaps, 3);
    expect(revived.bestLapMs(GrandPrixCircuitId.emeraldPark, laps: 3), 280000);
    expect(revived.bestLapMs(GrandPrixCircuitId.emeraldPark), 92000);

    // Garbage lap counts fall back to a single lap.
    expect(GrandPrixStats.fromJson({'lastLaps': 42}).lastLaps, 1);
  });

  test('json round-trip preserves the record; bad enums fall back safely', () {
    final stats = const GrandPrixStats()
        .recordResult(
          position: 1,
          lapTimeMs: 88000,
          circuit: GrandPrixCircuitId.mountainPass,
        )
        .copyWith(lastLivery: GrandPrixLivery.papaya);

    final revived = GrandPrixStats.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(stats.toJson())) as Map),
    );
    expect(revived.races, stats.races);
    expect(revived.wins, stats.wins);
    expect(revived.bestPosition, stats.bestPosition);
    expect(revived.bestLapMs(GrandPrixCircuitId.mountainPass), 88000);
    expect(revived.lastCircuit, GrandPrixCircuitId.mountainPass);
    expect(revived.lastLivery, GrandPrixLivery.papaya);

    // Unknown/removed enum names must not throw — they fall back to defaults.
    final legacy = GrandPrixStats.fromJson({
      'lastCircuit': 'retiredCircuit',
      'lastLivery': 'retiredLivery',
      'bestLapMsByCircuit': {'retiredCircuit': 90000, 'emeraldPark': 91000},
    });
    expect(legacy.lastCircuit, GrandPrixCircuitId.emeraldPark);
    expect(legacy.lastLivery, GrandPrixLivery.gridLine);
    expect(legacy.bestLapMs(GrandPrixCircuitId.emeraldPark), 91000);
  });

  test('verdict tiers and lap formatting', () {
    expect(grandPrixVerdict(1), GrandPrixVerdict.win);
    expect(grandPrixVerdict(2), GrandPrixVerdict.podium);
    expect(grandPrixVerdict(3), GrandPrixVerdict.podium);
    expect(grandPrixVerdict(4), GrandPrixVerdict.points);
    expect(grandPrixVerdict(10), GrandPrixVerdict.points);
    expect(grandPrixVerdict(11), GrandPrixVerdict.finished);
    expect(formatLapTime(92345), '1:32.345');
    expect(formatLapTime(60005), '1:00.005');
    expect(formatLapTime(null), '--:--.---');
    expect(formatLapTime(0), '--:--.---');
  });
}
