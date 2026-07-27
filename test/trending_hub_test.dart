import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/config/sport_modules.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/all_sports_screen.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:card_game/widgets/cyber/sport_underline_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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

  testWidgets('MATCH Trending resolves bento cards and All Sports selection', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(393, 852));
    final bundle = await _HubBundle.create();
    addTearDown(bundle.dispose);
    final harnessKey = GlobalKey<_HubHarnessState>();

    await tester.pumpWidget(
      bundle.wrap(_HubHarness(key: harnessKey, initialTopTab: 0)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('match-trending-feed')), findsOneWidget);
    expect(find.text('TRENDING NOW'), findsNothing);
    expect(find.text('FUTURE'), findsAtLeastNWidgets(1));
    expect(find.text('PREDICT'), findsAtLeastNWidgets(1));
    expect(find.text('PICK'), findsOneWidget);
    expect(find.textContaining('SIGNAL UNAVAILABLE'), findsNothing);

    final hubTabs = find.byType(SportHubTabs);
    expect(
      find.descendant(of: hubTabs, matching: find.byType(Icon)),
      findsNWidgets(6),
    );
    expect(
      find.descendant(
        of: hubTabs,
        matching: find.byIcon(Icons.sports_motorsports),
      ),
      findsNothing,
    );

    final wide = tester.getRect(find.byKey(const ValueKey('trend-live-epl')));
    final future = tester.getRect(
      find.byKey(const ValueKey('trend-world-cup-future')),
    );
    final predict = tester.getRect(
      find.byKey(const ValueKey('trend-arsenal-predict')),
    );
    expect(wide.width, greaterThan(wide.height * 1.8));
    expect(future.height, lessThan(future.width));
    expect(future.height, greaterThan(future.width * 0.75));
    expect(future.top, moreOrLessEquals(predict.top));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trend-live-epl')),
        matching: find.text('CFC'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('trend-live-epl')),
        matching: find.byType(PressableScale),
      ),
    );
    expect(harnessKey.currentState!.openedMatchId, 'epl_cfc_new');

    final pick = find.byKey(const ValueKey('trend-liverpool-pick'));
    await tester.scrollUntilVisible(
      pick,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.descendant(of: pick, matching: find.byType(PressableScale)),
    );
    expect(harnessKey.currentState!.openedMarketId, 'epl_liv_mc_winner');

    expect(harnessKey.currentState!.matchIndex, hubTrendingTabIndex);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AllSportsScreen), findsOneWidget);
    expect(find.text('SELECT SPORT'), findsOneWidget);
    expect(find.text('TRENDING'), findsOneWidget);
    expect(find.text('FOOTBALL'), findsOneWidget);
    expect(find.text('CRICKET'), findsOneWidget);
    expect(find.text('BASKETBALL'), findsOneWidget);
    expect(find.text('TENNIS'), findsOneWidget);
    expect(find.text('MOTORSPORT'), findsOneWidget);
    expect(harnessKey.currentState!.matchIndex, hubTrendingTabIndex);

    await tester.tap(find.text('CRICKET'));
    await tester.pumpAndSettle();
    expect(find.byType(AllSportsScreen), findsNothing);
    expect(
      harnessKey.currentState!.matchIndex,
      hubIndexForSport(Sport.cricket),
    );
  });

  testWidgets('GAMES Trending restores portrait cards and quick-play modes', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(393, 852));
    final bundle = await _HubBundle.create();
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
    expect(pitchRect.height, greaterThan(pitchRect.width * 1.8));
    expect(penaltyRect.height, greaterThan(penaltyRect.width * 1.8));
    expect(pitchRect.top, moreOrLessEquals(penaltyRect.top));
    expect(pitchRect.bottom, moreOrLessEquals(penaltyRect.bottom));
    expect(chessRect.height, greaterThan(chessRect.width * 1.8));
    expect(chessRect.top, moreOrLessEquals(quizRect.top));
    expect(quizRect.left, moreOrLessEquals(bingoRect.left));
    expect(bingoRect.top, greaterThan(quizRect.bottom));
    expect(guessRect.width, greaterThan(guessRect.height * 1.8));

    final title = find.descendant(
      of: pitchFinder,
      matching: find.text('PITCH DUEL'),
    );
    expect(tester.getCenter(title).dy, lessThan(pitchRect.center.dy));

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
    await tester.pumpAndSettle();
    expect(find.byType(AllSportsScreen), findsOneWidget);
    expect(find.text('6 PLAYABLE MODES'), findsOneWidget);
  });

  testWidgets('Trending feeds keep type readable at 320px', (tester) async {
    await _setPhoneSize(tester, const Size(320, 720));
    final bundle = await _HubBundle.create();
    addTearDown(bundle.dispose);
    final harnessKey = GlobalKey<_HubHarnessState>();

    await tester.pumpWidget(
      bundle.wrap(_HubHarness(key: harnessKey, initialTopTab: 0)),
    );
    await tester.pump(const Duration(seconds: 2));

    final matchFeed = find.byKey(const ValueKey('match-trending-feed'));
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

void _expectMinimumStyledType(WidgetTester tester, Finder root) {
  final styledText = tester
      .widgetList<Text>(find.descendant(of: root, matching: find.byType(Text)))
      .where((text) => text.style?.fontSize != null);
  expect(styledText, isNotEmpty);
  expect(styledText.every((text) => text.style!.fontSize! >= 10), isTrue);
}

Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    final predictions = PredictionCubit(MockPredictionRepository(), storage);
    final picks = PicksCubit(MockPickRepository(), storage);
    await predictions.load();
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
      child: MaterialApp(home: child),
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
