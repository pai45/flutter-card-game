import 'dart:convert';
import 'dart:io';

import 'package:card_game/services/espn_soccer_lineup_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the live ESPN path, against a trimmed capture of the real
/// `summary.rosters[]` for Fulham v Chelsea (event 401879318).
void main() {
  late Map<String, dynamic> roster;

  setUpAll(() {
    roster =
        jsonDecode(
              File('test/fixtures/espn_soccer_roster_che.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  test('starters and substitutes are separated', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    expect(lineup.formation, '3-4-2-1');
    expect(lineup.startingXI, hasLength(2));
    expect(lineup.substitutes, hasLength(1));
    expect(lineup.reportedPlayerCount, 3);
    expect(lineup.confirmed, isTrue);
  });

  // The pitch board sorts by formationPlace. This parser used to drop it,
  // which left every live lineup in arbitrary roster order.
  test('formationPlace survives the parse', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    final keeper = lineup.startingXI.firstWhere((p) => p.number == 1);
    expect(keeper.formationPlace, '1');
    final palmer = lineup.startingXI.firstWhere((p) => p.number == 10);
    expect(palmer.formationPlace, '10');
    // A bench player's place of "0" is not a position, so it is dropped.
    expect(lineup.substitutes.single.formationPlace, isNull);
  });

  test('the free per-player stat sheet is read off the same response', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    final palmer = lineup.startingXI.firstWhere((p) => p.name == 'Cole Palmer');
    final stats = palmer.matchStats!;
    expect(stats.values, hasLength(14));
    expect(stats.intStat('totalGoals'), 1);
    expect(stats.intStat('goalAssists'), 1);
    expect(stats.intStat('totalShots'), 5);
    expect(stats.intStat('shotsOnTarget'), 2);
    expect(stats.starter, isTrue);
    expect(stats.played, isTrue);
  });

  test('goalkeeper-only stats come through for the keeper', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    final keeper = lineup.startingXI.firstWhere((p) => p.number == 1);
    expect(keeper.matchStats!.stat('saves'), isNotNull);
    // Outfield-only stat, absent for a keeper — null, not zero.
    expect(keeper.matchStats!.stat('offsides'), isNull);
  });

  // The live path has no plays feed, so the card must fall back to its
  // "no tracked touches" state rather than drawing an empty pitch as if it
  // were data.
  test('the live path carries no positional tracking', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    for (final player in [...lineup.startingXI, ...lineup.substitutes]) {
      expect(player.matchStats!.hasTracking, isFalse);
      expect(player.matchStats!.touchCount, 0);
    }
  });

  test('short and full names are both kept', () {
    final lineup = parseSoccerRosterLineup(roster, isHomeTeam: false);
    final palmer = lineup.startingXI.firstWhere((p) => p.number == 10);
    expect(palmer.name, 'Cole Palmer');
    expect(palmer.shortName, 'C. Palmer');
  });

  test('an empty roster degrades instead of throwing', () {
    final lineup = parseSoccerRosterLineup(
      <String, dynamic>{'roster': <dynamic>[]},
      isHomeTeam: true,
    );
    expect(lineup.startingXI, isEmpty);
    expect(lineup.confirmed, isFalse);
    expect(lineup.formation, '4-3-3');
  });

  group('soccerSummarySlug', () {
    // The summary used to be fetched as fifa.world for every football fixture,
    // which is the wrong competition for a domestic match.
    test('resolves a competition by any of its colliding ids', () {
      for (final id in ['eng.1', 'EPL', 'epl', '700', '23']) {
        expect(soccerSummarySlug(id), 'eng.1');
      }
      for (final id in ['esp.1', 'LALIGA', '740', '15']) {
        expect(soccerSummarySlug(id), 'esp.1');
      }
    });

    test('falls back to fifa.world only when there is nothing to go on', () {
      expect(soccerSummarySlug(null), 'fifa.world');
      expect(soccerSummarySlug(''), 'fifa.world');
    });

    test('an unknown slug is passed through rather than misrouted', () {
      expect(soccerSummarySlug('ger.1'), 'ger.1');
    });
  });
}
