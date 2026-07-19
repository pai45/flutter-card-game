import 'dart:math';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/tennis/tennis_cubit.dart';
import 'package:card_game/games/tennis/tennis_game.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/models/tennis.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/screens/tennis/tennis_hub.dart';
import 'package:card_game/screens/tennis/widgets/tennis_hud.dart';
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

  testWidgets('Games tab features Tennis Rally before Tennis Trivia', (
    tester,
  ) async {
    final gameBloc = GameBloc(SecureGameStorage());
    final predictionCubit = PredictionCubit(
      _EmptyPredictionRepository(),
      SecureGameStorage(),
    );
    addTearDown(gameBloc.close);
    addTearDown(predictionCubit.close);
    var opened = false;

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
            activeGamesSportTab: 3,
            onGamesSportTabChanged: (_) {},
            onNavigate: (_) {},
            onOpenMatch: (_) {},
            onOpenLeague: (_) {},
            onOpenGame: () {},
            onOpenShootout: () {},
            onOpenQuiz: (_) {},
            onOpenFootballBingo: () {},
            onOpenFootballChess: () {},
            onOpenSuperOver: () {},
            onOpenCricketDeck: () {},
            onOpenGuessPlayer: () {},
            onOpenBasketballGuessPlayer: () {},
            onOpenCricketGuessPlayer: () {},
            onOpenGrandPrix: () {},
          onOpenF1GuessDriver: () {},
              onOpenTennisGuessWinner: () {},
            onOpenBasketball: () {},
            onOpenTennisRally: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TENNIS RALLY'), findsOneWidget);
    expect(find.text('TENNIS TRIVIA'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('TENNIS RALLY')).dy,
      lessThan(tester.getTopLeft(find.text('TENNIS TRIVIA')).dy),
    );
    await tester.tap(find.text('TENNIS RALLY'));
    expect(opened, isTrue);
  });

  testWidgets('MVP first entry opens a tennis starter pack then preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = SecureGameStorage();
    final tennisCubit = TennisCubit(storage, random: Random(4));
    await tennisCubit.load();
    addTearDown(tennisCubit.close);

    await tester.pumpWidget(
      BlocProvider<TennisCubit>.value(
        value: tennisCubit,
        child: MaterialApp(home: TennisRallyHub(onExit: () {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('OPEN STARTER PACK'), findsOneWidget);
    expect(find.text('PLAYER SELECT'), findsNothing);
    expect(find.text('PLAY MODES'), findsNothing);
    expect(find.text('TRAINING'), findsNothing);
    expect(find.text('TOURNAMENT'), findsNothing);
    expect(find.text('ENDLESS RALLY'), findsNothing);
    expect(find.text('TARGET PRACTICE'), findsNothing);

    await tester.tap(find.text('OPEN STARTER PACK'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ATHLETE UNLOCKED'), findsOneWidget);
    expect(tennisCubit.state.profile.ownedPlayerIds, hasLength(1));

    await tester.tap(find.text('ENTER QUICK MATCH'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('MATCH PREVIEW'), findsOneWidget);
    expect(find.text('PLAYER SELECT'), findsNothing);
  });

  testWidgets('claimed MVP users go straight to match preview', (tester) async {
    final storage = SecureGameStorage();
    await storage.saveTennisProfile(
      const TennisProfile(
        starterPackClaimed: true,
        ownedPlayerIds: ['luca-vale'],
        selectedPlayerId: 'luca-vale',
        lastOpponentId: 'jett-okafor',
      ),
    );
    final tennisCubit = TennisCubit(storage, random: Random(2));
    await tennisCubit.load();
    addTearDown(tennisCubit.close);

    await tester.pumpWidget(
      BlocProvider<TennisCubit>.value(
        value: tennisCubit,
        child: MaterialApp(home: TennisRallyHub(onExit: () {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MATCH PREVIEW'), findsOneWidget);
    expect(find.text('OPEN STARTER PACK'), findsNothing);
    expect(find.text('PLAYER SELECT'), findsNothing);
    expect(tennisCubit.state.profile.lastOpponentId, isNot('luca-vale'));
  });

  testWidgets('hidden V2 hub still exposes all modes and lessons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = SecureGameStorage();
    final gameBloc = GameBloc(storage);
    final tennisCubit = TennisCubit(storage);
    await tennisCubit.load();
    addTearDown(gameBloc.close);
    addTearDown(tennisCubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GameBloc>.value(value: gameBloc),
          BlocProvider<TennisCubit>.value(value: tennisCubit),
        ],
        child: MaterialApp(home: TennisRallyV2Hub(onExit: () {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('QUICK MATCH'), findsOneWidget);
    expect(find.text('TOURNAMENT'), findsOneWidget);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('ENDLESS RALLY'), findsOneWidget);
    expect(find.text('TARGET PRACTICE'), findsOneWidget);

    await tester.ensureVisible(find.text('TRAINING'));
    await tester.tap(find.text('TRAINING'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TRAINING LAB'), findsOneWidget);
    expect(find.text('MOVEMENT'), findsOneWidget);
    expect(find.text('SCORING'), findsOneWidget);
    expect(find.text('START'), findsNWidgets(8));
  });

  testWidgets(
    'scoreboard renders Deuce and Advantage without color dependence',
    (tester) async {
      const config = TennisMatchConfig(
        matchId: 'hud-test',
        mode: TennisMode.quickMatch,
        playerId: 'nova-reyes',
        opponentId: 'jett-okafor',
        difficulty: TennisDifficulty.pro,
        seed: 2,
      );
      final game = TennisGame(
        config: config,
        settings: const TennisSettings(),
        onEvents: (_) {},
      );
      for (var i = 0; i < 3; i++) {
        game.engine.scoring.awardPoint(0);
        game.engine.scoring.awardPoint(1);
      }
      game.score.value = game.engine.score;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TennisHud(game: game, onPause: () {}),
          ),
        ),
      );
      expect(find.text('DEUCE'), findsOneWidget);
      expect(find.text('40'), findsNWidgets(2));

      game.engine.scoring.awardPoint(0);
      game.score.value = game.engine.score;
      await tester.pump();
      expect(find.text('AD'), findsOneWidget);
    },
  );
}

class _EmptyPredictionRepository implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => const [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async => const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async => null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => null;

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [];
}
