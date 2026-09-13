import 'package:card_game/blocs/league_stats/league_stats_cubit.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/screens/predictions/league_detail_screen.dart';
import 'package:card_game/screens/predictions/widgets/standings_table.dart';
import 'package:card_game/services/nba_league_stats_package_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the real NBA league hub off the bundled package — the surface the
/// request was about, not just the decoder underneath it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const league = League(
    id: 'nba',
    name: 'National Basketball Association',
    shortCode: 'NBA',
    accent: Color(0xffffd34d),
  );

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    NbaLeagueStatsPackageService.clearCache();
    final stats = LeagueStatsCubit(
      'nba',
      leagueName: league.name,
      shortCode: 'NBA',
    );
    final storage = SecureGameStorage();
    final prediction = PredictionCubit(MockPredictionRepository(), storage);
    final picks = PicksCubit(MockPickRepository(), storage);
    addTearDown(stats.close);
    addTearDown(prediction.close);
    addTearDown(picks.close);

    await tester.runAsync(stats.load);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LeagueStatsCubit>.value(value: stats),
          BlocProvider.value(value: prediction),
          BlocProvider.value(value: picks),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LeagueDetailScreen(league: league),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('TABLE shows a real conference table in NBA columns', (
    tester,
  ) async {
    await pumpHub(tester);

    // The basketball layout, not football's P/W/D/L/GD or cricket's NRR.
    expect(find.text('PCT'), findsOneWidget);
    expect(find.text('GB'), findsOneWidget);
    expect(find.text('STRK'), findsOneWidget);
    // Not findsOneWidget: a ten-game losing streak also prints "L10", in the
    // STRK column right beside this header.
    expect(find.text('L10'), findsWidgets);
    expect(find.text('D'), findsNothing);
    expect(find.text('GD'), findsNothing);
    expect(find.text('NRR'), findsNothing);
    expect(find.byType(StandingsTable), findsOneWidget);

    // Detroit topped the East in 2025-26, at .732 with no games to make up.
    expect(find.text('.732'), findsOneWidget);
    expect(find.text('60'), findsWidgets);
    // The playoff cut line is the table's one live element.
    expect(find.text('PLAYOFFS'), findsOneWidget);
    expect(find.text('PLAY-IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the conference toggle swaps East for West', (tester) async {
    await pumpHub(tester);

    expect(find.text('.732'), findsOneWidget);
    await tester.tap(find.text('WEST'));
    await tester.pump(const Duration(milliseconds: 400));

    // Oklahoma City's 64-18 is the West's top line — 64/82 is .780, not .781.
    expect(find.text('.780'), findsOneWidget);
    expect(find.text('.732'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LEADERS carries the real season boards', (tester) async {
    await pumpHub(tester);
    await tester.tap(find.bySemanticsLabel('LEADERS'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Luka Doncic'), findsWidgets);
    expect(find.text('33.5'), findsWidgets);
    expect(find.textContaining('POINTS PER GAME'), findsWidgets);
    // The qualifying minimum rides in the headline, so nobody wonders why a
    // four-game hot streak is not top.
    expect(find.textContaining('58+ GAMES'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('STATS shows basketball boards, not football\'s', (tester) async {
    await pumpHub(tester);
    await tester.tap(find.bySemanticsLabel('STATS'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('SCORING'), findsOneWidget);
    expect(find.text('PLAYMAKING'), findsOneWidget);
    expect(find.text('DEFENCE'), findsOneWidget);
    // Football's groups must not leak in — the two sports share no stat keys,
    // so they would render a page of NOT PUBLISHED.
    expect(find.text('ATTACK'), findsNothing);
    expect(find.text('KEEPING'), findsNothing);
    expect(find.text('NOT PUBLISHED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
