import 'dart:convert';

import 'package:card_game/app.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/screens/predictions/picks_home_view.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/widgets/landing_bottom_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    final slot = defaultDeckSlots.first;
    FlutterSecureStorage.setMockInitialValues({
      'pd_starter_pack_claimed_v1': 'true',
      'pd_selected_avatar_v1': 'adams',
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

    expect(find.text('PREDICT'), findsAtLeastNWidgets(1));
    expect(find.text('PICK'), findsAtLeastNWidgets(1));
    expect(
      find.descendant(
        of: find.byType(LandingBottomNavigation),
        matching: find.text('MATCHES'),
      ),
      findsOneWidget,
    );
    expect(find.text('TOP'), findsAtLeastNWidgets(1));
    expect(find.text('PROFILE'), findsAtLeastNWidgets(1));
  });

  testWidgets('pick tab keeps matches selected in bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('prediction_top_tab_1')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PicksHomeView), findsOneWidget);
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

  testWidgets('returns from shop to last prediction pick tab', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('prediction_top_tab_1')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PicksHomeView), findsOneWidget);
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
        matching: find.text('MATCHES'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PicksHomeView), findsOneWidget);
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

  testWidgets('returns from top to last prediction games tab', (tester) async {
    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const ValueKey('prediction_top_tab_2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PITCH DUEL'), findsOneWidget);

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
        matching: find.text('MATCHES'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PITCH DUEL'), findsOneWidget);
    expect(
      tester
          .widget<LandingBottomNavigation>(find.byType(LandingBottomNavigation))
          .selectedIndex,
      0,
    );
  });
}
