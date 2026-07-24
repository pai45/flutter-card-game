import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/deck.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('StoredDeckSlot shared sport fields', () {
    test('legacy JSON hydrates missing tennis and racing fields', () {
      final slot = StoredDeckSlot.fromJson({
        'id': 'legacy',
        'name': 'Legacy Squad',
        'attackers': ['fra-kylian-mbappe'],
        'defenders': ['ned-virgil-van-dijk'],
        'actions': ['act1-gold'],
      });

      expect(slot.tennisPlayers, isEmpty);
      expect(slot.tennisStarter, isNull);
      expect(slot.racingPlayers, isEmpty);
      expect(slot.racingStarter, isNull);
    });

    test('copyWith preserves fields and can deliberately clear nullable ones', () {
      final slot = _fullSlot();

      final cricketEdit = slot.copyWith(
        finalOverBatsmen: [batsmen.last.id, ...slot.finalOverBatsmen.skip(1)],
      );
      expect(cricketEdit.attackers, slot.attackers);
      expect(cricketEdit.basketballPlayers, slot.basketballPlayers);
      expect(cricketEdit.tennisPlayers, slot.tennisPlayers);
      expect(cricketEdit.racingPlayers, slot.racingPlayers);
      expect(cricketEdit.keeper, slot.keeper);

      final cleared = slot.copyWith(
        keeper: null,
        basketballStarter: null,
        tennisStarter: null,
        racingStarter: null,
        chessFormation: null,
      );
      expect(cleared.keeper, isNull);
      expect(cleared.basketballStarter, isNull);
      expect(cleared.tennisStarter, isNull);
      expect(cleared.racingStarter, isNull);
      expect(cleared.chessFormation, isNull);
    });
  });

  group('active shared squad persistence', () {
    test('restores a valid persisted active squad', () async {
      final storage = SecureGameStorage();
      final first = _fullSlot();
      final second = first.copyWith(id: 'slot-2', name: 'Night Shift');
      await storage.saveDecks([first, second]);
      await storage.saveActiveDeckId(second.id);

      final bloc = GameBloc(storage)..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      expect(bloc.state.activeDeckId, second.id);
      expect(await storage.loadActiveDeckId(), second.id);
    });

    test('invalid persisted active squad falls back and repairs storage', () async {
      final storage = SecureGameStorage();
      final first = _fullSlot();
      await storage.saveDecks([first]);
      await storage.saveActiveDeckId('missing-slot');

      final bloc = GameBloc(storage)..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      expect(bloc.state.activeDeckId, first.id);
      expect(await storage.loadActiveDeckId(), first.id);
    });

    test('creating a squad clears all five sport loadouts and stays active', () async {
      final storage = SecureGameStorage();
      final first = _fullSlot();
      await storage.saveDecks([first]);
      await storage.saveActiveDeckId(first.id);
      final bloc = GameBloc(storage)..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      bloc.add(DeckCreated());
      final created = await bloc.stream.firstWhere(
        (state) => state.deckSlots.length == 2,
      );
      final slot = created.deckSlots.singleWhere(
        (item) => item.id == created.activeDeckId,
      );

      expect(slot.attackers, isEmpty);
      expect(slot.defenders, isEmpty);
      expect(slot.actions, isEmpty);
      expect(slot.finalOverBatsmen, isEmpty);
      expect(slot.basketballPlayers, isEmpty);
      expect(slot.basketballStarter, isNull);
      expect(slot.tennisPlayers, isEmpty);
      expect(slot.tennisStarter, isNull);
      expect(slot.racingPlayers, isEmpty);
      expect(slot.racingStarter, isNull);
      expect(await storage.loadActiveDeckId(), slot.id);
    });

    test('a sport-only save survives reload without erasing other sports', () async {
      final storage = SecureGameStorage();
      final first = _fullSlot();
      await storage.saveDecks([first]);
      await storage.saveActiveDeckId(first.id);
      final bloc = GameBloc(storage)..add(GameLoaded());
      await bloc.stream.firstWhere((state) => !state.loading);

      final nextTennis = tennisPlayerCards[1].id;
      bloc.add(
        DeckSaved(
          first.copyWith(
            tennisPlayers: [nextTennis],
            tennisStarter: nextTennis,
          ),
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.deckTennisStarter?.id == nextTennis,
      );
      await bloc.close();

      final reloaded = GameBloc(storage)..add(GameLoaded());
      addTearDown(reloaded.close);
      await reloaded.stream.firstWhere((state) => !state.loading);
      final revived = reloaded.state.deckSlots.single;

      expect(revived.tennisStarter, nextTennis);
      expect(revived.attackers, first.attackers);
      expect(revived.finalOverBatsmen, first.finalOverBatsmen);
      expect(revived.basketballPlayers, first.basketballPlayers);
      expect(revived.racingPlayers, first.racingPlayers);
    });
  });

  group('starter packs preserve the other four sports', () {
    final scenarios = <({
      String name,
      GameEvent event,
      String changedSport,
      bool Function(GameState) claimed,
    })>[
      (
        name: 'football',
        event: StarterPackOpened(),
        changedSport: 'football',
        claimed: (state) => state.starterPackClaimed,
      ),
      (
        name: 'cricket',
        event: CricketStarterPackOpened(),
        changedSport: 'cricket',
        claimed: (state) => state.cricketStarterPackClaimed,
      ),
      (
        name: 'basketball',
        event: BasketballStarterPackOpened(),
        changedSport: 'basketball',
        claimed: (state) => state.basketballStarterPackClaimed,
      ),
      (
        name: 'tennis',
        event: TennisStarterPackOpened(),
        changedSport: 'tennis',
        claimed: (state) => state.tennisStarterPackClaimed,
      ),
      (
        name: 'racing',
        event: GrandPrixStarterPackOpened(),
        changedSport: 'racing',
        claimed: (state) => state.grandPrixStarterPackClaimed,
      ),
    ];

    for (final scenario in scenarios) {
      test('${scenario.name} starter preserves every other loadout', () async {
        final before = _fullSlot().copyWith(name: 'Active Five');
        final bloc = GameBloc(SecureGameStorage());
        bloc.emit(
          GameState.initial().copyWith(
            loading: false,
            deckSlots: [before],
            activeDeckId: before.id,
            starterPackClaimed: false,
            cricketStarterPackClaimed: false,
            basketballStarterPackClaimed: false,
            tennisStarterPackClaimed: false,
            grandPrixStarterPackClaimed: false,
          ),
        );

        bloc.add(scenario.event);
        await bloc.stream.firstWhere(scenario.claimed);
        final after = bloc.state.deckSlots.single;
        await bloc.close();

        expect(after.id, before.id);
        expect(after.name, before.name);
        if (scenario.changedSport != 'football') {
          expect(after.attackers, before.attackers);
          expect(after.defenders, before.defenders);
          expect(after.actions, before.actions);
          expect(after.keeper, before.keeper);
        }
        if (scenario.changedSport != 'cricket') {
          expect(after.finalOverBatsmen, before.finalOverBatsmen);
        }
        if (scenario.changedSport != 'basketball') {
          expect(after.basketballPlayers, before.basketballPlayers);
          expect(after.basketballStarter, before.basketballStarter);
        }
        if (scenario.changedSport != 'tennis') {
          expect(after.tennisPlayers, before.tennisPlayers);
          expect(after.tennisStarter, before.tennisStarter);
        }
        if (scenario.changedSport != 'racing') {
          expect(after.racingPlayers, before.racingPlayers);
          expect(after.racingStarter, before.racingStarter);
        }
      });
    }
  });
}

StoredDeckSlot _fullSlot() {
  final guard = basketballPlayerCards.firstWhere(
    (card) => card.role == PlayerRole.basketballGuard,
  );
  final wing = basketballPlayerCards.firstWhere(
    (card) => card.role == PlayerRole.basketballWing,
  );
  final big = basketballPlayerCards.firstWhere(
    (card) => card.role == PlayerRole.basketballBig,
  );
  final tennis = tennisPlayerCards.first;
  final racing = racingPlayerCards.first;
  return defaultDeckSlots.first.copyWith(
    finalOverBatsmen: batsmen.take(3).map((card) => card.id).toList(),
    basketballPlayers: [guard.id, wing.id, big.id],
    basketballStarter: guard.id,
    tennisPlayers: [tennis.id],
    tennisStarter: tennis.id,
    racingPlayers: [racing.id],
    racingStarter: racing.id,
  );
}
