import 'dart:io';

import 'package:card_game/screens/predictions/widgets/team_stat_board.dart';
import 'package:card_game/services/espn_league_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the real ESPN endpoints behind the league hub's STATS tab.
///
/// Skipped by default: it depends on the network and on ESPN's live season
/// data, so it would add flake to the normal suite. Drop the `skip:` argument
/// (or run with `--run-skipped`) to check the live path by hand — that is how
/// the club-stats fetch was verified.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    EspnLeagueStatsService.clearCache();
    // The test binding stubs every HTTP call to a 400 by default; this test is
    // specifically about talking to the real ESPN API.
    HttpOverrides.global = null;
  });

  test(
    'ESPN serves club season stats for both covered leagues',
    () async {
      const service = EspnLeagueStatsService();

      for (final id in ['eng.1', 'esp.1']) {
        expect(EspnLeagueStatsService.supports(id), isTrue);

        // The club directory and season year come from the snapshot pass.
        final snapshot = await service.fetchSnapshot(id);
        expect(snapshot.isEmpty, isFalse, reason: '$id snapshot');
        expect(snapshot.allRows, hasLength(20), reason: '$id standings');

        final stats = await service.fetchTeamStats(id);
        expect(stats.isEmpty, isFalse, reason: '$id club stats');
        expect(stats.teams, hasLength(20), reason: '$id club count');
        expect(stats.definitions.length, greaterThanOrEqualTo(100));

        for (final team in stats.teams) {
          expect(
            team.values.length,
            greaterThanOrEqualTo(100),
            reason: '${team.team.name} stat count',
          );
        }

        // Every curated board must rank the whole league off live data, the
        // same way it does off the bundled package.
        final live = snapshot.withTeamStats(stats);
        for (final group in footballStatGroups) {
          for (final spec in group.boards) {
            expect(
              live.statDefinitions.containsKey(spec.stat),
              isTrue,
              reason: '${group.label}/${spec.stat} missing from live feed',
            );
            expect(
              live.boardFor(spec.stat, lowerIsBetter: spec.lowerIsBetter),
              hasLength(20),
              reason: '${spec.stat} should rank every club',
            );
          }
          for (final pulse in group.pulse) {
            expect(live.statDefinitions.containsKey(pulse.stat), isTrue);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: 'hits the live ESPN API; run manually with --run-skipped',
  );
}
