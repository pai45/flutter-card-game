import 'package:card_game/widgets/cyber/fixture_card.dart';
import 'package:card_game/widgets/reward_settlement_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders demo reward settlement content', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RewardSettlementPopup(
          data: RewardSettlementDemoData.demo(),
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));

    expect(find.text('REWARDS SETTLED'), findsOneWidget);
    expect(find.text('XP WON'), findsOneWidget);
    expect(find.text('COINS WON'), findsOneWidget);
    final sheet = find.byKey(const ValueKey('reward-settlement-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, closeTo(600 * 0.75, 0.1));
    expect(find.text('PREDICT'), findsOneWidget);
    expect(find.text('PICKS'), findsOneWidget);
    expect(find.text('Man City vs Arsenal'), findsOneWidget);
    expect(find.text('Chelsea to win'), findsNothing);
    expect(find.byType(FixtureCardFrame), findsWidgets);

    await tester.tap(find.text('PICKS'));
    await tester.pumpAndSettle();

    expect(find.text('Chelsea to win'), findsOneWidget);
    expect(find.text('Man City vs Arsenal'), findsNothing);

    await tester.tap(find.text('CONTINUE'));

    expect(dismissed, isTrue);
  });
}
