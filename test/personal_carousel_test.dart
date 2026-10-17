import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/design_system/match_discovery.generated.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/widgets/personal_prediction_selection.dart';
import 'package:card_game/screens/predictions/widgets/personal_predictions.dart';
import 'package:card_game/widgets/cyber/match_discovery.dart';

void main() {
  for (final size in [const Size(393, 1100), const Size(320, 1100)]) {
    testWidgets('personal cards scroll independently at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = List.generate(8, (i) {
        final id = 'saved-$i';
        final match = SportMatch(
          id: id,
          leagueId: 'review',
          sport: Sport.football,
          home: const SportTeam(
            id: 'h',
            name: 'Home United',
            shortName: 'HOM',
            color: Colors.blue,
          ),
          away: const SportTeam(
            id: 'a',
            name: 'Away Athletic',
            shortName: 'AWA',
            color: Colors.red,
          ),
          kickoff: DateTime(2026),
          status: MatchStatus.finished,
        );
        final quiz = PredictionQuiz(
          matchId: id,
          id: 'main',
          title: 'Scoreline quiz',
          questions: const [
            QuizQuestion(
              id: 'q',
              text: 'Who wins?',
              options: ['Home', 'Away'],
              reward: 10,
              settledOptionIndex: 0,
            ),
          ],
        );
        final prediction = UserPrediction(
          matchId: id,
          answers: const {'q': 0},
          submittedAt: DateTime(2026),
          status: i < 4 ? PredictionStatus.locked : PredictionStatus.settled,
          rewardEarned: 10,
          correctCount: 1,
        );
        return PersonalPredictionEntry(match, quiz, prediction);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: PersonalPredictions(entries: entries),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Reveal results'), findsOneWidget);
      expect(find.text('Your predictions'), findsOneWidget);
      final rails = find.byType(EditorialCarousel);
      expect(rails, findsNWidgets(2));
      final first = find.byKey(const ValueKey('personal-reveal:saved-0::main'));
      final third = find.byKey(const ValueKey('personal-reveal:saved-2::main'));
      final railRect = tester.getRect(rails.first),
          firstRect = tester.getRect(first);
      final visible = size.width < 360 ? 1.1 : 2.2;
      expect(
        firstRect.width,
        closeTo((railRect.width - visible.floor() * 16) / visible, .1),
      );
      if (size.width >= 360) {
        final thirdRect = tester.getRect(third);
        expect(thirdRect.left, lessThan(railRect.right));
        expect(thirdRect.right, greaterThan(railRect.right));
      }
      final scroll = find.descendant(
        of: rails.first,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      await tester.drag(rails.first, const Offset(-230, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      final playedScroll = find.descendant(
        of: rails.last,
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(playedScroll).position.pixels, 0);
      final focus = find
          .descendant(of: rails.first, matching: find.byType(Focus))
          .first;
      Focus.of(
        tester.element(
          find
              .descendant(
                of: focus,
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(position.pixels, 0);
      expect(MatchDiscoveryTokens.personalCarouselVisible, 2.2);
      expect(tester.takeException(), isNull);
    });
  }
}
