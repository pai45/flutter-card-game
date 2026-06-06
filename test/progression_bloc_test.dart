import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameState> _load(GameBloc bloc) async {
  bloc.add(GameLoaded());
  return bloc.stream
      .firstWhere((state) => !state.loading)
      .timeout(const Duration(seconds: 3));
}

Future<GameState> _nextWhere(
  GameBloc bloc,
  bool Function(GameState state) test,
) => bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('first launch prepares a playable fallback deck', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);

    final state = await _load(bloc);

    expect(state.starterPackClaimed, isFalse);
    expect(state.pendingPackReveal, isNull);
    expect(state.deckReady, isTrue);
    expect(state.deckAttackers, hasLength(2));
    expect(state.deckDefenders, hasLength(2));
    expect(state.deckActions, hasLength(6));
    expect(
      state.ownedCardIds,
      containsAll([
        ...state.deckAttackers.map((card) => card.id),
        ...state.deckDefenders.map((card) => card.id),
      ]),
    );
    expect(
      state.ownedActionCardIds,
      containsAll(state.deckActions.map((card) => card.id)),
    );
  });

  test('daily drop cooldown is persisted after claiming', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);

    bloc.add(DailyDropClaimed());
    final claimed = await _nextWhere(
      bloc,
      (state) => state.dailyDropLastClaimedAt != null,
    );
    expect(dailyDropStatus(claimed.dailyDropLastClaimedAt).ready, isFalse);

    final reloadedBloc = GameBloc(SecureGameStorage());
    addTearDown(reloadedBloc.close);
    final reloaded = await _load(reloadedBloc);

    expect(reloaded.dailyDropLastClaimedAt, isNotNull);
    expect(dailyDropStatus(reloaded.dailyDropLastClaimedAt).ready, isFalse);
  });

  test('shop pack purchase deducts coins and reveals rolled cards', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final loaded = await _load(bloc);

    bloc.add(CoinsAdded(150));
    await _nextWhere(bloc, (state) => state.coins == loaded.coins + 150);

    bloc.add(ShopPackPurchased('bronze'));
    final purchased = await _nextWhere(
      bloc,
      (state) => state.pendingPackReveal?.statusLabel == 'PURCHASED',
    );

    expect(purchased.coins, loaded.coins);
    expect(purchased.pendingPackReveal?.items, hasLength(3));
    expect(
      purchased.progression.totalXP,
      greaterThan(loaded.progression.totalXP),
    );
  });
}
