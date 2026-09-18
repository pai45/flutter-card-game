import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/models/oz_coin_ledger.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/unlock_progress.dart';
import 'package:card_game/models/xp_ledger.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameBloc> loaded(SecureGameStorage storage) async {
  final bloc = GameBloc(storage)..add(GameLoaded());
  await bloc.stream.firstWhere((s) => !s.loading);
  return bloc;
}

Future<GameState> settle(GameBloc bloc, bool Function(GameState) done) =>
    done(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(done);

FinalOverFinished finalOver(String id) => FinalOverFinished(
  matchId: id,
  runs: 12,
  target: 10,
  wickets: 1,
  resultLabel: 'CHASE COMPLETE',
  tierLabel: 'ROOKIE',
  grade: 'A',
  stars: 3,
  xp: 20,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh install stays unmanaged until a home sport is chosen', () async {
    final storage = SecureGameStorage();
    final bloc = await loaded(storage);
    expect(bloc.state.unlocks.gated, isFalse);

    bloc.add(HomeSportChosen(Sport.cricket));
    final state = await settle(bloc, (s) => s.unlocks.gated);
    expect(state.unlocks.isGameUnlocked(ArcadeGame.finalOver), isTrue);
    expect(state.unlocks.isGameUnlocked(ArcadeGame.pitchDuel), isFalse);
    await bloc.close();
    expect((await storage.loadUnlockProgress())!.homeSport, Sport.cricket);
  });

  test('a profile onboarded before unlocks shipped is grandfathered', () async {
    final storage = SecureGameStorage();
    await storage.saveOnboardingComplete(true);
    final bloc = await loaded(storage);
    expect(bloc.state.unlocks.grandfathered, isTrue);
    expect(bloc.state.unlocks.isGameUnlocked(ArcadeGame.footballChess), isTrue);
    await bloc.close();
    expect((await storage.loadUnlockProgress())!.grandfathered, isTrue);
  });

  test('finishing the quest step unlocks the next game with XP', () async {
    final bloc = await loaded(SecureGameStorage());
    bloc.add(HomeSportChosen(Sport.cricket));
    bloc.add(finalOver('fo-1'));
    final state = await settle(
      bloc,
      (s) => s.unlocks.gated && s.unlocks.reachedFor(Sport.cricket) == 2,
    );
    expect(
      state.xpLedger.where((e) => e.source == XpTransactionSource.beginnerQuest),
      hasLength(1),
    );
    expect(state.unlocks.pendingReveals.single.game, ArcadeGame.cricketQuiz);
    // A non-football game still counts toward the daily game quests.
    expect(state.dailyQuests.today.games, 1);

    // A replayed settle (same match id) is a no-op.
    bloc.add(finalOver('fo-1'));
    bloc.add(UnlockRevealConsumed());
    final after = await settle(bloc, (s) => s.unlocks.pendingReveals.isEmpty);
    expect(after.unlocks.reachedFor(Sport.cricket), 2);
    await bloc.close();
  });

  test('clearing the whole quest pays the sport-unlock Oz once', () async {
    final bloc = await loaded(SecureGameStorage());
    bloc.add(HomeSportChosen(Sport.cricket));
    bloc.add(finalOver('fo-1'));
    bloc.add(ArcadeGamePlayed(ArcadeGame.cricketQuiz, sourceId: 'q1'));
    bloc.add(ArcadeGamePlayed(ArcadeGame.cricketGuessPlayer, sourceId: 'g1'));
    bloc.add(ArcadeGamePlayed(ArcadeGame.cricketGuessPlayer, sourceId: 'g2'));
    final state = await settle(
      bloc,
      (s) => s.coinLedger.any(
        (e) => e.source == OzCoinTransactionSource.beginnerQuestReward,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state.unlocks.isQuestActive(Sport.cricket), isFalse);
    expect(state.coins, beginnerQuestCompleteOz);
    expect(
      bloc.state.coinLedger.where(
        (e) => e.source == OzCoinTransactionSource.beginnerQuestReward,
      ),
      hasLength(1),
    );
    await bloc.close();
  });

  test('buying a sport spends 50 Oz; broke or owned buys are no-ops', () async {
    final bloc = await loaded(SecureGameStorage());
    bloc.add(HomeSportChosen(Sport.football));
    await settle(bloc, (s) => s.unlocks.gated);

    // Too poor: nothing changes.
    bloc.add(SportUnlockPurchased(Sport.tennis));
    bloc.add(CoinsAdded(80));
    await settle(bloc, (s) => s.coins == 80);
    expect(bloc.state.unlocks.isSportUnlocked(Sport.tennis), isFalse);

    bloc.add(SportUnlockPurchased(Sport.tennis));
    final bought = await settle(
      bloc,
      (s) => s.unlocks.isSportUnlocked(Sport.tennis),
    );
    expect(bought.coins, 80 - sportUnlockCostOz);
    expect(bought.coinLedger.first.source, OzCoinTransactionSource.sportUnlock);
    expect(bought.unlocks.pendingReveals.single.kind, UnlockRevealKind.sport);

    // Owned already: no second charge.
    bloc.add(SportUnlockPurchased(Sport.tennis));
    bloc.add(CoinsAdded(1));
    final after = await settle(bloc, (s) => s.coins == 31);
    expect(after.coins, 80 - sportUnlockCostOz + 1);
    await bloc.close();
  });

  test('the rookie ticket is spent once', () async {
    final bloc = await loaded(SecureGameStorage());
    bloc.add(HomeSportChosen(Sport.cricket));
    bloc.add(finalOver('fo-1'));
    await settle(bloc, (s) => s.unlocks.hasRookieTicket(Sport.cricket));
    bloc.add(RookieTicketUsed(Sport.cricket));
    final state = await settle(
      bloc,
      (s) => !s.unlocks.hasRookieTicket(Sport.cricket),
    );
    expect(state.unlocks.rookieTicketsUsed, {Sport.cricket});
    await bloc.close();
  });
}
