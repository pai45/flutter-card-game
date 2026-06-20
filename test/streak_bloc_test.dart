import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 0,
        'ownedCardIds': const <String>[],
        'ownedActionCardIds': const <String>[],
        'ownedCardBackIds': const ['default'],
        'equippedCardBackId': 'default',
      }),
    });
  });

  test(
    'milestone coin reward is persisted and cannot be claimed twice',
    () async {
      final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      bloc.add(StreakActivityRecorded(StreakActivity.predict));
      await bloc.stream.firstWhere(
        (state) => state.streak.announcedMilestones.contains(7),
      );

      bloc.add(StreakMilestoneClaimed(7));
      final claimed = await bloc.stream.firstWhere(
        (state) => state.streak.claimedMilestones.contains(7),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.coins, 250);
      expect(claimed.streak.claimedMilestones, contains(7));

      bloc.add(StreakMilestoneClaimed(7));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.coins, 250);

      final restored = await SecureGameStorage().loadStreak();
      expect(restored?.claimedMilestones, contains(7));
    },
  );
}
