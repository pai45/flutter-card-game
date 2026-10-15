import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/tennis_scorecard.dart';
import 'package:card_game/screens/predictions/widgets/match_prediction_card.dart';
import 'package:card_game/widgets/cyber/match_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The pre-editorial renderer is still needed by Tennis. Retired multi-sport
  // helpers must not take its score, set details or status with them.
  for (final status in MatchStatus.values) {
    testWidgets('Tennis fallback retains identity and scores: ${status.name}', (
      tester,
    ) async {
      final hasScore = status != MatchStatus.upcoming;
      final match = SportMatch(
        id: 'tennis-cleanup-review',
        leagueId: 'review',
        sport: Sport.tennis,
        home: const SportTeam(
          id: 'home',
          name: 'Player North',
          shortName: 'NOR',
          color: Colors.blue,
        ),
        away: const SportTeam(
          id: 'away',
          name: 'Player South',
          shortName: 'SOU',
          color: Colors.red,
        ),
        kickoff: DateTime(2026, 10, 15, 20),
        status: status,
        homeScore: hasScore ? '2' : null,
        awayScore: hasScore ? '0' : null,
        resultLine: status == MatchStatus.finished ? 'Player North won' : null,
        tennisScorecard: hasScore
            ? const TennisScorecard(
                sets: [
                  TennisSet(homeScore: 6, awayScore: 4),
                  TennisSet(homeScore: 6, awayScore: 2),
                ],
              )
            : null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchPredictionCard(match: match, prediction: null),
          ),
        ),
      );
      expect(find.byType(EditorialMatchCard), findsNothing);
      expect(find.text('Player North'), findsOneWidget);
      expect(find.text('Player South'), findsOneWidget);
      expect(
        find.text('2  -  0', findRichText: true),
        hasScore ? findsOneWidget : findsNothing,
      );
      expect(find.text('6-4'), hasScore ? findsOneWidget : findsNothing);
      expect(find.text('6-2'), hasScore ? findsOneWidget : findsNothing);
      expect(
        find.text(switch (status) {
          MatchStatus.upcoming => '20:00',
          MatchStatus.live => 'LIVE',
          MatchStatus.finished => 'Finished',
        }),
        findsOneWidget,
      );
      if (status == MatchStatus.finished) {
        expect(find.text('Player North won'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
