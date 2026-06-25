import 'package:card_game/widgets/cyber/fixture_card.dart';
import 'package:card_game/widgets/reward_settlement_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders demo reward settlement bottom modal content', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RewardSettlementPopup(
          data: RewardSettlementDemoData.demo(),
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('REWARDS SETTLED'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reward-settlement-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reward-settlement-overlay')),
      findsOneWidget,
    );
    expect(find.text('XP WON'), findsOneWidget);
    expect(find.text('COINS WON'), findsOneWidget);
    final sheet = find.byKey(const ValueKey('reward-settlement-sheet'));
    expect(sheet, findsOneWidget);
    final sheetSize = tester.getSize(sheet);
    expect(sheetSize.height, closeTo(600 * 0.75, 0.1));
    expect(sheetSize.width, closeTo(800, 0.1));
    expect(tester.getTopLeft(sheet).dx, closeTo(0, 0.1));
    expect(find.text('PREDICT'), findsOneWidget);
    expect(find.text('PICKS'), findsOneWidget);
    expect(find.text('Man City vs Arsenal'), findsOneWidget);
    expect(find.text('Chelsea to win'), findsNothing);
    expect(find.byType(FixtureCardFrame), findsWidgets);

    await tester.tap(find.text('PICKS'));
    await tester.pumpAndSettle();

    expect(find.text('Chelsea to win'), findsOneWidget);
    expect(find.text('Man City vs Arsenal'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reward-settlement-continue')));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
