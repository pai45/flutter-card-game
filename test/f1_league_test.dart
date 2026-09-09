import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:card_game/blocs/f1_league/f1_league_cubit.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/picks/picks_state.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/f1_league_data.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/f1_league_view.dart';
import 'package:card_game/screens/predictions/league_detail_screen.dart';
import 'package:card_game/screens/predictions/widgets/match_prediction_card.dart';
import 'package:card_game/screens/predictions/widgets/pick_market_card.dart';
import 'package:card_game/services/espn_f1_league_service.dart';
import 'package:card_game/services/f1_race_package_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> capture() =>
    (jsonDecode(File(EspnF1LeagueService.assetPath).readAsStringSync())
        as Map<String, dynamic>);

F1LeagueData decode(Map<String, dynamic> raw) =>
    F1LeagueData.fromEspn(raw, fetchedAt: DateTime.utc(2026, 9, 9));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = decode(capture()['response'] as Map<String, dynamic>);

  test(
    'real ESPN snapshot includes both championships and source season',
    () async {
      final bundled = await const EspnF1LeagueService().bundled();
      expect(bundled.season, 2026);
      expect(bundled.drivers, hasLength(23));
      expect(bundled.constructors, hasLength(11));
      expect(bundled.drivers.first.name, 'Kimi Antonelli');
      expect(bundled.drivers.first.points, 267);
      expect(bundled.constructors.first.name, 'Mercedes');
      expect(bundled.constructors.first.points, 468);
      expect(bundled.constructors.every((r) => r.abbreviation == null), isTrue);
    },
  );

  test('unplayed numeric zero differs from recorded scoreless weekend', () {
    final kimi = data.drivers.first;
    expect(kimi.byRace['BAR'], 0);
    expect(kimi.byRace.containsKey('BRN'), isFalse);
    expect(kimi.byRace.containsKey('ESP'), isFalse);
    expect(data.rounds.firstWhere((r) => r.code == 'BRN').played, isFalse);
    expect(kimi.byRace['CHN'], 29, reason: 'weekend may include sprint points');
    expect(kimi.byRace['ITA'], 25);
  });

  test(
    'missing totals remain absent and inconsistent seasons are rejected',
    () {
      final raw = capture()['response'] as Map<String, dynamic>;
      final tables = raw['children'] as List;
      final stats = tables[0]['standings']['entries'][0]['stats'] as List;
      stats.removeWhere((s) => s['name'] == 'championshipPts');
      expect(decode(raw).drivers.first.points, isNull);
      tables[1]['standings']['season'] = '2025';
      expect(() => decode(raw), throwsFormatException);
      expect(() => decode({}), throwsFormatException);
    },
  );

  test('failed refresh keeps ESPN snapshot, retry replaces it', () async {
    final service = _Service(data)..fail = true;
    final cubit = F1LeagueCubit(service: service);
    await cubit.load();
    expect(cubit.state.data, same(data));
    expect(cubit.state.snapshot, isTrue);
    expect(cubit.state.failed, isTrue);
    service.fail = false;
    await cubit.refresh();
    expect(cubit.state.snapshot, isFalse);
    expect(cubit.state.failed, isFalse);
    await cubit.close();
  });

  test(
    'closing a route during fetch does not emit into a closed cubit',
    () async {
      final pending = Completer<F1LeagueData>();
      final service = _Service(data)..pending = pending;
      final cubit = F1LeagueCubit(service: service);
      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      pending.complete(data);
      await load;
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('F1 tabs, scoring expansion and chart fit ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AudioController.instance.muted.value = true;
      final cubit = F1LeagueCubit(service: _Service(data));
      await cubit.load();
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const F1LeagueView(
              gamesTab: Center(child: Text('MATCH CARDS PANEL')),
              picksTab: Center(child: Text('PICKS PANEL')),
              league: League(
                id: 'f1',
                name: 'Formula 1',
                shortCode: 'F1',
                accent: Cyber.cyan,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('World Drivers’ Championship'.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.text('Kimi Antonelli').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('WEEKEND POINTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('WCC'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mercedes'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('STATS'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('POINTS RACE'), findsOneWidget);
      await tester.tap(find.text('CONSTRUCTORS'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ROUNDS'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pirelli Italian GP'), findsOneWidget);
      await tester.tap(find.text('GAMES'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MATCH CARDS PANEL'), findsOneWidget);
      await tester.tap(find.text('PICKS'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PICKS PANEL'), findsOneWidget);
      await tester.tap(find.text('TABLE'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mercedes'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'F1 view-more opens shared match cards and league-filtered picks',
    (tester) async {
      final fixtures = await tester.runAsync(
        F1RacePackageService.bundledFixtures,
      );
      final markets = await tester.runAsync(
        () => MockPickRepository().markets(),
      );
      final prediction = _SeededPrediction([
        fixtures!.first.copyWith(leagueId: '2030'),
        fixtures.first.copyWith(id: 'f1_demo'),
        fixtures.first.copyWith(id: '12345', leagueId: 'indycar'),
      ]);
      final picks = _SeededPicks(markets!);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PredictionCubit>.value(value: prediction),
            BlocProvider<PicksCubit>.value(value: picks),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LeagueDetailScreen(
              league: League(
                id: 'formula1',
                name: 'Formula 1',
                shortCode: 'F1',
                accent: Cyber.cyan,
              ),
              openFixturesTab: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final card = tester.widget<MatchPredictionCard>(
        find.byType(MatchPredictionCard),
      );
      expect(card.match.id, fixtures.first.id);
      expect(find.text('PREDICTION CENTER'), findsOneWidget);
      await tester.tap(find.text('PICKS'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final cards = tester.widgetList<PickMarketCard>(
        find.byType(PickMarketCard),
      );
      expect(cards, isNotEmpty);
      expect(cards.every((card) => card.market.leagueId == 'f1'), isTrue);
      await tester.pumpWidget(const SizedBox());
      await prediction.close();
      await picks.close();
      expect(tester.takeException(), isNull);
    },
  );
}

class _SeededPrediction extends PredictionCubit {
  _SeededPrediction(List<SportMatch> fixtures)
    : super(MockPredictionRepository(), SecureGameStorage()) {
    emit(
      PredictionState(
        loading: false,
        fixtures: fixtures,
        loadedSports: const {Sport.motorsport},
      ),
    );
  }
}

class _SeededPicks extends PicksCubit {
  _SeededPicks(List<PickMarket> markets)
    : super(MockPickRepository(), SecureGameStorage()) {
    emit(PicksState(loading: false, markets: markets));
  }
}

class _Service extends EspnF1LeagueService {
  _Service(this.data);
  final F1LeagueData data;
  bool fail = false;
  Completer<F1LeagueData>? pending;
  @override
  Future<F1LeagueData> bundled() async => data;
  @override
  Future<F1LeagueData> fetch() async {
    if (fail) throw StateError('offline');
    return pending == null ? data : await pending!.future;
  }
}
