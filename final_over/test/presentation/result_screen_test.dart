import 'package:final_over/presentation/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  testWidgets('victory result presents stats and routes both actions', (
    tester,
  ) async {
    useTestViewport(tester, const Size(393, 852));
    var replayCount = 0;
    var homeCount = 0;
    const summary = GameResultSummary(
      won: true,
      runs: 15,
      target: 14,
      legalBalls: 5,
      wickets: 1,
      stars: 3,
      points: 2450,
      objectiveLabel: 'Hit two boundaries',
      objectiveComplete: true,
      history: <String>['1', '4', 'W', '6', '4'],
      reason: 'TARGET CHASED',
    );

    await tester.pumpWidget(
      finalOverTestApp(
        home: ResultScreen(
          summary: summary,
          onPlayAgain: () => replayCount++,
          onHome: () => homeCount++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.text('15/1'), findsOneWidget);
    expect(find.text('TARGET CHASED'), findsOneWidget);
    expect(find.text('POINTS 2450'), findsOneWidget);
    expect(find.text('Hit two boundaries'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expectNoBuildException(tester);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.tap(find.text('HOME'));
    expect(replayCount, 1);
    expect(homeCount, 1);
  });

  testWidgets('defeat result reports terminal reason and blocks system back', (
    tester,
  ) async {
    useTestViewport(tester, const Size(360, 800));
    const summary = GameResultSummary(
      won: false,
      runs: 9,
      target: 14,
      legalBalls: 6,
      wickets: 1,
      stars: 1,
      points: 900,
      objectiveLabel: 'Complete a double',
      objectiveComplete: false,
      history: <String>['1', '0', '2', 'W', '4', '2'],
      reason: 'SIX LEGAL BALLS USED',
    );

    await tester.pumpWidget(
      finalOverTestApp(
        home: ResultScreen(summary: summary, onPlayAgain: () {}, onHome: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('DEFEAT'), findsOneWidget);
    expect(find.text('SIX LEGAL BALLS USED'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    expectNoBuildException(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('DEFEAT'), findsOneWidget);
  });
}
