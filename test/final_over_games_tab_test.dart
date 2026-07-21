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

  testWidgets(
    'Cricket Games features Final Over first and opens only Final Over',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
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

      var finalOverOpens = 0;
      var guessPlayerOpens = 0;
      var quizOpens = 0;

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
              activeGamesSportTab: 1,
              onGamesSportTabChanged: (_) {},
              onNavigate: (_) {},
              onOpenMatch: (_) {},
              onOpenLeague: (_) {},
              onOpenGame: () {},
              onOpenShootout: () {},
              onOpenQuiz: (_) => quizOpens++,
              onOpenFootballBingo: () {},
              onOpenFootballChess: () {},
              onOpenGuessPlayer: () {},
              onOpenBasketballGuessPlayer: () {},
              onOpenCricketGuessPlayer: () => guessPlayerOpens++,
              onOpenGrandPrix: () {},
          onOpenF1GuessDriver: () {},
              onOpenTennisGuessWinner: () {},
              onOpenBasketball: () {},
              onOpenFinalOver: () => finalOverOpens++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final finalOver = find.text('FINAL OVER');
      final guessPlayer = find.text('GUESS THE PLAYER');
      final cricketQuiz = find.text('CRICKET QUIZ');

      expect(finalOver, findsOneWidget);
      expect(guessPlayer, findsOneWidget);
      expect(cricketQuiz, findsOneWidget);
      expect(
        tester.getTopLeft(finalOver).dy,
        lessThan(tester.getTopLeft(guessPlayer).dy),
      );
      expect(
        tester.getTopLeft(guessPlayer).dy,
        lessThan(tester.getTopLeft(cricketQuiz).dy),
      );

      await tester.tap(finalOver);

      expect(finalOverOpens, 1);
      expect(guessPlayerOpens, 0);
      expect(quizOpens, 0);
    },
  );
}
