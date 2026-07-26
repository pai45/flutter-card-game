import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/guess_player/guess_player_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'small phone flow searches, submits, and reveals without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cubit = GuessPlayerCubit(
        sport: Sport.football,
        timelines: footballGuessTimelines,
        allPlayers: footballPlayerCards,
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 18, 12),
      );
      final gameBloc = GameBloc(SecureGameStorage());
      addTearDown(cubit.close);
      addTearDown(gameBloc.close);
      await cubit.load();
      await cubit.openToday();
      final wrong = footballPlayerCards.firstWhere(
        (player) => player.id != cubit.state.targetPlayer!.id,
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GuessPlayerCubit>.value(value: cubit),
            BlocProvider<GameBloc>.value(value: gameBloc),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.2),
              ),
              child: GuessPlayerScreen(onBack: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CLUE 1/6 · 6 TRIES'), findsOneWidget);
      expect(find.text('LOCK PLAYER'), findsOneWidget);
      expect(find.text('POSITION'), findsOneWidget);
      expect(find.text('NATIONALITY'), findsOneWidget);
      expect(find.text('ROLE'), findsNothing);
      expect(find.text('TRAIT'), findsNothing);
      expect(find.byIcon(Icons.monetization_on_outlined), findsNothing);
      for (var index = 0; index < 6; index++) {
        expect(
          find.byKey(ValueKey('guess-player-heart-$index')),
          findsOneWidget,
        );
      }
      for (var index = 0; index < 6; index++) {
        expect(
          find.byKey(ValueKey('career-route-node-$index')),
          findsOneWidget,
        );
      }
      expect(find.text('?'), findsNWidgets(5));
      final firstStopName = cubit.state.puzzle!.clues.first.value;
      await tester.tap(find.byKey(const ValueKey('career-route-node-0')));
      await tester.pump();
      expect(find.text(firstStopName), findsWidgets);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        0,
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), wrong.name);
      await tester.pump();
      await tester.tap(find.text(wrong.name).last);
      await tester.pump();
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('LOCK PLAYER'));
      await tester.tap(find.text('LOCK PLAYER'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(cubit.state.attemptsRemaining, 5);
      expect(cubit.state.revealedClueCount, 2);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('guess-player-heart-5')),
        findsOneWidget,
      );
      expect(find.text('?'), findsNWidgets(4));
      expect(find.text('CLUE 2/6 · 5 TRIES'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('GIVE UP'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('DECLASSIFY THIS PLAYER?'), findsOneWidget);
      await tester.tap(find.text('KEEP SCANNING'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        cubit.state.activeRecord?.status,
        GuessPlayerResultStatus.inProgress,
      );

      await tester.tap(find.text('GIVE UP'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('GIVE UP >'));
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.activeRecord?.status, GuessPlayerResultStatus.gaveUp);
      expect(find.text('PLAYER DECLASSIFIED'), findsOneWidget);
      expect(find.text('SHARE SPOILER-FREE RESULT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exhausted guesses show paid continue and give up actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = GuessPlayerCubit(
      sport: Sport.football,
      timelines: footballGuessTimelines,
      allPlayers: footballPlayerCards,
      storage: SecureGameStorage(),
      now: () => DateTime(2026, 7, 18, 12),
    );
    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(cubit.close);
    addTearDown(gameBloc.close);
    await cubit.load();
    await cubit.openToday();
    final targetId = cubit.state.targetPlayer!.id;
    final wrong = footballPlayerCards
        .where((player) => player.id != targetId)
        .take(6)
        .toList();
    for (final player in wrong) {
      await cubit.submitGuess(player);
    }

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GuessPlayerCubit>.value(value: cubit),
          BlocProvider<GameBloc>.value(value: gameBloc),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(393, 852)),
            child: GuessPlayerScreen(onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      cubit.state.activeRecord?.status,
      GuessPlayerResultStatus.inProgress,
    );
    expect(find.text('NO GUESSES LEFT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guess-player-buy-extra-attempt')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guess-player-give-up-exhausted')),
      findsOneWidget,
    );
    expect(find.text('PLAYER DECLASSIFIED'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('guess-player-give-up-exhausted')),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('DECLASSIFY THIS PLAYER?'), findsOneWidget);
    await tester.tap(find.text('GIVE UP >'));
    await tester.pump(const Duration(seconds: 1));

    expect(cubit.state.activeRecord?.status, GuessPlayerResultStatus.gaveUp);
    expect(find.text('PLAYER DECLASSIFIED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard layout, reduced motion, and search semantics stay accessible',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final cubit = GuessPlayerCubit(
        sport: Sport.football,
        timelines: footballGuessTimelines,
        allPlayers: footballPlayerCards,
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 18, 12),
      );
      final gameBloc = GameBloc(SecureGameStorage());
      addTearDown(cubit.close);
      addTearDown(gameBloc.close);
      await cubit.load();
      await cubit.openToday();
      final wrong = footballPlayerCards.firstWhere(
        (player) => player.id != cubit.state.targetPlayer!.id,
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<GuessPlayerCubit>.value(value: cubit),
            BlocProvider<GameBloc>.value(value: gameBloc),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(393, 852),
                viewInsets: EdgeInsets.only(bottom: 300),
                textScaler: TextScaler.linear(1.3),
                disableAnimations: true,
              ),
              child: GuessPlayerScreen(onBack: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label?.contains('6 attempts remaining') == true,
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), wrong.name);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Select ${wrong.name}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('tablet layout supports enlarged text', (tester) async {
    tester.view.physicalSize = const Size(800, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = GuessPlayerCubit(
      sport: Sport.basketball,
      timelines: basketballGuessTimelines,
      allPlayers: basketballPlayerCards,
      storage: SecureGameStorage(),
      now: () => DateTime(2026, 7, 18, 12),
    );
    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(cubit.close);
    addTearDown(gameBloc.close);
    await cubit.load();
    await cubit.openToday();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GuessPlayerCubit>.value(value: cubit),
          BlocProvider<GameBloc>.value(value: gameBloc),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 1024),
              textScaler: TextScaler.linear(1.6),
            ),
            child: GuessPlayerScreen(onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GUESS THE PLAYER'), findsOneWidget);
    expect(find.text('LOCK PLAYER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
