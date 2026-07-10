import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('basketball deck serialization', () {
    test('old deck json without basketball fields still loads', () {
      final slot = StoredDeckSlot.fromJson({
        'id': 'slot-1',
        'name': 'Legacy',
        'attackers': ['fra-kylian-mbappe', 'eng-harry-kane'],
        'defenders': ['ned-virgil-van-dijk', 'esp-rodri'],
        'actions': ['act1-gold'],
        'keeper': 'bra-alisson-becker',
      });

      expect(slot.basketballPlayers, isEmpty);
      expect(slot.basketballStarter, isNull);
    });

    test('basketball fields serialize and hydrate', () {
      const slot = StoredDeckSlot(
        id: 'slot-1',
        name: 'World Icons',
        attackers: ['fra-kylian-mbappe'],
        defenders: ['ned-virgil-van-dijk'],
        actions: ['act1-gold'],
        keeper: 'bra-alisson-becker',
        batsmen: ['ind-virat-kohli'],
        basketballPlayers: [
          'okc-shai-gilgeous-alexander',
          'hou-kevin-durant',
          'den-nikola-jokic',
        ],
        basketballStarter: 'okc-shai-gilgeous-alexander',
      );

      final revived = StoredDeckSlot.fromJson(slot.toJson());

      expect(revived.basketballPlayers, slot.basketballPlayers);
      expect(revived.basketballStarter, slot.basketballStarter);
      expect(revived.batsmen, slot.batsmen);
      expect(revived.keeper, slot.keeper);
    });
  });

  group('basketball starter pack', () {
    test('claims and equips only the Hoop Duel starter pack', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      final footballBefore = bloc.state.deckAttackers.map((c) => c.id).toList();
      final cricketBefore = bloc.state.deckBatsmen.map((c) => c.id).toList();

      bloc.add(BasketballStarterPackOpened());
      final opened = await bloc.stream.firstWhere(
        (state) => state.basketballStarterPackClaimed,
      );

      expect(opened.starterPackClaimed, isFalse);
      expect(opened.cricketStarterPackClaimed, isFalse);
      expect(opened.deckAttackers.map((c) => c.id), footballBefore);
      expect(opened.deckBatsmen.map((c) => c.id), cricketBefore);
      expect(opened.deckBasketballPlayers, hasLength(3));
      expect(opened.hoopDuelDeckReady, isTrue);
      expect(opened.pendingPackReveal?.headline, 'HOOP\nSTARTER');

      expect(
        opened.deckBasketballPlayers.where(
          (card) => card.role == PlayerRole.basketballGuard,
        ),
        hasLength(1),
      );
      expect(
        opened.deckBasketballPlayers.where(
          (card) => card.role == PlayerRole.basketballWing,
        ),
        hasLength(1),
      );
      expect(
        opened.deckBasketballPlayers.where(
          (card) => card.role == PlayerRole.basketballBig,
        ),
        hasLength(1),
      );
      expect(
        opened.deckBasketballPlayers.every(
          (card) => card.tier != CardTier.platinum,
        ),
        isTrue,
      );
      expect(
        opened.deckBasketballPlayers.every(
          (card) => opened.ownedCardIds.contains(card.id),
        ),
        isTrue,
      );

      final topCard = [...opened.deckBasketballPlayers]
        ..sort((a, b) => b.rating.compareTo(a.rating));
      expect(opened.deckBasketballStarter?.id, topCard.first.id);
    });
  });
}
