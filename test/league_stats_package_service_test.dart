import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/widgets/team_stat_board.dart';
import 'package:card_game/services/league_stats_package_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LeagueStatsPackageService.clearCache);

  test('bundled package fills both covered leagues', () async {
    for (final id in ['eng.1', 'esp.1']) {
      final snapshot = await LeagueStatsPackageService.snapshotFor(id);
      expect(snapshot, isNotNull, reason: '$id should be in the package');
      expect(snapshot!.isEmpty, isFalse);

      // One flat table of 20 clubs.
      expect(snapshot.groups, hasLength(1));
      expect(snapshot.allRows, hasLength(20));
      expect(
        snapshot.allRows.map((r) => r.rank),
        List.generate(20, (i) => i + 1),
        reason: 'rows arrive rank-sorted',
      );

      // Leaderboards arrive already named — the package resolves athletes at
      // build time, so the LEADERS tab never shows "LOADING…".
      expect(snapshot.categories, isNotEmpty);
      for (final category in snapshot.categories) {
        expect(category.leaders, hasLength(10));
        expect(
          category.isResolved,
          isTrue,
          reason: '${category.key} should need no athlete fetch',
        );
      }

      // 20 clubs x 112 stats.
      expect(snapshot.hasTeamStats, isTrue);
      expect(snapshot.teamStats, hasLength(20));
      for (final team in snapshot.teamStats) {
        expect(team.values, hasLength(112));
      }
      expect(snapshot.statDefinitions, hasLength(112));
    }
  });

  test('every league id the app can produce resolves to the right league', () async {
    // The same competition reaches the hub under a curated id, the follow-list
    // id, ESPN's scoreboard id and ESPN's standings id — plus its name.
    const epl = ['eng.1', 'epl', 'EPL', '700', '23', 'English Premier League'];
    const laliga = ['esp.1', 'laliga', 'LALIGA', '740', '15', 'La Liga'];

    for (final id in epl) {
      final snapshot = await LeagueStatsPackageService.snapshotFor(id);
      expect(
        snapshot?.seasonLabel,
        contains('Premier League'),
        reason: '$id should resolve to the EPL',
      );
    }
    for (final id in laliga) {
      final snapshot = await LeagueStatsPackageService.snapshotFor(id);
      expect(
        snapshot?.seasonLabel,
        contains('LALIGA'),
        reason: '$id should resolve to LaLiga',
      );
    }

    // Name/short-code fallback for a league discovered under an id nobody
    // predicted.
    final byName = await LeagueStatsPackageService.snapshotFor(
      '99999',
      leagueName: 'Spanish LALIGA',
    );
    expect(byName?.seasonLabel, contains('LALIGA'));

    expect(await LeagueStatsPackageService.snapshotFor('nba'), isNull);
  });

  test('every curated STATS board resolves and ranks correctly', () async {
    final snapshot = await LeagueStatsPackageService.snapshotFor('eng.1');
    expect(snapshot, isNotNull);

    for (final group in footballStatGroups) {
      for (final spec in group.boards) {
        expect(
          snapshot!.statDefinitions.containsKey(spec.stat),
          isTrue,
          reason: '${group.label}/${spec.stat} must exist in the package',
        );
        final board = snapshot.boardFor(
          spec.stat,
          lowerIsBetter: spec.lowerIsBetter,
        );
        expect(
          board,
          hasLength(20),
          reason: '${spec.stat} should rank every club',
        );
        expect(board.first.rank, 1);
        expect(board.last.rank, 20);
        // Ordering honours the stat's direction.
        for (var i = 1; i < board.length; i++) {
          if (spec.lowerIsBetter) {
            expect(board[i].value, greaterThanOrEqualTo(board[i - 1].value));
          } else {
            expect(board[i].value, lessThanOrEqualTo(board[i - 1].value));
          }
        }
      }
      for (final pulse in group.pulse) {
        expect(snapshot!.statDefinitions.containsKey(pulse.stat), isTrue);
      }
    }
  });

  test('a live snapshot layers over the package without losing team stats', () async {
    final bundled = await LeagueStatsPackageService.snapshotFor('eng.1');
    expect(bundled, isNotNull);

    // A live pass that refreshed the table but carries no team stats of its
    // own — the shape every real ESPN refresh has.
    final live = LeagueStatsSnapshot(
      groups: [
        StandingsGroup(
          label: '',
          rows: [
            TeamStanding(
              team: const SportTeam(
                id: '359',
                name: 'Arsenal',
                shortName: 'ARS',
                color: Color(0xffef0107),
              ),
              rank: 1,
              played: 4,
              won: 4,
              lost: 0,
              points: 12,
              diffLabel: '+9',
              form: '',
            ),
          ],
        ),
      ],
      categories: const [],
      seasonLabel: '2026-27 LIVE',
    );

    final merged = bundled!.mergedWith(live);
    // The package is the only source of team stats, so they must survive.
    expect(merged.teamStats, hasLength(20));
    expect(merged.statDefinitions, hasLength(112));
    // The live table replaces the package's.
    expect(merged.allRows, hasLength(1));
    expect(merged.seasonLabel, '2026-27 LIVE');
    // Live carried no leaderboards, so the package's are kept rather than
    // blanking the LEADERS tab mid-refresh.
    expect(merged.categories, isNotEmpty);

    // An entirely empty live result is ignored outright — a failed refresh
    // must never downgrade a filled hub.
    final ignored = bundled.mergedWith(LeagueStatsSnapshot.empty);
    expect(ignored.allRows, hasLength(20));
    expect(ignored.seasonLabel, bundled.seasonLabel);
  });
}
