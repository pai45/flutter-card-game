import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/data/followable_leagues.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'pd_followed_leagues_v1': '["eng.1"]',
      'pd_favorite_teams_v1': '{"eng.1":"liv"}',
    });
  });

  test('followable league lookup resolves ESPN aliases by identity', () {
    final canonical = followableLeagueById('epl');
    expect(canonical, isNotNull);
    expect(followableLeagueById('eng.1'), same(canonical));
    expect(followableLeagueById('700'), same(canonical));
    expect(
      followableLeagueFor(
        const League(
          id: '23',
          name: 'Premier League',
          shortCode: 'EPL',
          accent: Color(0xff000000),
        ),
      ),
      same(canonical),
    );
  });

  test(
    'follow mutation canonicalizes aliases and persists immediately',
    () async {
      final storage = SecureGameStorage();
      final cubit = PredictionCubit(MockPredictionRepository(), storage);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setLeagueFollowed('eng.1', true);
      expect(cubit.state.followedLeagueIds, ['epl']);
      expect(cubit.state.favoriteTeams, {'epl': 'liv'});
      expect(await storage.loadFollowedLeagueIds(), ['epl']);
      expect(await storage.loadFavoriteTeams(), {'epl': 'liv'});

      await cubit.setLeagueFollowed('700', false);
      expect(cubit.state.followedLeagueIds, isEmpty);
      expect(cubit.state.favoriteTeams, isEmpty);
      expect(await storage.loadFollowedLeagueIds(), isEmpty);
      expect(await storage.loadFavoriteTeams(), isEmpty);
    },
  );
}
