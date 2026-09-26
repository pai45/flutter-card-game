import 'dart:convert';

import 'package:card_game/app.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/screens/onboarding/player_profile_selector_screen.dart';
import 'package:card_game/screens/profile/profile_screen.dart';
import 'package:card_game/widgets/unlock_celebration_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real app shell: Profile → Settings → Log Out → Profile Select.
/// Guards the session hand-off, where the outgoing shell used to release the
/// unlock-reveal gate the incoming shell had already claimed (a locked-tree
/// exception that aborted the old session's teardown).
void main() {
  setUp(() {
    final slot = defaultDeckSlots.first;
    FlutterSecureStorage.setMockInitialValues({
      'pd_starter_pack_claimed_v1': 'true',
      'pd_selected_avatar_v1': 'adams',
      'pd_onboarding_complete_v1': 'true',
      'pd_onboarding_reward_status_v1': 'seen',
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

  Future<void> frames(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openProfileSelector(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PitchDuelApp());
    await frames(tester, 60);
    // Launch-time moments (e.g. the streak reminder) sit above the shell.
    for (var i = 0; i < 3; i++) {
      if (find.byType(ModalBarrier).evaluate().length <= 1) break;
      await tester.tapAt(const Offset(10, 10));
      await frames(tester, 10);
    }

    await tester.tap(find.text('PROFILE').last);
    await frames(tester, 10);
    expect(find.byType(ProfileScreen), findsOneWidget);

    final settings = find.text('Settings');
    await tester.dragUntilVisible(
      settings,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await frames(tester, 5);
    await tester.tap(settings);
    await frames(tester, 10);
    await tester.tap(find.text('LOG OUT'));
    await frames(tester, 10);
    await tester.tap(find.text('CONTINUE >'));
    await frames(tester, 20);

    expect(find.byType(PlayerProfileSelectorScreen), findsOneWidget);
    expect(UnlockRevealGate.instance.hubVisible.value, isFalse);
  }

  testWidgets('switching to the blank slot starts a clean session', (
    tester,
  ) async {
    await openProfileSelector(tester);

    await tester.tap(find.text('START FRESH'));
    await frames(tester, 40);

    expect(tester.takeException(), isNull);
    expect(find.byType(PlayerProfileSelectorScreen), findsNothing);
    expect(find.text("LET'S GET STARTED"), findsOneWidget);
    // The new session's shell still owns the reveal routes.
    final gate = UnlockRevealGate.instance;
    expect(gate.playGame, isNotNull);
    expect(gate.openSport, isNotNull);
    expect(gate.openQuestHub, isNotNull);
  });

  testWidgets('staying in the active slot returns to the profile', (
    tester,
  ) async {
    await openProfileSelector(tester);

    await tester.tap(find.text('STAY IN THIS PROFILE'));
    await frames(tester, 20);

    expect(tester.takeException(), isNull);
    expect(find.byType(PlayerProfileSelectorScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
