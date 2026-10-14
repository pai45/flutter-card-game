import 'package:card_game/widgets/cyber/match_discovery.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/config/sport_modules.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/all_sports_screen.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/screens/predictions/trending_hub_catalog.dart';
import 'package:card_game/services/basketball_match_package_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.debugUseBackend(_NoopAudioBackend());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('MATCH Trending registers the bundled NBA Finals card', () {
    final card = matchTrendingCatalog.singleWhere(
      (item) => item.id == 'trend-spurs-knicks',
    );

    expect(card.kind, TrendingTileKind.match);
    expect(card.sourceId, BasketballMatchPackageService.bundledMatchId);
    expect(card.sport, Sport.basketball);
    expect(card.span, CyberBentoSpan.wide);
  });

  testWidgets(
    'MATCH Trending shows editorial fixtures and preserves All Sports navigation',
    (tester) async {
      await _setPhoneSize(tester, const Size(393, 852));
      final bundle = (await tester.runAsync(_HubBundle.create))!;
      addTearDown(bundle.dispose);
      final harnessKey = GlobalKey<_HubHarnessState>();
      await tester.pumpWidget(
        bundle.wrap(_HubHarness(key: harnessKey, initialTopTab: 0)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(const PageStorageKey('match-trending-feed')),
        findsOneWidget,
      );
      expect(find.text('Featured Picks'), findsNothing);
      expect(
        find.byKey(const PageStorageKey('featured-winner-picks')),
        findsOneWidget,
      );
      expect(find.byTooltip('Previous Pick'), findsNothing);
      expect(find.byTooltip('Next Pick'), findsNothing);
      expect(
        find.byKey(const ValueKey('trend-category-futures')),
        findsNothing,
      );
      final card = find.byType(EditorialMatchCard);
      await _dragIntoView(tester, card);
      final firstCard = card.first;
      final fixture = tester.widget<EditorialMatchCard>(firstCard).match;
      await tester.tap(firstCard);
      expect(harnessKey.currentState!.openedMatchId, fixture.id);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(AllSportsScreen), findsOneWidget);
      await tester.tap(find.text('CRICKET'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        harnessKey.currentState!.matchIndex,
        hubIndexForSport(Sport.cricket),
      );
    },
  );

  testWidgets('GAMES Trending restores portrait cards and quick-play modes', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(393, 852));
    final bundle = (await tester.runAsync(_HubBundle.create))!;
    addTearDown(bundle.dispose);
    final harnessKey = GlobalKey<_HubHarnessState>();

    await tester.pumpWidget(
      bundle.wrap(_HubHarness(key: harnessKey, initialTopTab: 1)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('games-trending-feed')), findsOneWidget);
    expect(find.text('TRENDING ARCADE'), findsNothing);
    expect(find.textContaining('MODE OFFLINE'), findsNothing);

    final pitchFinder = find.byKey(const ValueKey('trend-game-pitch-duel'));
    final penaltyFinder = find.byKey(const ValueKey('trend-game-penalty'));
    final chessFinder = find.byKey(const ValueKey('trend-game-football-chess'));
    final quizFinder = find.byKey(const ValueKey('trend-game-football-quiz'));
    final bingoFinder = find.byKey(const ValueKey('trend-game-football-bingo'));
    final guessFinder = find.byKey(const ValueKey('trend-game-guess-player'));
    final pitchRect = tester.getRect(pitchFinder);
    final penaltyRect = tester.getRect(penaltyFinder);
    final chessRect = tester.getRect(chessFinder);
    final quizRect = tester.getRect(quizFinder);
    final bingoRect = tester.getRect(bingoFinder);
    final guessRect = tester.getRect(guessFinder);
    expect(pitchRect.height, moreOrLessEquals(300));
    expect(penaltyRect.height, moreOrLessEquals(300));
    expect(pitchRect.top, moreOrLessEquals(penaltyRect.top));
    expect(pitchRect.bottom, moreOrLessEquals(penaltyRect.bottom));
    expect(chessRect.height, greaterThan(chessRect.width * 1.8));
    expect(chessRect.top, moreOrLessEquals(quizRect.top));
    expect(quizRect.left, moreOrLessEquals(bingoRect.left));
    expect(bingoRect.top, greaterThanOrEqualTo(quizRect.bottom));
    expect(guessRect.width, greaterThan(guessRect.height * 1.6));

    final title = find.descendant(
      of: pitchFinder,
      matching: find.text('PITCH DUEL'),
    );
    expect(tester.getCenter(title).dy, greaterThan(pitchRect.center.dy));

    await tester.tap(pitchFinder);
    expect(harnessKey.currentState!.pitchDuelOpens, 1);

    await _scrollAndTap(tester, penaltyFinder);
    expect(harnessKey.currentState!.shootoutOpens, 1);
    await _scrollAndTap(tester, chessFinder);
    expect(harnessKey.currentState!.footballChessOpens, 1);
    await _scrollAndTap(tester, quizFinder);
    expect(harnessKey.currentState!.openedQuizSport, Sport.football);
    await _scrollAndTap(tester, bingoFinder);
    expect(harnessKey.currentState!.footballBingoOpens, 1);
    await _scrollAndTap(tester, guessFinder);
    expect(harnessKey.currentState!.guessPlayerOpens, 1);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(AllSportsScreen), findsOneWidget);
    expect(find.text('6 PLAYABLE MODES'), findsOneWidget);
  });

  testWidgets('Trending feeds keep type readable at 320px', (tester) async {
    await _setPhoneSize(tester, const Size(320, 720));
    final bundle = (await tester.runAsync(_HubBundle.create))!;
    addTearDown(bundle.dispose);
    final harnessKey = GlobalKey<_HubHarnessState>();

    await tester.pumpWidget(
      bundle.wrap(_HubHarness(key: harnessKey, initialTopTab: 0)),
    );
    await tester.pump(const Duration(seconds: 2));

    final matchFeed = find.byKey(const PageStorageKey('match-trending-feed'));
    expect(find.text('Featured Picks'), findsNothing);
    expect(
      find.byKey(const PageStorageKey('featured-winner-picks')),
      findsOneWidget,
    );
    expect(find.byTooltip('Previous Pick'), findsNothing);
    expect(find.byTooltip('Next Pick'), findsNothing);
    _expectMinimumStyledType(tester, matchFeed);
    final matchText = tester.widgetList<Text>(
      find.descendant(of: matchFeed, matching: find.byType(Text)),
    );
    expect(
      matchText.any((text) => RegExp(r'^0[1-9]$').hasMatch(text.data ?? '')),
      isFalse,
    );
    expect(tester.takeException(), isNull);

    harnessKey.currentState!.switchTopTab(1);
    await tester.pump(const Duration(milliseconds: 700));

    final gamesFeed = find.byKey(const ValueKey('games-trending-feed'));
    _expectMinimumStyledType(tester, gamesFeed);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cricket editorial fixture stacks innings and keeps overs and target',
    (tester) async {
      await _setPhoneSize(tester, const Size(320, 720));
      final original = await MockPredictionRepository().fixtureById('1496576');
      final fixture = original!.copyWith(
        status: MatchStatus.finished,
        homeScore: '201/7 (20 ov)',
        awayScore: '203/5 (19.1 ov, target 202)',
        resultLine: 'India won by 5 wickets',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorialMatchCard(match: fixture, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('201/7'), findsOneWidget);
      expect(find.text('203/5'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('203/5')).dy,
        greaterThan(tester.getBottomLeft(find.text('201/7')).dy),
      );
      expect(find.text('FINISHED'), findsOneWidget);
      expect(find.text('India won by 5 wickets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [
    Size(320, 1000),
    Size(393, 1000),
    Size(600, 1000),
  ]) {
    testWidgets('CyberBentoGrid packs without overlap at ${size.width}px', (
      tester,
    ) async {
      await _setPhoneSize(tester, size);
      final keys = List.generate(5, (index) => ValueKey('cell-$index'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CyberBentoGrid(
                tiles: [
                  CyberBentoTile(
                    span: CyberBentoSpan.wide,
                    child: ColoredBox(key: keys[0], color: Colors.red),
                  ),
                  CyberBentoTile(
                    span: CyberBentoSpan.tall,
                    child: ColoredBox(key: keys[1], color: Colors.blue),
                  ),
                  CyberBentoTile(
                    span: CyberBentoSpan.square,
                    child: ColoredBox(key: keys[2], color: Colors.green),
                  ),
                  CyberBentoTile(
                    span: CyberBentoSpan.square,
                    child: ColoredBox(key: keys[3], color: Colors.yellow),
                  ),
                  CyberBentoTile(
                    span: CyberBentoSpan.wide,
                    child: ColoredBox(key: keys[4], color: Colors.purple),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
      for (var first = 0; first < rects.length; first++) {
        for (var second = first + 1; second < rects.length; second++) {
          expect(rects[first].overlaps(rects[second]), isFalse);
        }
      }
      expect(rects[1].height, greaterThan(rects[1].width * 1.8));
      expect(tester.takeException(), isNull);
      if (size.width >= 600) {
        expect(rects.first.width, lessThanOrEqualTo(440));
      }
    });
  }
}

class _NoopAudioBackend implements AudioPlaybackBackend {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> playEffect(
    String assetPath, {
    required AudioBus bus,
    required double volume,
  }) async {}

  @override
  Future<void> preload(List<String> assetPaths) async {}

  @override
  Future<void> setAmbienceVolume(double volume) async {}

  @override
  Future<void> setDynamicLoop({
    required double volume,
    required double rate,
  }) async {}

  @override
  Future<void> startAmbience(
    String assetPath, {
    required double volume,
  }) async {}

  @override
  Future<void> startDynamicLoop(
    String assetPath, {
    required double volume,
  }) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> stopAmbience() async {}

  @override
  Future<void> stopDynamicLoop() async {}
}

void _expectMinimumStyledType(WidgetTester tester, Finder root) {
  final styledText = tester
      .widgetList<Text>(find.descendant(of: root, matching: find.byType(Text)))
      .where((text) => text.style?.fontSize != null);
  expect(styledText, isNotEmpty);
  expect(styledText.every((text) => text.style!.fontSize! >= 10), isTrue);
}

Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await _dragIntoView(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

/// Drags the hub feed until [finder] sits on screen. The top bar and MATCH /
/// GAMES switcher scroll away in a [NestedScrollView], where `ensureVisible`
/// (and so `scrollUntilVisible`) re-opens the header and snaps the feed back.
Future<void> _dragIntoView(WidgetTester tester, Finder finder) async {
  final view = find.byType(NestedScrollView);
  for (var step = 0; step < 60; step++) {
    if (finder.evaluate().isNotEmpty &&
        tester.getRect(finder.first).bottom <= tester.getRect(view).bottom) {
      return;
    }
    await tester.dragFrom(tester.getRect(view).center, const Offset(0, -120));
    await tester.pump();
  }
  fail('could not drag $finder into view');
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Bundled fixture integration tests avoid a rolling live network refresh.
class _OfflineHubPredictions extends PredictionCubit {
  _OfflineHubPredictions(SecureGameStorage storage)
    : super(MockPredictionRepository(), storage);
  @override
  Future<void> loadSport(Sport sport) async {}
}

class _HubBundle {
  _HubBundle({
    required this.game,
    required this.predictions,
    required this.picks,
  });

  final GameBloc game;
  final PredictionCubit predictions;
  final PicksCubit picks;

  static Future<_HubBundle> create() async {
    final storage = SecureGameStorage();
    final game = GameBloc(storage);
    final predictions = _OfflineHubPredictions(storage);
    final picks = PicksCubit(MockPickRepository(), storage);
    await predictions.load();
    await predictions.ingestFixtures(
      await MockPredictionRepository().fixtures(),
    );
    await picks.load();
    return _HubBundle(game: game, predictions: predictions, picks: picks);
  }

  Widget wrap(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<GameBloc>.value(value: game),
        BlocProvider<PredictionCubit>.value(value: predictions),
        BlocProvider<PicksCubit>.value(value: picks),
      ],
      child: MaterialApp(
        home: child,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await game.close();
    await predictions.close();
    await picks.close();
  }
}

class _HubHarness extends StatefulWidget {
  const _HubHarness({required this.initialTopTab, super.key});

  final int initialTopTab;

  @override
  State<_HubHarness> createState() => _HubHarnessState();
}

class _HubHarnessState extends State<_HubHarness> {
  late int topTab = widget.initialTopTab;
  int matchIndex = hubTrendingTabIndex;
  int gamesIndex = hubTrendingTabIndex;
  String? openedMatchId;
  String? openedMarketId;
  int pitchDuelOpens = 0;
  int shootoutOpens = 0;
  int footballBingoOpens = 0;
  int footballChessOpens = 0;
  int guessPlayerOpens = 0;
  Sport? openedQuizSport;

  void switchTopTab(int value) => setState(() => topTab = value);

  @override
  Widget build(BuildContext context) {
    return PredictionHomeScreen(
      activeTab: topTab,
      onTabChanged: (value) => setState(() => topTab = value),
      activeMatchSportTab: matchIndex,
      onMatchSportTabChanged: (value) => setState(() => matchIndex = value),
      activeGamesSportTab: gamesIndex,
      onGamesSportTabChanged: (value) => setState(() => gamesIndex = value),
      onNavigate: (AppSection _) {},
      onOpenMatch: (match) => openedMatchId = match.id,
      onOpenMarket: (marketId) => openedMarketId = marketId,
      onOpenLeague: (League _) {},
      onOpenLeagueGames: (League _) {},
      onOpenGame: () => pitchDuelOpens++,
      onOpenShootout: () => shootoutOpens++,
      onOpenQuiz: (sport) => openedQuizSport = sport,
      onOpenFootballBingo: () => footballBingoOpens++,
      onOpenFootballChess: () => footballChessOpens++,
      onOpenGuessPlayer: () => guessPlayerOpens++,
      onOpenBasketballGuessPlayer: () {},
      onOpenCricketGuessPlayer: () {},
      onOpenGrandPrix: () {},
      onOpenF1GuessDriver: () {},
      onOpenTennisGuessWinner: () {},
      onOpenBasketball: () {},
      onOpenFinalOver: () {},
      onOpenTennisRally: () {},
    );
  }
}
