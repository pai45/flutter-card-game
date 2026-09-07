import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/services/cricket_league_stats_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the bundled IPL league package against the real aggregate.
///
/// The numbers here are the actual IPL 2026 season, summed from all 74 match
/// summaries (ESPN publishes no league-level leaders or team-stats feed for
/// cricket — see docs/data/ipl-match-player-field-inventory.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LeagueStatsSnapshot snapshot;

  setUpAll(() async {
    CricketLeagueStatsPackageService.clearCache();
    snapshot = (await CricketLeagueStatsPackageService.snapshotFor('ipl'))!;
  });

  test('the package fills the hub that used to be empty', () {
    expect(snapshot.isEmpty, isFalse);
    expect(snapshot.groups, hasLength(1));
    expect(snapshot.groups.single.rows, hasLength(10));
    expect(snapshot.categories, hasLength(9));
    expect(snapshot.teamStats, hasLength(10));
    expect(snapshot.seasonLabel, isNotNull);
  });

  // The same competition reaches the cubit as 'ipl', ESPN's numeric id, or a
  // display name. A single-key lookup is what left the hub blank for football.
  test('resolves by every alias, not one id', () async {
    for (final id in ['ipl', 'IPL', '8048', 'Indian Premier League']) {
      expect(
        await CricketLeagueStatsPackageService.snapshotFor(id),
        isNotNull,
        reason: '$id should resolve',
      );
    }
    expect(
      await CricketLeagueStatsPackageService.snapshotFor(
        'nonsense',
        shortCode: 'IPL',
      ),
      isNotNull,
      reason: 'short code is a fallback',
    );
    expect(
      await CricketLeagueStatsPackageService.snapshotFor('eng.1'),
      isNull,
      reason: 'football must not resolve to the cricket package',
    );
  });

  test('the table is a real 10-team IPL season, ranked', () {
    final rows = snapshot.groups.single.rows;
    for (var i = 0; i < rows.length; i++) {
      expect(rows[i].rank, i + 1);
      expect(rows[i].played, greaterThan(0));
      expect(rows[i].team.name, isNotEmpty);
      expect(rows[i].team.shortName, isNotEmpty);
      expect(rows[i].won + rows[i].lost, lessThanOrEqualTo(rows[i].played));
      // Null `drawn` is the contract StandingsTable reads as "cricket", which
      // is what swaps the GD column for NRR.
      expect(rows[i].drawn, isNull);
    }
    // Net run rate carries a sign, which is how a cricket table is read.
    expect(rows.first.diffLabel, anyOf(startsWith('+'), startsWith('-')));
    // Points must not increase as rank worsens.
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].points, lessThanOrEqualTo(rows[i - 1].points));
    }
  });

  test('every leader board is named, ranked and resolved', () {
    for (final category in snapshot.categories) {
      expect(category.label, isNotEmpty);
      expect(category.unitLabel, isNotEmpty);
      expect(category.leaders, isNotEmpty);
      for (final leader in category.leaders) {
        expect(
          leader.name,
          isNotNull,
          reason: '${category.label} has an unresolved athlete',
        );
        expect(leader.team, isNotNull);
        expect(leader.displayValue, isNotEmpty);
      }
    }
  });

  test('boards rank in the direction that makes them a leaderboard', () {
    for (final category in snapshot.categories) {
      final values = category.leaders.map((l) => l.value).toList();
      // Economy is the one board where the smallest number wins.
      final ascending = category.key == 'economyRate';
      for (var i = 1; i < values.length; i++) {
        if (ascending) {
          expect(values[i], greaterThanOrEqualTo(values[i - 1]));
        } else {
          expect(values[i], lessThanOrEqualTo(values[i - 1]));
        }
      }
    }
  });

  // A rate board without a qualifying minimum would be topped by whoever bowled
  // one tidy over, which is the classic way to make a leaderboard meaningless.
  test('rate boards state their qualifying minimum', () {
    for (final key in ['strikeRate', 'economyRate']) {
      final board = snapshot.categories.firstWhere((c) => c.key == key);
      expect(board.unitLabel, contains('+'));
    }
  });

  test('the season leaders match the real IPL 2026 charts', () {
    final runs = snapshot.categories.firstWhere((c) => c.key == 'runs');
    expect(runs.leaders.first.name, 'Vaibhav Sooryavanshi');
    expect(runs.leaders.first.value, 776);

    final wickets = snapshot.categories.firstWhere((c) => c.key == 'wickets');
    expect(wickets.leaders.first.name, 'Kagiso Rabada');
    expect(wickets.leaders.first.value, 29);
  });

  test('team stats carry real season totals with definitions', () {
    for (final team in snapshot.teamStats) {
      expect(team.values, isNotEmpty);
      expect(team['runs'], isNotNull);
      expect(team['runs']!.value, greaterThan(0));
      expect(team['wickets'], isNotNull);
    }
    // Every stat the STATS boards can show must have label copy.
    for (final key in ['runs', 'wickets', 'sixes', 'dots']) {
      expect(snapshot.statDefinitions[key], isNotNull);
      expect(snapshot.statDefinitions[key]!.displayName, isNotEmpty);
    }
  });

  test('the champions top the table', () {
    // RCB won the 2026 final, and finished first in the group stage.
    expect(snapshot.groups.single.rows.first.team.shortName, 'RCB');
    expect(snapshot.groups.single.rows.first.zoneNote, 'Playoffs');
  });
}
