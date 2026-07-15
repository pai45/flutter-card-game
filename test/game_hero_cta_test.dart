import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('arcade hero CTAs render and open the intended games', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = SecureGameStorage();
    final gameBloc = GameBloc(storage);
    final predictionCubit = PredictionCubit(
      MockPredictionRepository(),
      storage,
    );
    addTearDown(gameBloc.close);
    addTearDown(predictionCubit.close);

    var grandPrixOpens = 0;
    var hoopDuelOpens = 0;
    var finalOverOpens = 0;
    var tennisRallyOpens = 0;
    var pitchDuelOpens = 0;
    var penaltyShootoutOpens = 0;
    var footballChessOpens = 0;

    Future<void> pumpGamesTab(int sportTab) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GameBloc>.value(value: gameBloc),
            BlocProvider<PredictionCubit>.value(value: predictionCubit),
          ],
          child: MaterialApp(
            home: PredictionHomeScreen(
              activeTab: 1,
              onTabChanged: (_) {},
              activeMatchSportTab: 0,
              onMatchSportTabChanged: (_) {},
              activeGamesSportTab: sportTab,
              onGamesSportTabChanged: (_) {},
              onNavigate: (_) {},
              onOpenMatch: (_) {},
              onOpenLeague: (_) {},
              onOpenGame: () => pitchDuelOpens++,
              onOpenShootout: () => penaltyShootoutOpens++,
              onOpenQuiz: (_) {},
              onOpenFootballBingo: () {},
              onOpenFootballChess: () => footballChessOpens++,
              onOpenSuperOver: () {},
              onOpenCricketDeck: () {},
              onOpenGuessPlayer: () {},
              onOpenBasketballGuessPlayer: () {},
              onOpenCricketGuessPlayer: () {},
              onOpenGrandPrix: () => grandPrixOpens++,
              onOpenBasketball: () => hoopDuelOpens++,
              onOpenFinalOver: () => finalOverOpens++,
              onOpenTennisRally: () => tennisRallyOpens++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    await pumpGamesTab(0);
    expect(find.text('PITCH DUEL'), findsOneWidget);
    expect(find.text('TACTICAL CARD GAME'), findsOneWidget);
    expect(find.text('ENTER THE DUEL'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pitch-duel-hero-card')));
    expect(pitchDuelOpens, 1);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('penalty-shootout-hero-card')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('PENALTY'), findsOneWidget);
    expect(find.text('SHOOTOUT'), findsOneWidget);
    expect(find.text('SUDDEN-DEATH SPOT KICKS'), findsOneWidget);
    expect(find.text('TAKE THE SHOT'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('penalty-shootout-hero-card')));
    expect(penaltyShootoutOpens, 1);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('football-chess-hero-card')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('5V5 FOOTBALL'), findsOneWidget);
    expect(find.text('CHESS'), findsOneWidget);
    expect(find.text('TACTICAL SQUAD DUEL'), findsOneWidget);
    expect(find.text('MAKE YOUR MOVE'), findsNothing);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -140));
    await tester.pumpAndSettle();
    final footballChessCard = tester.getRect(
      find.byKey(const ValueKey('football-chess-hero-card')),
    );
    await tester.tapAt(
      Offset(footballChessCard.center.dx, footballChessCard.bottom - 20),
    );
    expect(footballChessOpens, 1);

    await pumpGamesTab(2);
    expect(find.text('HOOP DUEL'), findsOneWidget);
    expect(find.text('STREET 1-ON-1 ARCADE HOOPS'), findsOneWidget);
    expect(find.text('HIT THE COURT'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hoop-duel-hero-card')));
    expect(hoopDuelOpens, 1);

    await pumpGamesTab(1);
    expect(find.text('FINAL OVER'), findsOneWidget);
    expect(find.text('SIX-BALL CRICKET CHASE'), findsOneWidget);
    expect(find.text('START THE CHASE'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('final-over-hero-card')));
    expect(finalOverOpens, 1);

    await pumpGamesTab(4);
    expect(find.text('GRAND PRIX DASH'), findsOneWidget);
    expect(find.text('ONE-LAP ARCADE RACER'), findsOneWidget);
    expect(find.text('RACE NOW'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('grand-prix-dash-hero-card')));
    expect(grandPrixOpens, 1);

    await pumpGamesTab(3);
    expect(find.text('TENNIS RALLY'), findsOneWidget);
    expect(find.text('2D ARCADE SETS // 5 MODES'), findsOneWidget);
    expect(find.text('STEP ON COURT'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tennis-rally-hero-card')));
    expect(tennisRallyOpens, 1);
  });
}
