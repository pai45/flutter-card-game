import 'dart:convert';
import 'dart:io';

import 'package:card_game/models/cricket_match_data.dart';
import 'package:card_game/services/espn_cricket_roster_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the live ESPN path, against a trimmed capture of the real
/// `summary.rosters[]` for the IPL 2026 final (league 8048, event 1535465).
void main() {
  late Map<String, dynamic> roster;

  setUpAll(() {
    roster =
        jsonDecode(
              File(
                'test/fixtures/espn_cricket_roster_rcb.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  test('the squad and its identity parse', () {
    final squad = parseCricketRosterSquad(roster);
    expect(squad.abbreviation, 'RCB');
    expect(squad.name, 'Royal Challengers Bengaluru');
    expect(squad.isHome, isTrue);
    expect(squad.players, hasLength(3));
    expect(squad.playerCount, 3);
    expect(squad.squadPublished, isTrue);
  });

  // Cricket buries its stats under linescores[].linescores[].statistics rather
  // than the flat array soccer uses; this is the regression lock on that walk.
  test('the 46-stat sheet is folded out of the nested linescores', () {
    final squad = parseCricketRosterSquad(roster);
    final kohli = squad.players.firstWhere((p) => p.name == 'Virat Kohli');
    final stats = kohli.matchStats!;
    // ESPN sends 46 stat names; `dismissalCard` is a display STRING rather
    // than a number, so 45 land in the numeric sheet.
    expect(stats.values, hasLength(45));
    expect(stats.runs, 75);
    expect(stats.ballsFaced, 42);
    expect(stats.intStat('fours'), 9);
    expect(stats.intStat('sixes'), 3);
    expect(stats.doubleStat('strikeRate'), closeTo(178.57, 0.01));
    expect(stats.didBat, isTrue);
    expect(stats.didBowl, isFalse);
    expect(stats.battingLine, '75* (42)');
  });

  test('a bowler folds their bowling block, not the batting one', () {
    final squad = parseCricketRosterSquad(roster);
    final bowler = squad.players.firstWhere((p) => p.name == 'Josh Hazlewood');
    final stats = bowler.matchStats!;
    expect(stats.didBowl, isTrue);
    expect(stats.wickets, greaterThan(0));
    expect(stats.doubleStat('overs'), greaterThan(0));
    expect(stats.bowlingLine, '${stats.wickets}/${stats.conceded}');
  });

  test('athlete style descriptions come through', () {
    final squad = parseCricketRosterSquad(roster);
    final kohli = squad.players.firstWhere((p) => p.name == 'Virat Kohli');
    expect(kohli.battingStyle, isNotEmpty);
    expect(kohli.styleLine, contains(kohli.battingStyle));
  });

  test('the keeper is identified from the position, not a flag', () {
    final squad = parseCricketRosterSquad(roster);
    final keeper = squad.players.firstWhere((p) => p.keeper);
    expect(keeper.name, 'Jitesh Sharma');
  });

  // The live path has no play-by-play, so the card must fall back to its
  // "no ball-by-ball" state rather than drawing an empty tape as if it were
  // data.
  test('the live path carries a sheet but no ball-by-ball', () {
    final squad = parseCricketRosterSquad(roster);
    for (final player in squad.players) {
      expect(player.matchStats, isNotNull);
      expect(player.matchStats!.hasBallByBall, isFalse);
      expect(player.matchStats!.faced, isEmpty);
      expect(player.matchStats!.bowled, isEmpty);
    }
  });

  test('an empty roster degrades instead of throwing', () {
    final squad = parseCricketRosterSquad(<String, dynamic>{
      'roster': <dynamic>[],
    });
    expect(squad.players, isEmpty);
    expect(squad.squadPublished, isFalse);
    expect(squad.playerCount, 0);
  });

  test('every stat the live feed sends has curated label copy', () {
    final squad = parseCricketRosterSquad(roster);
    final shipped = {
      for (final player in squad.players) ...player.matchStats!.values.keys,
    };
    for (final descriptor in kCricketPlayerStatCatalog) {
      expect(
        shipped,
        contains(descriptor.key),
        reason: '${descriptor.key} is catalogued but the live feed omits it',
      );
    }
  });
}
