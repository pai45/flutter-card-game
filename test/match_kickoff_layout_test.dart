import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/widgets/cyber/match_discovery.dart';

SportMatch fixture(Sport sport, MatchStatus status) => SportMatch(
  id: 'kickoff-review',
  leagueId: 'league-not-for-sport-header',
  sport: sport,
  home: const SportTeam(
    id: 'h',
    name: 'Home Athletic',
    shortName: 'HOM',
    color: Colors.blue,
  ),
  away: const SportTeam(
    id: 'a',
    name: 'Away United',
    shortName: 'AWA',
    color: Colors.red,
  ),
  kickoff: DateTime(2026, 10, 20, 0, 30),
  status: status,
  homeScore: '102',
  awayScore: '98',
  liveMinute: 67,
);
void main() {
  for (final sport in Sport.values) {
    testWidgets('centered kickoff and distinct headers: ${sport.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      double? trendsHeight;
      for (final competition in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(393, 1100),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: EditorialMatchCard(
                    match: fixture(sport, MatchStatus.upcoming),
                    competitionLabel: 'NATIONAL LEAGUE',
                    showCompetition: competition,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('00:30'), findsOneWidget);
        expect(find.text('VS'), findsNothing);
        expect(find.textContaining('Starts today'), findsNothing);
        expect(find.textContaining('Starts 20'), findsNothing);
        expect(
          find.text('NATIONAL LEAGUE'),
          competition ? findsOneWidget : findsNothing,
        );
        final status = tester.widget<EditorialStatusArea>(
          find.byType(EditorialStatusArea),
        );
        expect(status.showMarker, competition);
        expect(status.timing, isNull);
        final height = tester.getSize(find.byType(EditorialMatchCard)).height;
        if (competition) {
          trendsHeight = height;
        } else {
          expect(height, lessThan(trendsHeight!));
        }
        expect(find.text('OPEN'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('live football keeps inline clock and real score', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialMatchCard(
            match: fixture(Sport.football, MatchStatus.live),
            showCompetition: false,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('LIVE 67′'), findsOneWidget);
    expect(find.text('102 : 98'), findsOneWidget);
    expect(find.byKey(const ValueKey('editorial-kickoff-clock')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
