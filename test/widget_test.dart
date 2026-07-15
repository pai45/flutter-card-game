import 'dart:convert';

import 'package:card_game/app.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/widgets/landing_bottom_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    final slot = defaultDeckSlots.first;
    FlutterSecureStorage.setMockInitialValues({
      'pd_starter_pack_claimed_v1': 'true',
      'pd_selected_avatar_v1': 'adams',
      'pd_onboarding_complete_v1': 'true',
      'pd_demo_reward_settlement_seen_v1': 'true',
      'pd_deck_slots_v1': jsonEncode([slot.toJson()]),
      'pd_pick_positions_v1': '[]',
    });
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 0,
        'ownedCardIds': [...slot.attackers, ...slot.defenders],
        'ownedActionCardIds': slot.actions,
        'ownedCardBackIds': ['default'],
        'equippedCardBackId': 'default',
      }),
    });
  });

  testWidgets('prediction home renders primary navigation', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('MATCH'), findsAtLeastNWidgets(1));
    expect(find.text('GAMES'), findsAtLeastNWidgets(1));
    expect(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SPORTS'),
      ),
      findsOneWidget,
    );
    expect(find.text('TOP'), findsAtLeastNWidgets(1));
    expect(find.text('PROFILE'), findsAtLeastNWidgets(1));
  });

  testWidgets('games tab keeps match selected in bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('cyber_gliding_tab_1')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<PredictionHomeScreen>(find.byType(PredictionHomeScreen))
          .activeTab,
      1,
    );
    final bottomNav = tester.widget<LandingBottomNavigation>(
      find.byType(LandingBottomNavigation),
    );
    expect(bottomNav.selectedIndex, 0);
  });

  testWidgets('returns from shop to last match games tab', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('cyber_gliding_tab_1')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<PredictionHomeScreen>(find.byType(PredictionHomeScreen))
          .activeTab,
      1,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SHOP'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<LandingBottomNavigation>(find.byType(LandingBottomNavigation))
          .selectedIndex,
      1,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SPORTS'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<PredictionHomeScreen>(find.byType(PredictionHomeScreen))
          .activeTab,
      1,
    );
    expect(
      tester
          .widget<LandingBottomNavigation>(find.byType(LandingBottomNavigation))
          .selectedIndex,
      0,
    );
  });

  testWidgets('returns to remembered games sport tab', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('cyber_gliding_tab_1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('FORMULA 1').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('GRAND PRIX DASH'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SHOP'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SPORTS'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester
          .widget<PredictionHomeScreen>(find.byType(PredictionHomeScreen))
          .activeTab,
      1,
    );
    expect(find.text('GRAND PRIX DASH'), findsOneWidget);
    expect(find.text('PITCH DUEL'), findsNothing);
  });

  testWidgets('returns from top to last prediction games tab', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('cyber_gliding_tab_1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('TOP'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<LandingBottomNavigation>(find.byType(LandingBottomNavigation))
          .selectedIndex,
      2,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('SPORTS'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));
    expect(
      tester
          .widget<LandingBottomNavigation>(find.byType(LandingBottomNavigation))
          .selectedIndex,
      0,
    );
  });

  testWidgets('games tab separates sports with shop-style tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('cyber_gliding_tab_1')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FOOTBALL'), findsAtLeastNWidgets(1));
    expect(find.text('FORMULA 1'), findsAtLeastNWidgets(1));
    expect(find.text('BASKET'), findsAtLeastNWidgets(1));
    expect(find.text('CRICKET'), findsAtLeastNWidgets(1));
    expect(find.text('PITCH DUEL'), findsAtLeastNWidgets(1));
    expect(find.text('PENALTY SHOOTOUT'), findsAtLeastNWidgets(1));
    expect(find.text('5V5 FOOTBALL CHESS'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('FOOTBALL QUIZ'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('FOOTBALL QUIZ'), findsAtLeastNWidgets(1));
    expect(find.text('FOOTBALL BINGO'), findsAtLeastNWidgets(1));
    expect(find.text('GUESS THE PLAYER'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('FORMULA 1').last);
    await tester.pump(const Duration(milliseconds: 300));
    // The F1 tab now hosts a real game instead of a coming-soon state.
    expect(find.text('GRAND PRIX DASH'), findsOneWidget);
    expect(find.text('ONE-LAP ARCADE RACER'), findsOneWidget);
    expect(find.text('PITCH DUEL'), findsNothing);

    await tester.tap(find.text('BASKET').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('HOOP DUEL'), findsOneWidget);
    expect(find.text('STREET 1-ON-1 ARCADE HOOPS'), findsOneWidget);
    expect(find.text('PITCH DUEL'), findsNothing);

    await tester.tap(find.text('CRICKET').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FINAL OVER'), findsOneWidget);
    expect(find.text('SIX-BALL CRICKET CHASE'), findsOneWidget);
    expect(find.text('PITCH DUEL'), findsNothing);
  });
}
