import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/screens/game/game_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('daily drop reveals immediately inside card game route', (
    tester,
  ) async {
    final slot = defaultDeckSlots.first;
    FlutterSecureStorage.setMockInitialValues({
      'pd_starter_pack_claimed_v1': 'true',
      'pd_deck_slots_v1': jsonEncode([slot.toJson()]),
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

    final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: GameTabContent(onNavigate: (AppSection _) {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('OPEN DAILY DROP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('game-pack-reveal')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });
}
