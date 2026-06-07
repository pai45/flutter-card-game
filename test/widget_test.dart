import 'dart:convert';

import 'package:card_game/app.dart';
import 'package:card_game/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('prediction home renders primary navigation', (tester) async {
    final slot = defaultDeckSlots.first;
    FlutterSecureStorage.setMockInitialValues({
      'pd_starter_pack_claimed_v1': 'true',
      'pd_selected_avatar_v1': 'adams',
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

    await tester.pumpWidget(const PitchDuelApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('MATCHES'), findsAtLeastNWidgets(1));
    expect(find.text('PICK'), findsAtLeastNWidgets(1));
    expect(find.text('TOP'), findsAtLeastNWidgets(1));
    expect(find.text('PROFILE'), findsAtLeastNWidgets(1));
  });
}
