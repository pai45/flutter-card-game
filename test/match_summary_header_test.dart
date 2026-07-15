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

  testWidgets('cricket header keeps scores beside their teams', (tester) async {
    final match = _match(
      sport: Sport.cricket,
      status: MatchStatus.finished,
      homeScore: '221-4 (20 ov)',
      awayScore: '198-8 (20 ov)',
    );

    await tester.pumpWidget(_host(match));

    expect(find.text('FT'), findsOneWidget);
    expect(find.text('221-4 (20 ov)'), findsOneWidget);
    expect(find.text('198-8 (20 ov)'), findsOneWidget);
    expect(find.text('vs'), findsOneWidget);
    expect(find.text('221-4 (20 ov) - 198-8 (20 ov)'), findsNothing);
  });

  testWidgets('F1 header shows weekend status and Grand Prix name', (
    tester,
  ) async {
    final match = _match(
      sport: Sport.f1,
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
