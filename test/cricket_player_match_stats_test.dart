import 'package:card_game/models/cricket_match_data.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/cricket_match_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the per-player layer against the real bundled IPL final.
///
/// These assert the numbers ESPN actually returned (league 8048, event 1535465,
/// probed 2026-09-07), not merely that the JSON parsed — a thinner asset parses
/// perfectly well.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SportMatch match;
  late List<CricketSquadPlayer> everyone;

  setUpAll(() async {
    match = await const CricketMatchPackageService().loadBundled();
    everyone = [
      for (final team in match.cricketDetails!.teams) ...team.players,
    ];
  });

  test('every player carries a match stat sheet', () {
    expect(everyone, hasLength(24));
    for (final player in everyone) {
      expect(
        player.matchStats,
        isNotNull,
        reason: '${player.name} has no matchStats',
      );
      expect(player.matchStats!.values, isNotEmpty);
    }
  });

  test('the ball feed is complete and split by innings', () {
    final all = <CricketDelivery>{
      for (final player in everyone) ...player.matchStats!.faced,
    };
    expect(all, hasLength(233));
    expect(all.where((d) => d.innings == 1), hasLength(124));
    expect(all.where((d) => d.innings == 2), hasLength(109));
  });

  // The strongest check available: three independent sources — the ball feed,
  // ESPN's stat sheet, and the hand-transcribed scorecard already in the asset
  // — must agree on every batter.
  test('deliveries reconcile with the stat sheet and the scorecard', () {
    final card = {
      for (final innings in match.cricketScorecard!.innings)
        for (final batter in innings.batters)
          if (batter.id != null) batter.id!: batter,
    };

    var checked = 0;
    for (final player in everyone) {
      final stats = player.matchStats!;
      if (!stats.didBat) continue;

      final rebuiltRuns = stats.faced.fold<int>(
        0,
        (sum, d) => sum + d.runsOffTheBat,
      );
      final rebuiltBalls = stats.faced
          .where((d) => d.countsAsBallFaced)
          .length;

      expect(rebuiltRuns, stats.runs, reason: '${player.name} runs');
      expect(rebuiltBalls, stats.ballsFaced, reason: '${player.name} balls');

      final row = card[player.id];
      if (row != null) {
        expect(row.runs, stats.runs, reason: '${player.name} vs scorecard');
        expect(row.balls, stats.ballsFaced, reason: '${player.name} vs card');
      }
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(12));
  });

  test('Kohli reads exactly as the scorecard does', () {
    final kohli = everyone.firstWhere((p) => p.name == 'Virat Kohli');
    final stats = kohli.matchStats!;
    expect(stats.battingLine, '75* (42)');
    expect(stats.intStat('fours'), 9);
    expect(stats.intStat('sixes'), 3);
    expect(stats.doubleStat('strikeRate'), closeTo(178.57, 0.01));
    expect(stats.didBat, isTrue);
    expect(stats.didBowl, isFalse);
    // 9 fours + 3 sixes = 54 of 75 runs.
    expect(stats.boundaryShare, closeTo(54 / 75, 1e-9));
  });

  test('a bowler carries a spell and reconciles with their figures', () {
    final bowlers = everyone.where((p) => p.matchStats!.didBowl).toList();
    expect(bowlers.length, greaterThanOrEqualTo(10));
    for (final player in bowlers) {
      final stats = player.matchStats!;
      expect(stats.bowled, isNotEmpty, reason: '${player.name} has no spell');
      final wickets = stats.bowled.where((d) => d.isWicket).length;
      expect(wickets, stats.wickets, reason: '${player.name} wickets');
    }
  });

  test('phase splits partition the innings', () {
    for (final player in everyone) {
      final stats = player.matchStats!;
      if (!stats.didBat) continue;
      var runs = 0;
      var balls = 0;
      for (final phase in CricketMatchPhase.values) {
        final split = stats.battingPhase(phase);
        runs += split.runs;
        balls += split.balls;
      }
      expect(runs, stats.runs, reason: '${player.name} phase runs');
      expect(balls, stats.ballsFaced, reason: '${player.name} phase balls');
    }
  });

  test('a wide is not a ball faced but a leg bye is', () {
    final all = <CricketDelivery>{
      for (final player in everyone) ...player.matchStats!.faced,
    };
    final wides = all.where((d) => d.outcome == CricketBallOutcome.wide);
    expect(wides, isNotEmpty);
    for (final ball in wides) {
      expect(ball.countsAsBallFaced, isFalse);
      expect(ball.runsOffTheBat, 0);
    }
    for (final ball in all.where(
      (d) => d.outcome == CricketBallOutcome.legBye,
    )) {
      expect(ball.countsAsBallFaced, isTrue);
      expect(ball.runsOffTheBat, 0);
    }
  });

  // If ESPN adds a stat this fails, rather than the card rendering a
  // machine-cased key.
  test('every catalogued stat key is one the asset actually ships', () {
    final shipped = {
      for (final player in everyone) ...player.matchStats!.values.keys,
    };
    expect(shipped, hasLength(46));
    for (final descriptor in kCricketPlayerStatCatalog) {
      expect(
        shipped,
        contains(descriptor.key),
        reason: '${descriptor.key} is catalogued but not shipped',
      );
    }
  });

  test('phase boundaries sit at overs 6 and 15', () {
    expect(CricketMatchPhase.forOver(1), CricketMatchPhase.powerplay);
    expect(CricketMatchPhase.forOver(6), CricketMatchPhase.powerplay);
    expect(CricketMatchPhase.forOver(7), CricketMatchPhase.middle);
    expect(CricketMatchPhase.forOver(15), CricketMatchPhase.middle);
    expect(CricketMatchPhase.forOver(16), CricketMatchPhase.death);
    expect(CricketMatchPhase.forOver(20), CricketMatchPhase.death);
  });
}
