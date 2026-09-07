import 'package:card_game/models/sport_match.dart';
import 'package:card_game/widgets/match_summary_header.dart';
import 'package:card_game/widgets/team_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('team header shows live status, score, and both teams', (
    tester,
  ) async {
    final match = _match(
      sport: Sport.football,
      status: MatchStatus.live,
      liveMinute: 67,
      homeScore: '2',
      awayScore: '1',
    );

    await tester.pumpWidget(_host(match));

    expect(find.text("LIVE 67'"), findsOneWidget);
    expect(find.text('Home United'), findsOneWidget);
    expect(find.text('Away City'), findsOneWidget);
    expect(find.text('2 - 1'), findsOneWidget);
    expect(find.byType(TeamLogo), findsNWidgets(2));
  });

  testWidgets('cricket splits runs beside the crest from the innings detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final match = _match(
      sport: Sport.cricket,
      status: MatchStatus.finished,
      homeScore: '221-4 (20 ov)',
      awayScore: '198-8 (18/20 ov, target 222)',
    );

    await tester.pumpWidget(_host(match));

    expect(find.text('FT'), findsOneWidget);
    expect(find.text('vs'), findsOneWidget);
    // The raw combined strings are gone — runs and qualifier are split.
    expect(find.text('221-4 (20 ov)'), findsNothing);
    expect(find.text('221-4 (20 ov) - 198-8 (20 ov)'), findsNothing);

    expect(find.text('221-4'), findsOneWidget);
    expect(find.text('198-8'), findsOneWidget);
    expect(find.text('20 OV'), findsOneWidget);
    expect(find.text('18/20 OV, TARGET 222'), findsOneWidget);

    // Runs sit on the crest line; the qualifier sits under the club name.
    final homeCrest = tester.getRect(find.byType(TeamLogo).first);
    final homeRuns = tester.getRect(find.text('221-4'));
    final homeName = tester.getRect(find.text('Home United'));
    final homeDetail = tester.getRect(find.text('20 OV'));

    expect(homeRuns.left, greaterThan(homeCrest.right));
    expect(homeRuns.center.dy, closeTo(homeCrest.center.dy, 4));
    expect(homeName.top, greaterThan(homeCrest.bottom));
    expect(homeDetail.top, greaterThan(homeName.bottom));
    expect(homeDetail.left, closeTo(homeName.left, 0.5));

    // The away block mirrors: crest on the outer edge, runs inside it.
    final awayCrest = tester.getRect(find.byType(TeamLogo).last);
    final awayRuns = tester.getRect(find.text('198-8'));
    expect(awayRuns.right, lessThan(awayCrest.left));

    expect(
      tester.widget<Text>(find.text('Home United')).style?.color,
      Colors.white,
    );
    expect(
      tester.widget<Text>(find.text('Away City')).style?.color,
      Colors.white,
    );
  });

  testWidgets('team blocks hug their outer edge with a one-line name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final match = _match(
      sport: Sport.football,
      status: MatchStatus.finished,
      home: const SportTeam(
        id: 'home',
        name: 'Wolverhampton Wanderers',
        shortName: 'WOL',
        color: Colors.cyan,
      ),
      homeScore: '2',
      awayScore: '3',
    );

    await tester.pumpWidget(_host(match));

    final homeCrest = tester.getRect(find.byType(TeamLogo).first);
    final awayCrest = tester.getRect(find.byType(TeamLogo).last);
    final homeName = tester.getRect(find.text('Wolverhampton Wanderers'));
    final awayName = tester.getRect(find.text('Away City'));

    // Each block sits 16px from its own screen edge, name under crest.
    expect(homeCrest.left, closeTo(16, 0.5));
    expect(awayCrest.right, closeTo(360 - 16, 0.5));
    expect(homeName.top, greaterThan(homeCrest.bottom));
    expect(homeName.left, closeTo(homeCrest.left, 0.5));
    expect(awayName.right, closeTo(awayCrest.right, 0.5));

    // Long names truncate rather than wrapping to a second line.
    final homeNameWidget = tester.widget<Text>(
      find.text('Wolverhampton Wanderers'),
    );
    expect(homeNameWidget.maxLines, 1);
    expect(homeNameWidget.overflow, TextOverflow.ellipsis);
    expect(homeName.height, lessThan(24));
  });

  testWidgets('F1 header shows weekend status and Grand Prix name', (
    tester,
  ) async {
    final match = _match(
      sport: Sport.motorsport,
      status: MatchStatus.upcoming,
      home: const SportTeam(
        id: 'british-gp',
        name: 'British Grand Prix',
        shortName: 'GBR',
        color: Colors.cyan,
      ),
    );

    await tester.pumpWidget(_host(match));

    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('BRITISH GRAND PRIX'), findsOneWidget);
    expect(find.text('23:00'), findsNothing);
    expect(find.byType(TeamLogo), findsNothing);
  });
}

Widget _host(SportMatch match) => MaterialApp(
  home: Scaffold(body: MatchSummaryHeader(match: match)),
);

SportMatch _match({
  required Sport sport,
  required MatchStatus status,
  SportTeam home = const SportTeam(
    id: 'home',
    name: 'Home United',
    shortName: 'HOM',
    color: Colors.cyan,
  ),
  String? homeScore,
  String? awayScore,
  int? liveMinute,
}) => SportMatch(
  id: 'match-1',
  leagueId: 'league-1',
  sport: sport,
  home: home,
  away: const SportTeam(
    id: 'away',
    name: 'Away City',
    shortName: 'AWY',
    color: Colors.red,
  ),
  kickoff: DateTime(2026, 7, 15, 23),
  status: status,
  liveMinute: liveMinute,
  homeScore: homeScore,
  awayScore: awayScore,
);
