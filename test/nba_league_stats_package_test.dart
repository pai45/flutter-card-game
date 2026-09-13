import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/screens/predictions/widgets/team_stat_board.dart';
import 'package:card_game/services/nba_league_stats_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the bundled NBA league package against the real 2025-26 season.
///
/// Unlike cricket, every league-level ESPN feed answers for basketball, so
/// these numbers are a straight extraction rather than an aggregation — see
/// docs/data/nba-league-stats-field-inventory.md.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LeagueStatsSnapshot snapshot;

  setUpAll(() async {
    NbaLeagueStatsPackageService.clearCache();
    snapshot = (await NbaLeagueStatsPackageService.snapshotFor('nba'))!;
  });

  test('the package fills the hub that used to be empty', () {
    expect(snapshot.isEmpty, isFalse);
    // Two conferences, not one flat table — the group toggle is the point.
    expect(snapshot.groups, hasLength(2));
    for (final group in snapshot.groups) {
      expect(group.rows, hasLength(15));
      expect(group.label, isNotEmpty);
    }
    expect(snapshot.categories, hasLength(12));
    expect(snapshot.teamStats, hasLength(30));
    expect(snapshot.seasonLabel, '2025-26');
    expect(snapshot.seasonYear, 2026);
  });

  // The same competition reaches the cubit as 'nba', ESPN's numeric id, or a
  // display name. A single-key lookup is what left the hub blank for football.
  test('resolves by every alias, not one id', () async {
    for (final id in ['nba', 'NBA', '46', 'National Basketball Association']) {
      expect(
        await NbaLeagueStatsPackageService.snapshotFor(id),
        isNotNull,
        reason: '$id should resolve',
      );
    }
    expect(
      await NbaLeagueStatsPackageService.snapshotFor(
        'nonsense',
        shortCode: 'NBA',
      ),
      isNotNull,
      reason: 'short code is a fallback',
    );
    // 'basketball' is the sport, not the competition: matching it would hand
    // the WNBA the NBA's table.
    for (final other in ['eng.1', 'ipl', '8048', 'basketball', 'wnba']) {
      expect(
        await NbaLeagueStatsPackageService.snapshotFor(other),
        isNull,
        reason: '$other must not resolve to the NBA package',
      );
    }
  });

  test('each conference is a real 15-team table, seeded', () {
    for (final group in snapshot.groups) {
      final rows = group.rows;
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].rank, i + 1, reason: 'seeds must run 1..15 in order');
        expect(rows[i].team.name, isNotEmpty);
        expect(rows[i].team.shortName, isNotEmpty);
        // 82 games, and played is exactly W+L because there are no draws.
        expect(rows[i].won + rows[i].lost, rows[i].played);
        expect(rows[i].played, greaterThan(0));
        // The contract StandingsTable reads as "basketball", which is what
        // swaps football's P/W/D/L/GD for W/L/PCT/GB. A null `drawn` alone
        // would be read as cricket.
        expect(rows[i].winPercent, isNotNull);
        expect(rows[i].drawn, isNull);
        expect(rows[i].streak, isNotNull);
        expect(rows[i].lastTen, isNotNull);
      }
      // Win percentage must not climb as the seed worsens.
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].winPercent!, lessThanOrEqualTo(rows[i - 1].winPercent!));
      }
      // The leader has no games to make up; everyone below does.
      expect(rows.first.diffLabel, '—');
      expect(rows.last.diffLabel, isNot('—'));
    }
  });

  // The 6/10 split is the NBA's published structure. ESPN states only a seed
  // number, so the two cut lines have to be derived — and they are what makes
  // the table readable as a playoff race rather than a list.
  test('the playoff and play-in cut lines land on the real seeds', () {
    for (final group in snapshot.groups) {
      final rows = group.rows;
      for (final row in rows) {
        final expected = switch (row.rank) {
          <= 6 => 'Playoffs',
          <= 10 => 'Play-In',
          _ => null,
        };
        expect(row.zoneNote, expected, reason: 'seed ${row.rank}');
      }
      expect(rows.where((r) => r.zoneNote == 'Playoffs'), hasLength(6));
      expect(rows.where((r) => r.zoneNote == 'Play-In'), hasLength(4));
    }
  });

  test('every leader board is named, ranked and resolved', () {
    for (final category in snapshot.categories) {
      expect(category.label, isNotEmpty);
      expect(category.unitLabel, isNotEmpty);
      expect(category.leaders, hasLength(10));
      for (final leader in category.leaders) {
        expect(
          leader.name,
          isNotNull,
          reason: '${category.label} has an unresolved athlete',
        );
        expect(leader.team, isNotNull);
        expect(leader.displayValue, isNotEmpty);
      }
      final values = category.leaders.map((l) => l.value).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThanOrEqualTo(values[i - 1]));
      }
    }
  });

  // ESPN's leader feed applies no games or minutes cut of its own, so an
  // eight-appearance two-way player topped PER and free-throw percentage until
  // the league's own minimums were applied. The headline has to say so.
  test('rate boards state their qualifying minimum', () {
    for (final key in ['PER', 'fieldGoalPercentage', 'FreeThrowPct']) {
      final board = snapshot.categories.firstWhere((c) => c.key == key);
      expect(board.unitLabel, contains('//'));
    }
    final games = snapshot.categories.firstWhere((c) => c.key == 'PER');
    expect(games.unitLabel, contains('58+ GAMES'));
    final throws = snapshot.categories.firstWhere(
      (c) => c.key == 'FreeThrowPct',
    );
    expect(throws.unitLabel, contains('125+ MADE'));
    // Double-doubles are a count, so the board carries no cut at all.
    final counts = snapshot.categories.firstWhere(
      (c) => c.key == 'doubleDouble',
    );
    expect(counts.unitLabel, isNot(contains('//')));
  });

  test('the season leaders match the real 2025-26 charts', () {
    final points = snapshot.categories.firstWhere(
      (c) => c.key == 'pointsPerGame',
    );
    expect(points.leaders.first.name, 'Luka Doncic');
    expect(points.leaders.first.value, closeTo(33.5, 0.05));
    // Basketball quotes a rate to one decimal, not two.
    expect(points.leaders.first.shortValue, '33.5');

    final efficiency = snapshot.categories.firstWhere((c) => c.key == 'PER');
    expect(efficiency.leaders.first.name, 'Nikola Jokic');

    // ESPN ships 3P% as a 0-1 fraction while FG% and FT% in the same response
    // are already 0-100; the generator scales it so all three read alike.
    final threes = snapshot.categories.firstWhere((c) => c.key == '3PointPct');
    expect(threes.leaders.first.value, greaterThan(30));
    expect(threes.leaders.first.value, lessThan(100));
  });

  test('team stats carry real season totals with ESPN definitions', () {
    for (final team in snapshot.teamStats) {
      expect(team.values, isNotEmpty);
      expect(team['points'], isNotNull);
      expect(team['points']!.value, greaterThan(0));
      expect(team['avgRebounds'], isNotNull);
    }
    for (final key in ['points', 'avgRebounds', 'threePointPct', 'fouls']) {
      expect(snapshot.statDefinitions[key], isNotNull);
      expect(snapshot.statDefinitions[key]!.displayName, isNotEmpty);
    }
    // ESPN publishes real prose for basketball, unlike cricket where the
    // explainers had to be written by hand.
    expect(snapshot.statDefinitions['points']!.description, isNotNull);
  });

  // Basketball files its stats under the same `offensive` / `defensive` /
  // `general` categories football does, so the STATS tab cannot pick its board
  // set by category the way cricket is picked.
  test('the STATS tab picks the basketball boards, not football\'s', () {
    final groups = statGroupsFor(snapshot.statDefinitions);
    expect(groups, same(basketballStatGroups));
    expect(
      groups.map((g) => g.label),
      containsAll(['SCORING', 'PLAYMAKING', 'DEFENCE', 'DISCIPLINE']),
    );
    // Every curated board must exist in the shipped dictionary, or it renders
    // as NOT PUBLISHED.
    for (final group in groups) {
      for (final board in group.boards) {
        expect(
          snapshot.statDefinitions[board.stat],
          isNotNull,
          reason: '${group.label} board ${board.stat} is not in the package',
        );
      }
      for (final pulse in group.pulse) {
        expect(
          snapshot.statDefinitions[pulse.stat],
          isNotNull,
          reason: '${group.label} pulse ${pulse.stat} is not in the package',
        );
      }
    }
  });

  test('the conference winners top their tables', () {
    final byLabel = {for (final g in snapshot.groups) g.label: g};
    expect(
      byLabel['Eastern Conference']!.rows.first.team.shortName,
      'DET',
    );
    expect(
      byLabel['Western Conference']!.rows.first.team.shortName,
      'OKC',
    );
  });
}
