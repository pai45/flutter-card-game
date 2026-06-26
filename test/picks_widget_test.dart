import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/predictions/market_detail_screen.dart';
import 'package:card_game/screens/predictions/match_prediction_screen.dart';
import 'package:card_game/screens/predictions/picks_home_view.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('picks tab renders percent markets and filters', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'pd_pick_positions_v1': '[]'});
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 500,
        'ownedCardIds': <String>[],
        'ownedActionCardIds': <String>[],
        'ownedCardBackIds': ['default'],
        'equippedCardBackId': 'default',
      }),
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PicksHomeView()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('France'), findsAtLeastNWidgets(1));
    expect(find.text('Iraq'), findsAtLeastNWidgets(1));
    expect(find.text('72%'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LEAGUE'), findsOneWidget);
    expect(find.text('FIFA'), findsOneWidget);
  });

  testWidgets('future pick cards build all outcome CTAs in the rail', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'pd_pick_positions_v1': '[]'});
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 500,
        'ownedCardIds': <String>[],
        'ownedActionCardIds': <String>[],
        'ownedCardBackIds': ['default'],
        'equippedCardBackId': 'default',
      }),
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PicksHomeView()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('FUTURES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Who will win IPL 2026?'), findsOneWidget);
    expect(find.text('MUM'), findsOneWidget);
    expect(find.text('CHE'), findsOneWidget);
    expect(find.text('BLR'), findsOneWidget);
    expect(find.text('KOL'), findsOneWidget);
    expect(find.text('HYD'), findsOneWidget);
    expect(find.text('PJB'), findsOneWidget);
  });

  testWidgets('buy pick sheet accepts typed stake and validates multiples', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'pd_pick_positions_v1': '[]'});
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 500,
        'ownedCardIds': <String>[],
        'ownedActionCardIds': <String>[],
        'ownedCardBackIds': ['default'],
        'equippedCardBackId': 'default',
      }),
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: PicksHomeView()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.scrollUntilVisible(
      find.text('68%'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.text('68%').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final stakeInput = find.byKey(const ValueKey('pick_stake_input'));
    expect(stakeInput, findsOneWidget);

    await tester.enterText(stakeInput, '69');
    await tester.pump();

    expect(find.text('Stake must be a multiple of 68 Oz.'), findsOneWidget);

    await tester.enterText(stakeInput, '136');
    await tester.pump();

    expect(find.textContaining('2 SHARES'), findsOneWidget);
    expect(find.textContaining('BALANCE AFTER 364 OZ'), findsOneWidget);
    expect(find.text('Stake must be a multiple of 68 Oz.'), findsNothing);
  });

  testWidgets('FIFA event detail chart has all week day filters', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'pd_pick_positions_v1': '[]'});

    await tester.pumpWidget(
      BlocProvider(
        create: (_) =>
            PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MarketDetailScreen(marketId: 'fifa_arg_por_final'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Will Argentina or Portugal reach FIFA 26 Finals?'),
      findsOneWidget,
    );
    expect(find.text('MARKET ODDS'), findsOneWidget);
    expect(find.text('101 BETS'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('WEEK'), findsOneWidget);
    expect(find.text('DAY'), findsOneWidget);
    expect(find.text('YES 59%'), findsOneWidget);
    expect(find.text('NO 41%'), findsOneWidget);

    final chart = find.byKey(const ValueKey('pick_odds_chart'));
    final chartRect = tester.getRect(chart);
    await tester.tapAt(chartRect.centerLeft + const Offset(1, 0));
    await tester.pump();

    expect(find.text('YES 56%'), findsOneWidget);
    expect(find.text('NO 44%'), findsOneWidget);
  });

  testWidgets(
    'linked market detail can navigate to same match prediction quiz',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'pd_pick_positions_v1': '[]'});
      SharedPreferences.setMockInitialValues({});

      final picksCubit = PicksCubit(MockPickRepository(), SecureGameStorage());
      final predictionCubit = PredictionCubit(
        MockPredictionRepository(),
        SecureGameStorage(),
      );
      await picksCubit.load();
      await predictionCubit.load();
      addTearDown(picksCubit.close);
      addTearDown(predictionCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PicksCubit>.value(value: picksCubit),
            BlocProvider<PredictionCubit>.value(value: predictionCubit),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MarketDetailScreen(marketId: 'epl_liv_mc_winner'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Liverpool vs Man City result'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('same_match_prediction_quiz_cta')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('PREDICTION QUIZ'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('same_match_prediction_quiz_cta')),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 800));

      expect(find.byType(MarketDetailScreen), findsNothing);
      expect(find.byType(MatchPredictionScreen), findsOneWidget);
    },
  );
}

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 16);
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}
